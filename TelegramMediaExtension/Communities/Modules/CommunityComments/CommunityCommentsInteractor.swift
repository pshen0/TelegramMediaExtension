import Combine
import Foundation

protocol CommunityCommentsBusinessLogic: AnyObject {
    func viewDidLoad(_ request: CommunityCommentsModel.ViewDidLoad.Request)
    func viewWillAppear()
    func viewWillDisappear()
    func sendComment(_ request: CommunityCommentsModel.SendComment.Request)
}

protocol CommunityCommentsRoutingLogic: AnyObject {
    func routeToNestedThread(commentId: UUID)
}

final class CommunityCommentsInteractor: CommunityCommentsBusinessLogic {

    let rootMessage: CommunityMessage
    let threadParentCommentId: UUID?

    private let presenter: CommunityCommentsPresentationLogic
    private let store = CommunityStore.shared

    weak var router: CommunityCommentsRoutingLogic?

    private var cancellables = Set<AnyCancellable>()
    private var didEmitInitialComments = false
    private var realtimeTask: Task<Void, Never>?

    init(
        presenter: CommunityCommentsPresentationLogic,
        rootMessage: CommunityMessage,
        threadParentCommentId: UUID?
    ) {
        self.presenter = presenter
        self.rootMessage = rootMessage
        self.threadParentCommentId = threadParentCommentId
    }

    func viewDidLoad(_ request: CommunityCommentsModel.ViewDidLoad.Request) {
        store.loadIfNeeded()
        bindComments()
        pushCommentsToPresenter(scrollAnimated: false)
        Task { [weak self] in
            guard let self else { return }
            await self.store.refreshComments(messageId: self.rootMessage.id, threadParentCommentId: self.threadParentCommentId)
        }
    }

    func viewWillAppear() {
        startRealtime()
    }

    func viewWillDisappear() {
        stopRealtime()
    }

    private func startRealtime() {
        guard realtimeTask == nil else { return }
        realtimeTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                do {
                    try await self.store.longPollNewComments(messageId: self.rootMessage.id, threadParentCommentId: self.threadParentCommentId)
                } catch {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
            }
        }
    }

    private func stopRealtime() {
        realtimeTask?.cancel()
        realtimeTask = nil
    }

    func sendComment(_ request: CommunityCommentsModel.SendComment.Request) {
        store.addComment(
            messageId: rootMessage.id,
            threadParentCommentId: threadParentCommentId,
            text: request.text
        )
    }

    private func bindComments() {
        store.$comments
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                let animated = self.didEmitInitialComments
                self.didEmitInitialComments = true
                self.pushCommentsToPresenter(scrollAnimated: animated)
            }
            .store(in: &cancellables)
    }

    private func pushCommentsToPresenter(scrollAnimated: Bool) {
        let list = store.comments(for: rootMessage.id, threadParentCommentId: threadParentCommentId)
        presenter.presentComments(
            CommunityCommentsModel.CommentsList.Response(comments: list, scrollAnimated: scrollAnimated)
        )
    }

    func parentCommentForThreadHeader() -> CommunityComment? {
        guard let tid = threadParentCommentId else { return nil }
        let roots = store.comments(for: rootMessage.id, threadParentCommentId: nil)
        return roots.first(where: { $0.id == tid })
    }
}
