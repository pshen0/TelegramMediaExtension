import UIKit

final class MediaItemDetailViewController: UIViewController {
    private let interactor: MediaItemDetailBusinessLogic
    private var item: MediaItem
    private let scroll = UIScrollView()
    private let stack = UIStackView()

    private let posterView = UIImageView()
    private let titleLabel = UILabel()
    private let metaLabel = UILabel()
    private let synopsisLabel = UILabel()
    private let statusTabs = MediaLibraryFolderTabsView(titles: MediaWatchStatus.allCases.map(\.folderTabTitle))
    private let progressLabel = UILabel()
    private let notesTitle = UILabel()
    private let notesBody = UILabel()
    private let tagsTitle = UILabel()
    private let tagsBody = UILabel()

    private var bannerColorObserver: NSObjectProtocol?
    private var posterUsesCatalogPlaceholder = false
    private var favoriteBarButton: UIBarButtonItem?

    init(interactor: MediaItemDetailBusinessLogic, item: MediaItem) {
        self.interactor = interactor
        self.item = item
        super.init(nibName: nil, bundle: nil)
    }

    convenience init(item: MediaItem) {
        let presenter = MediaItemDetailPresenter()
        let interactor = MediaItemDetailInteractor(presenter: presenter)
        self.init(interactor: interactor, item: item)
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
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.title = ""

        scroll.alwaysBounceVertical = true
        if #available(iOS 11.0, *) {
            scroll.contentInsetAdjustmentBehavior = .automatic
        }
        stack.axis = .vertical
        stack.spacing = 14
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 12, left: 16, bottom: 24, right: 16)

        posterView.contentMode = .scaleAspectFill
        posterView.clipsToBounds = true
        posterView.layer.cornerRadius = 12
        posterView.setHeight(220)

        titleLabel.font = TMETheme.Fonts.titleSemibold(22)
        titleLabel.numberOfLines = 0

        metaLabel.font = TMETheme.Fonts.body(14)
        metaLabel.textColor = .secondaryLabel
        metaLabel.numberOfLines = 0

        synopsisLabel.font = TMETheme.Fonts.body(15)
        synopsisLabel.textColor = .label
        synopsisLabel.numberOfLines = 0

        statusTabs.onSelectionChange = { [weak self] idx in
            guard let self, idx >= 0, idx < MediaWatchStatus.allCases.count else { return }
            self.interactor.updateStatus(.init(index: idx))
        }

        progressLabel.font = TMETheme.Fonts.body(14)
        progressLabel.textColor = .secondaryLabel
        progressLabel.numberOfLines = 0

        notesTitle.text = "Мои заметки"
        notesTitle.font = TMETheme.Fonts.titleSemibold(16)

        notesBody.font = TMETheme.Fonts.body(15)
        notesBody.textColor = .label
        notesBody.numberOfLines = 0

        tagsTitle.text = "Мои хэштеги"
        tagsTitle.font = TMETheme.Fonts.titleSemibold(16)

        tagsBody.font = TMETheme.Fonts.body(14)
        tagsBody.textColor = TMETheme.Colors.accent
        tagsBody.numberOfLines = 0

        let more = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), style: .plain, target: self, action: #selector(moreTapped))
        more.accessibilityLabel = "Ещё"
        let edit = UIBarButtonItem(image: UIImage(systemName: "pencil"), style: .plain, target: self, action: #selector(editTapped))
        edit.accessibilityLabel = "Изменить"
        let favSymbol = item.isFavorite ? "star.fill" : "star"
        let fav = UIBarButtonItem(image: UIImage(systemName: favSymbol), style: .plain, target: self, action: #selector(favoriteTapped))
        fav.accessibilityLabel = "Избранное"
        favoriteBarButton = fav
        navigationItem.rightBarButtonItems = [more, edit, fav]

        view.addSubview(scroll)
        scroll.addSubview(stack)

        scroll.pinTop(to: view.topAnchor)
        scroll.pinLeft(to: view)
        scroll.pinRight(to: view)
        scroll.pinBottom(to: view)
        stack.pinTop(to: scroll.contentLayoutGuide.topAnchor)
        stack.pinBottom(to: scroll.contentLayoutGuide.bottomAnchor)
        stack.pinLeft(to: scroll.frameLayoutGuide.leadingAnchor)
        stack.pinRight(to: scroll.frameLayoutGuide.trailingAnchor)
        stack.pinWidth(to: scroll.frameLayoutGuide.widthAnchor)

        [
            posterView, titleLabel, metaLabel, synopsisLabel, statusTabs, progressLabel,
            notesTitle, notesBody, tagsTitle, tagsBody
        ].forEach { stack.addArrangedSubview($0) }
        statusTabs.setHeight(Double(MediaLibraryFolderTabsView.preferredHeight))

        interactor.build(.init(item: item))
        interactor.viewDidLoad(.init())

        bannerColorObserver = NotificationCenter.default.addObserver(
            forName: .mediaLibraryBannerColorDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyPosterPlaceholderColorsIfNeeded()
        }
    }

    deinit {
        if let bannerColorObserver {
            NotificationCenter.default.removeObserver(bannerColorObserver)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        interactor.viewWillAppear(.init())
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyPosterPlaceholderColorsIfNeeded()
    }

    private func applyPosterPlaceholderColorsIfNeeded() {
        guard posterUsesCatalogPlaceholder else { return }
        posterView.tintColor = MediaLibraryHeaderBannerColor.posterPlaceholderTint(for: traitCollection)
        posterView.backgroundColor = MediaLibraryHeaderBannerColor.posterPlaceholderFill(for: traitCollection)
    }

    private func posterSymbolName(for kind: MediaItemKind) -> String {
        switch kind {
        case .film: return "film"
        case .series: return "tv"
        case .book: return "book.closed"
        case .musicAlbum: return "music.note.list"
        }
    }

    @objc private func favoriteTapped() {
        interactor.toggleFavorite(.init())
    }

    @objc private func editTapped() {
        interactor.edit(.init())
    }

    @objc private func moreTapped() {
        let ac = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        ac.addAction(UIAlertAction(title: "Поделиться", style: .default) { [weak self] _ in self?.interactor.share(.init()) })
        ac.addAction(UIAlertAction(title: "Экспорт JSON", style: .default) { [weak self] _ in self?.interactor.exportJSON(.init()) })
        ac.addAction(UIAlertAction(title: "Удалить", style: .destructive) { [weak self] _ in
            self?.interactor.delete(.init())
        })
        ac.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        ac.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItems?.first
        present(ac, animated: true)
    }

    private func popToMediaLibraryList() {
        guard let nav = navigationController else { return }
        if let list = nav.viewControllers.first(where: { $0 is MediaLibraryListViewController }) {
            nav.popToViewController(list, animated: true)
        } else {
            nav.popViewController(animated: true)
        }
    }
}

// MARK: - MediaItemDetailDisplayLogic

extension MediaItemDetailViewController: MediaItemDetailDisplayLogic {
    func displayContent(_ viewModel: MediaItemDetailModel.Content.ViewModel) {
        titleLabel.text = viewModel.title
        metaLabel.text = viewModel.metaText

        synopsisLabel.text = viewModel.synopsisText
        synopsisLabel.textColor = viewModel.synopsisIsPlaceholder ? .tertiaryLabel : .label

        if statusTabs.selectedIndex != viewModel.statusIndex {
            statusTabs.selectedIndex = viewModel.statusIndex
        }

        progressLabel.text = viewModel.progressText
        notesBody.text = viewModel.notesText

        tagsBody.text = viewModel.tagsText
        tagsBody.textColor = viewModel.tagsArePlaceholder ? .tertiaryLabel : TMETheme.Colors.accent

        favoriteBarButton?.image = UIImage(systemName: viewModel.isFavorite ? "star.fill" : "star")

        if let url = MediaLibraryStore.coverImageURL(fileName: viewModel.coverFileName),
           let data = try? Data(contentsOf: url),
           let img = UIImage(data: data) {
            posterUsesCatalogPlaceholder = false
            posterView.contentMode = .scaleAspectFill
            posterView.image = img
            posterView.backgroundColor = .clear
            posterView.tintColor = nil
        } else {
            posterUsesCatalogPlaceholder = true
            posterView.contentMode = .center
            let sym = UIImage.SymbolConfiguration(pointSize: 56, weight: .medium)
            posterView.image = UIImage(systemName: posterSymbolName(for: viewModel.kind), withConfiguration: sym)
            applyPosterPlaceholderColorsIfNeeded()
        }
    }
}

// MARK: - MediaItemDetailRoutingLogic

extension MediaItemDetailViewController: MediaItemDetailRoutingLogic {
    func routeToEdit(item: MediaItem) {
        let editor = MediaItemEditorBuilder.build(mode: .edit(existing: item)) { [weak self] updated in
            MediaLibraryStore.shared.upsert(updated)
            self?.navigationController?.popViewController(animated: true)
        }
        navigationController?.pushViewController(editor, animated: true)
    }

    func routeToShare(text: String) {
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        present(av, animated: true)
    }

    func routeToExport(url: URL) {
        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        av.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItems?.first
        present(av, animated: true)
    }

    func routeBackToMediaLibraryList() {
        popToMediaLibraryList()
    }

    func routeToError(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
