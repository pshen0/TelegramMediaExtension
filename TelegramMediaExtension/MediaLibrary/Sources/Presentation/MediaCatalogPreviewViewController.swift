import UIKit

/// Предпросмотр объекта из каталога; для TMDB подгружает детали (серии, год, жанр, хронометраж) и открывает форму редактора с предзаполнением.
final class MediaCatalogPreviewViewController: UIViewController {
    private let candidate: MediaCatalogCandidate
    weak var addFlowCoordinator: AddToMediaLibraryViewController?

    private let scroll = UIScrollView()
    private let stack = UIStackView()
    private let metaLabel = UILabel()
    private let synopsisLabel = UILabel()
    private let hintLabel = UILabel()
    private let addButton = UIButton(type: .system)

    private var loadedDetail: TMDBClient.DetailMetadata?

    init(candidate: MediaCatalogCandidate) {
        self.candidate = candidate
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = candidate.title

        scroll.alwaysBounceVertical = true
        stack.axis = .vertical
        stack.spacing = 12
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 32, right: 16)

        let kindBadge = UILabel()
        kindBadge.text = candidate.kind.title
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
        hintLabel.text = TMDBClient.isConfigured && candidate.id.hasPrefix("tmdb-")
            ? "Подтягиваем описание и число серий из каталога TMDB…"
            : nil
        hintLabel.isHidden = hintLabel.text == nil

        addButton.setTitle("Открыть форму с автозаполнением", for: .normal)
        addButton.titleLabel?.font = TMETheme.Fonts.titleSemibold(17)
        addButton.addTarget(self, action: #selector(addTapped), for: .touchUpInside)

        [kindBadge, metaLabel, synopsisLabel, hintLabel, addButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            stack.addArrangedSubview($0)
        }

        scroll.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor)
        ])

        refreshTexts()
        loadTMDBDetailIfNeeded()
    }

    private func loadTMDBDetailIfNeeded() {
        guard TMDBClient.isConfigured, candidate.id.hasPrefix("tmdb-") else {
            hintLabel.isHidden = true
            return
        }
        Task {
            let detail = await TMDBClient.fetchDetail(candidateId: candidate.id)
            await MainActor.run {
                self.loadedDetail = detail
                self.hintLabel.isHidden = true
                self.refreshTexts()
            }
        }
    }

    private func refreshTexts() {
        let d = loadedDetail
        var metaParts: [String] = []
        let year = d?.year ?? candidate.year
        if let y = year { metaParts.append(String(y)) }
        let genre = d?.genre ?? candidate.genre
        if let g = genre, !g.isEmpty { metaParts.append(g) }
        let rating = d?.rating ?? candidate.rating
        if let r = rating { metaParts.append(String(format: "★ %.1f/5", r)) }
        if candidate.kind == .series {
            if let ep = d?.totalEpisodes, ep > 0 {
                metaParts.append("\(ep) эп.")
            }
            if let ss = d?.numberOfSeasons, ss > 0 {
                metaParts.append("\(ss) сез.")
            }
        }
        if candidate.kind == .film, let run = d?.runtimeMinutes, run > 0 {
            metaParts.append("\(run) мин")
        }
        metaLabel.text = metaParts.joined(separator: " · ")

        let syn: String = {
            if let s = d?.synopsis?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
                return s
            }
            return candidate.synopsis.trimmingCharacters(in: .whitespacesAndNewlines)
        }()
        synopsisLabel.text = syn.isEmpty ? "Нет описания." : syn
    }

    @objc private func addTapped() {
        let item = candidate.makeMediaItem(detail: loadedDetail)
        let editor = MediaItemEditorViewController(mode: .createPrefilled(item)) { [weak self] saved in
            MediaLibraryStore.shared.upsert(saved)
            self?.addFlowCoordinator?.popToLibraryList()
        }
        navigationController?.pushViewController(editor, animated: true)
    }
}
