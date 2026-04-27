import UIKit

/// Детализация объекта медиатеки (ТЗ п.2): постер, метаданные, статус, заметки, хэштеги.
final class MediaItemDetailViewController: UIViewController {
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

    init(item: MediaItem) {
        self.item = item
        super.init(nibName: nil, bundle: nil)
    }

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
        posterView.heightAnchor.constraint(equalToConstant: 220).isActive = true

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
            self.item.status = MediaWatchStatus.allCases[idx]
            MediaLibraryStore.shared.upsert(self.item)
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
        let fav = UIBarButtonItem(image: UIImage(systemName: favoriteSymbolName()), style: .plain, target: self, action: #selector(favoriteTapped))
        fav.accessibilityLabel = "Избранное"
        favoriteBarButton = fav
        navigationItem.rightBarButtonItems = [more, edit, fav]

        scroll.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            // Важно: скролл идёт под навбаром, чтобы `scrollEdgeAppearance` работал как на списках (blur появляется при прокрутке).
            scroll.topAnchor.constraint(equalTo: view.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor)
        ])

        [
            posterView, titleLabel, metaLabel, synopsisLabel, statusTabs, progressLabel,
            notesTitle, notesBody, tagsTitle, tagsBody
        ].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            stack.addArrangedSubview($0)
        }
        statusTabs.heightAnchor.constraint(equalToConstant: MediaLibraryFolderTabsView.preferredHeight).isActive = true

        reloadFromStore()

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
        reloadFromStore()
    }

    private func reloadFromStore() {
        if let fresh = MediaLibraryStore.shared.item(id: item.id) {
            item = fresh
        }
        applyContent()
    }

    private func applyContent() {
        titleLabel.text = item.title
        refreshRightBarButtons()

        var meta: [String] = [item.kind.title]
        if let y = item.year { meta.append(String(y)) }
        if let g = item.genre, !g.isEmpty { meta.append(g) }
        if let r = item.rating {
            meta.append(String(format: "★ %.1f/5", r))
        }
        metaLabel.text = meta.joined(separator: " · ")

        if let s = item.synopsis, !s.isEmpty {
            synopsisLabel.text = s
            synopsisLabel.textColor = .label
        } else {
            synopsisLabel.text = "Описание не указано."
            synopsisLabel.textColor = .tertiaryLabel
        }

        if let idx = MediaWatchStatus.allCases.firstIndex(of: item.status), statusTabs.selectedIndex != idx {
            statusTabs.selectedIndex = idx
        }

        progressLabel.text = progressSummary()

        notesBody.text = item.notes.isEmpty ? "—" : item.notes

        if item.hashtags.isEmpty {
            tagsBody.text = "—"
            tagsBody.textColor = .tertiaryLabel
        } else {
            tagsBody.text = item.hashtags.map { "#\($0)" }.joined(separator: "  ")
            tagsBody.textColor = TMETheme.Colors.accent
        }

        if let url = MediaLibraryStore.coverImageURL(fileName: item.coverFileName),
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
            posterView.image = UIImage(systemName: posterSymbolName(for: item.kind), withConfiguration: sym)
            applyPosterPlaceholderColorsIfNeeded()
        }
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

    private func refreshRightBarButtons() {
        favoriteBarButton?.image = UIImage(systemName: favoriteSymbolName())
    }

    private func favoriteSymbolName() -> String {
        item.isFavorite ? "star.fill" : "star"
    }

    @objc private func favoriteTapped() {
        item.isFavorite.toggle()
        MediaLibraryStore.shared.upsert(item)
        refreshRightBarButtons()
    }

    private func progressSummary() -> String {
        var parts: [String] = []
        if item.kind == .series, let s = item.progress.season, s > 0 {
            parts.append("Сезон \(s)")
        }
        if let p = item.progress.displayString(kind: item.kind) {
            parts.append(p)
        }
        return parts.isEmpty ? "Прогресс не задан" : parts.joined(separator: " · ")
    }

    @objc private func editTapped() {
        let editor = MediaItemEditorViewController(mode: .edit(existing: item)) { [weak self] updated in
            MediaLibraryStore.shared.upsert(updated)
            self?.item = updated
            self?.navigationController?.popViewController(animated: true)
        }
        navigationController?.pushViewController(editor, animated: true)
    }

    @objc private func moreTapped() {
        let ac = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        ac.addAction(UIAlertAction(title: "Поделиться", style: .default) { [weak self] _ in
            guard let self else { return }
            let text = [self.item.title, self.item.synopsis].compactMap { $0 }.joined(separator: "\n\n")
            let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
            self.present(av, animated: true)
        })
        ac.addAction(UIAlertAction(title: "Экспорт JSON", style: .default) { [weak self] _ in
            self?.presentJSONExport()
        })
        ac.addAction(UIAlertAction(title: "Удалить", style: .destructive) { [weak self] _ in
            guard let self else { return }
            MediaLibraryStore.shared.delete(id: self.item.id)
            self.popToMediaLibraryList()
        })
        ac.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        ac.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItems?.first
        present(ac, animated: true)
    }

    private func presentJSONExport() {
        reloadFromStore()
        do {
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            enc.dateEncodingStrategy = .iso8601
            let data = try enc.encode(item)
            let safeBase = item.title
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ":", with: "-")
            let name = String(safeBase.prefix(72))
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("media_\(name).json")
            try data.write(to: url, options: [.atomic])
            let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            av.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItems?.first
            present(av, animated: true)
        } catch {
            let alert = UIAlertController(title: "Не удалось сформировать JSON", message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }

    /// Возврат к списку медиатеки (в т.ч. если открывали карточку через сетку).
    private func popToMediaLibraryList() {
        guard let nav = navigationController else { return }
        if let list = nav.viewControllers.first(where: { $0 is MediaLibraryListViewController }) {
            nav.popToViewController(list, animated: true)
        } else {
            nav.popViewController(animated: true)
        }
    }
}
