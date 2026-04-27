import UIKit

/// Экран «Добавить в медиатеку»: вкладки «Поиск в базах» и «Создать вручную» (ТЗ п.3).
final class AddToMediaLibraryViewController: UIViewController {
    private let segment = UISegmentedControl(items: ["Поиск в базах", "Создать вручную"])
    private let container = UIView()

    private let catalogSearch = MediaCatalogSearchViewController(style: .insetGrouped)
    private let manualPlaceholder = MediaLibraryManualAddViewController()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = "Добавить в медиатеку"

        segment.selectedSegmentIndex = 0
        segment.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)

        catalogSearch.addFlowCoordinator = self
        addChild(catalogSearch)
        addChild(manualPlaceholder)
        manualPlaceholder.coordinator = self

        view.addSubview(segment)
        view.addSubview(container)
        container.addSubview(catalogSearch.view)
        container.addSubview(manualPlaceholder.view)
        catalogSearch.didMove(toParent: self)
        manualPlaceholder.didMove(toParent: self)

        segmentChanged()
    }

    func popToLibraryList() {
        guard let nav = navigationController else { return }
        if let list = nav.viewControllers.first(where: { $0 is MediaLibraryListViewController }) {
            nav.popToViewController(list, animated: true)
        } else {
            nav.popViewController(animated: true)
        }
    }

    @objc private func segmentChanged() {
        let showSearch = segment.selectedSegmentIndex == 0
        catalogSearch.view.isHidden = !showSearch
        manualPlaceholder.view.isHidden = showSearch
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let safe = view.safeAreaInsets
        let w = view.bounds.width
        let segH: CGFloat = 32
        segment.frame = CGRect(x: 16, y: safe.top + 8, width: w - 32, height: segH)
        let y = segment.frame.maxY + 8
        container.frame = CGRect(x: 0, y: y, width: w, height: view.bounds.height - y)
        catalogSearch.view.frame = container.bounds
        manualPlaceholder.view.frame = container.bounds
    }
}

/// Заглушка вкладки «Создать вручную» + переход к полной форме.
private final class MediaLibraryManualAddViewController: UIViewController {
    weak var coordinator: AddToMediaLibraryViewController?
    private var bannerColorObserver: NSObjectProtocol?
    private weak var openFormButton: UIButton?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground

        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = TMETheme.Fonts.body(15)
        label.textColor = TMETheme.Colors.secondaryText
        label.text = "Для контента, которого нет в публичных базах, заполните карточку вручную: тип, название, год, обложка, описание, статус и прогресс."

        let button = UIButton(type: .system)
        button.setTitle("Заполнить форму", for: .normal)
        button.titleLabel?.font = TMETheme.Fonts.titleSemibold(17)
        openFormButton = button
        applyChromeAccent()
        button.addTarget(self, action: #selector(openForm), for: .touchUpInside)

        label.translatesAutoresizingMaskIntoConstraints = false
        button.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        view.addSubview(button)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -32),
            button.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 24),
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])

        bannerColorObserver = NotificationCenter.default.addObserver(
            forName: .mediaLibraryBannerColorDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyChromeAccent()
        }
    }

    deinit {
        if let bannerColorObserver {
            NotificationCenter.default.removeObserver(bannerColorObserver)
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyChromeAccent()
    }

    private func applyChromeAccent() {
        openFormButton?.tintColor = MediaLibraryHeaderBannerColor.catalogChromeAccent(for: traitCollection)
    }

    @objc private func openForm() {
        let editor = MediaItemEditorViewController(mode: .create) { [weak self] item in
            MediaLibraryStore.shared.upsert(item)
            self?.coordinator?.popToLibraryList()
        }
        navigationController?.pushViewController(editor, animated: true)
    }
}
