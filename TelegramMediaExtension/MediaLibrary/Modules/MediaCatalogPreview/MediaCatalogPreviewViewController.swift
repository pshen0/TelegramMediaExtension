import UIKit

final class MediaCatalogPreviewViewController: UIViewController {
    private let interactor: MediaCatalogPreviewBusinessLogic
    private let candidate: MediaCatalogCandidate

    weak var addFlowCoordinator: AddToMediaLibraryViewController?

    private let scroll = UIScrollView()
    private let stack = UIStackView()
    private let kindBadge = UILabel()
    private let metaLabel = UILabel()
    private let synopsisLabel = UILabel()
    private let hintLabel = UILabel()
    private let addButton = UIButton(type: .system)

    init(interactor: MediaCatalogPreviewBusinessLogic, candidate: MediaCatalogCandidate) {
        self.interactor = interactor
        self.candidate = candidate
        super.init(nibName: nil, bundle: nil)
    }

    convenience init(candidate: MediaCatalogCandidate) {
        let presenter = MediaCatalogPreviewPresenter()
        let interactor = MediaCatalogPreviewInteractor(presenter: presenter)
        self.init(interactor: interactor, candidate: candidate)
        presenter.view = self
        interactor.router = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground

        scroll.alwaysBounceVertical = true

        stack.axis = .vertical
        stack.spacing = 12
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 32, right: 16)

        kindBadge.font = TMETheme.Fonts.body(13)
        kindBadge.textColor = .secondaryLabel

        metaLabel.numberOfLines = 0
        metaLabel.font = TMETheme.Fonts.body(14)
        metaLabel.textColor = .secondaryLabel

        synopsisLabel.numberOfLines = 0
        synopsisLabel.font = TMETheme.Fonts.body(16)
        synopsisLabel.textColor = .label

        hintLabel.numberOfLines = 0
        hintLabel.font = TMETheme.Fonts.body(13)
        hintLabel.textColor = .secondaryLabel

        addButton.setTitle("Открыть форму с автозаполнением", for: .normal)
        addButton.titleLabel?.font = TMETheme.Fonts.titleSemibold(17)
        addButton.addTarget(self, action: #selector(addTapped), for: .touchUpInside)

        view.addSubview(scroll)
        scroll.addSubview(stack)
        [kindBadge, metaLabel, synopsisLabel, hintLabel, addButton].forEach { stack.addArrangedSubview($0) }

        scroll.pinTop(to: view.safeAreaLayoutGuide.topAnchor)
        scroll.pinLeft(to: view)
        scroll.pinRight(to: view)
        scroll.pinBottom(to: view)

        stack.pinTop(to: scroll.contentLayoutGuide.topAnchor)
        stack.pinBottom(to: scroll.contentLayoutGuide.bottomAnchor)
        stack.pinLeft(to: scroll.frameLayoutGuide.leadingAnchor)
        stack.pinRight(to: scroll.frameLayoutGuide.trailingAnchor)
        stack.pinWidth(to: scroll.frameLayoutGuide.widthAnchor)

        interactor.build(.init(candidate: candidate))
        interactor.loadDetailIfNeeded(.init())
    }

    @objc private func addTapped() {
        interactor.addTapped(.init())
    }
}

// MARK: - MediaCatalogPreviewDisplayLogic

extension MediaCatalogPreviewViewController: MediaCatalogPreviewDisplayLogic {
    func displayContent(_ viewModel: MediaCatalogPreviewModel.Content.ViewModel) {
        title = viewModel.title
        kindBadge.text = viewModel.kindTitle
        metaLabel.text = viewModel.metaText
        synopsisLabel.text = viewModel.synopsisText
        hintLabel.text = viewModel.hintText
        hintLabel.isHidden = viewModel.hintText == nil
    }
}

// MARK: - MediaCatalogPreviewRoutingLogic

extension MediaCatalogPreviewViewController: MediaCatalogPreviewRoutingLogic {
    func routeToCreatePrefilled(item: MediaItem) {
        let editor = MediaItemEditorBuilder.build(mode: .createPrefilled(item)) { [weak self] saved in
            MediaLibraryStore.shared.upsert(saved)
            self?.addFlowCoordinator?.popToLibraryList()
        }
        navigationController?.pushViewController(editor, animated: true)
    }
}

