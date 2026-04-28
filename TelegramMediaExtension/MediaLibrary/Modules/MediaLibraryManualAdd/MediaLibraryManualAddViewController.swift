import UIKit

final class MediaLibraryManualAddViewController: UIViewController {
    weak var coordinator: AddToMediaLibraryViewController?

    private let interactor: MediaLibraryManualAddBusinessLogic
    private var bannerColorObserver: NSObjectProtocol?
    private weak var openFormButton: UIButton?

    init(interactor: MediaLibraryManualAddBusinessLogic) {
        self.interactor = interactor
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

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

        view.addSubview(label)
        view.addSubview(button)

        label.pinLeft(to: view.leadingAnchor, 24)
        label.pinRight(to: view.trailingAnchor, 24)
        label.pinCenterX(to: view.centerXAnchor)
        label.pinCenterY(to: view.centerYAnchor, -32)

        button.pinTop(to: label.bottomAnchor, 24)
        button.pinCenterX(to: view.centerXAnchor)

        bannerColorObserver = NotificationCenter.default.addObserver(
            forName: .mediaLibraryBannerColorDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyChromeAccent()
        }

        interactor.viewDidLoad(.init())
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
        interactor.openForm(.init())
    }
}

// MARK: - MediaLibraryManualAddRoutingLogic

extension MediaLibraryManualAddViewController: MediaLibraryManualAddRoutingLogic {
    func routeToCreateForm() {
        let editor = MediaItemEditorBuilder.build(mode: .create) { [weak self] item in
            MediaLibraryStore.shared.upsert(item)
            self?.coordinator?.popToLibraryList()
        }
        navigationController?.pushViewController(editor, animated: true)
    }
}

