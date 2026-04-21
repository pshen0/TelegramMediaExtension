import UIKit

/// Предпросмотр объекта из каталога перед добавлением в медиатеку (ТЗ п.3).
final class MediaCatalogPreviewViewController: UIViewController {
    private let candidate: MediaCatalogCandidate
    weak var addFlowCoordinator: AddToMediaLibraryViewController?

    private let scroll = UIScrollView()
    private let stack = UIStackView()

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

        let meta = UILabel()
        meta.numberOfLines = 0
        meta.font = TMETheme.Fonts.body(14)
        meta.textColor = .secondaryLabel
        var metaParts: [String] = []
        if let y = candidate.year { metaParts.append(String(y)) }
        if let g = candidate.genre, !g.isEmpty { metaParts.append(g) }
        if let r = candidate.rating { metaParts.append(String(format: "★ %.1f/5", r)) }
        meta.text = metaParts.joined(separator: " · ")

        let synopsis = UILabel()
        synopsis.numberOfLines = 0
        synopsis.font = TMETheme.Fonts.body(16)
        synopsis.textColor = .label
        synopsis.text = candidate.synopsis

        let addButton = UIButton(type: .system)
        addButton.setTitle("Добавить в мою медиатеку", for: .normal)
        addButton.titleLabel?.font = TMETheme.Fonts.titleSemibold(17)
        addButton.addTarget(self, action: #selector(addTapped), for: .touchUpInside)

        [kindBadge, meta, synopsis, addButton].forEach {
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
    }

    @objc private func addTapped() {
        let item = candidate.makeMediaItem()
        MediaLibraryStore.shared.upsert(item)
        addFlowCoordinator?.popToLibraryList()
    }
}
