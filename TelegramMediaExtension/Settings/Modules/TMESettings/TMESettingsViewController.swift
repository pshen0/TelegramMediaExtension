import UIKit

final class TMESettingsViewController: UIViewController {
    private let interactor: TMESettingsBusinessLogic
    private let header = UIView()
    private let headerAvatar = UIImageView()
    private let headerName = UILabel()
    private let headerMeta = UILabel()
    private var headerEditButton: LiquidGlassBarButtonView?
    private var headerQRButton: LiquidGlassBarButtonView?

    private let contentStack = UIStackView()
    private var groups: [TMESettingsModel.Rows.Group] = []

    init(interactor: TMESettingsBusinessLogic) {
        self.interactor = interactor
        super.init(nibName: nil, bundle: nil)
    }

    convenience init() {
        let presenter = TMESettingsPresenter()
        let interactor = TMESettingsInteractor(presenter: presenter)
        self.init(interactor: interactor)
        presenter.view = self
        interactor.router = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = nil
        view.backgroundColor = .systemBackground
        navigationItem.largeTitleDisplayMode = .never

        buildHeader()
        buildContent()

        interactor.viewDidLoad(.init())
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
        headerEditButton?.updateBlurStyle(for: traitCollection)
        headerQRButton?.updateBlurStyle(for: traitCollection)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        headerEditButton?.updateBlurStyle(for: traitCollection)
        headerQRButton?.updateBlurStyle(for: traitCollection)
    }

    private func buildHeader() {
        header.backgroundColor = UIColor(red: 0.53, green: 0.42, blue: 0.77, alpha: 1)

        headerAvatar.contentMode = .scaleAspectFill
        headerAvatar.clipsToBounds = true
        headerAvatar.layer.cornerRadius = 50
        if #available(iOS 13.0, *) {
            headerAvatar.layer.cornerCurve = .continuous
        }
        headerAvatar.image = UIImage(named: "cat1")
        headerAvatar.tintColor = nil
        headerAvatar.backgroundColor = UIColor.white.withAlphaComponent(0.12)

        headerName.font = TMETheme.Fonts.titleSemibold(28)
        headerName.textColor = .white
        headerName.textAlignment = .center
        headerName.text = "Какой-то Мявкин"
        headerName.numberOfLines = 1
        headerName.adjustsFontSizeToFitWidth = true
        headerName.minimumScaleFactor = 0.75

        headerMeta.font = TMETheme.Fonts.body(16)
        headerMeta.textColor = UIColor.white.withAlphaComponent(0.78)
        headerMeta.textAlignment = .center
        headerMeta.text = "+7 955 555 55 55 · @meow_meowich"
        headerMeta.numberOfLines = 1
        headerMeta.adjustsFontSizeToFitWidth = true
        headerMeta.minimumScaleFactor = 0.8

        header.addSubview(headerAvatar)
        header.addSubview(headerName)
        header.addSubview(headerMeta)
        
        let edit = LiquidGlassBarButtonView(
            title: "Изм.",
            accessibilityLabel: "Изменить",
            size: CGSize(width: 72, height: 42),
            titleFont: TMETheme.Fonts.titleSemibold(17)
        ) {}
        edit.updateBlurStyle(for: traitCollection)
        headerEditButton = edit
        header.addSubview(edit)

        let qr = LiquidGlassBarButtonView(symbolName: "qrcode.viewfinder", accessibilityLabel: "Сканировать QR", symbolPointSize: 17, side: 42) {}
        qr.updateBlurStyle(for: traitCollection)
        qr.isUserInteractionEnabled = false
        headerQRButton = qr
        header.addSubview(qr)

        view.addSubview(header)

        header.pinTop(to: view.topAnchor)
        header.pinLeft(to: view)
        header.pinRight(to: view)
        header.setHeight(276)

        edit.pinTop(to: header.safeAreaLayoutGuide.topAnchor, 10)
        edit.pinRight(to: header.trailingAnchor, 16)
        edit.setWidth(72)
        edit.setHeight(42)

        qr.pinTop(to: header.safeAreaLayoutGuide.topAnchor, 10)
        qr.pinLeft(to: header.leadingAnchor, 16)
        qr.setWidth(42)
        qr.setHeight(42)

        headerAvatar.pinTop(to: header.safeAreaLayoutGuide.topAnchor, 10)
        headerAvatar.pinCenterX(to: header.centerXAnchor)
        headerAvatar.setWidth(100)
        headerAvatar.setHeight(100)

        headerName.pinTop(to: headerAvatar.bottomAnchor, 14)
        headerName.pinLeft(to: header.leadingAnchor, 16)
        headerName.pinRight(to: header.trailingAnchor, 16)

        headerMeta.pinTop(to: headerName.bottomAnchor, 6)
        headerMeta.pinLeft(to: header.leadingAnchor, 16)
        headerMeta.pinRight(to: header.trailingAnchor, 16)
        headerMeta.pinBottom(to: header.bottomAnchor, 14, .lsOE)
    }

    private func buildContent() {
        contentStack.axis = .vertical
        contentStack.spacing = 20

        view.addSubview(contentStack)
        contentStack.pinTop(to: header.bottomAnchor, 22)
        contentStack.pinLeft(to: view.leadingAnchor, 16)
        contentStack.pinRight(to: view.trailingAnchor, 16)
        contentStack.pinBottom(to: view.safeAreaLayoutGuide.bottomAnchor, 16, .lsOE)
    }

    private func makePillGroup(rows: [UIView]) -> UIView {
        let clip = UIView()
        clip.backgroundColor = UIColor { tc in
            tc.userInterfaceStyle == .dark ? UIColor(white: 0.12, alpha: 1) : UIColor(white: 0.96, alpha: 1)
        }
        clip.layer.cornerRadius = 24
        if #available(iOS 13.0, *) { clip.layer.cornerCurve = .continuous }
        clip.clipsToBounds = true

        let stack = UIStackView(arrangedSubviews: rows)
        stack.axis = .vertical
        stack.spacing = 0
        clip.addSubview(stack)

        stack.pin(to: clip)
        return clip
    }

    private func presentBackendURLPrompt() {
        let current = BackendAuthStore.shared.baseURL.absoluteString
        let ac = UIAlertController(
            title: "Backend URL",
            message: "Укажите адрес бекенда.\nДля другого устройства это должен быть IP вашего Mac в сети, например: http://192.168.1.10:8000",
            preferredStyle: .alert
        )
        ac.addTextField { tf in
            tf.text = current
            tf.autocapitalizationType = .none
            tf.autocorrectionType = .no
            tf.keyboardType = .URL
            tf.placeholder = "http://<ip>:8000"
        }
        ac.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        ac.addAction(UIAlertAction(title: "Сохранить", style: .default) { [weak self] _ in
            let raw = (ac.textFields?.first?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard let url = URL(string: raw), url.scheme != nil, url.host != nil else {
                let err = UIAlertController(title: "Некорректный URL", message: nil, preferredStyle: .alert)
                err.addAction(UIAlertAction(title: "Ок", style: .default))
                self?.present(err, animated: true)
                return
            }
            BackendAuthStore.shared.baseURL = url

            self?.contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            self?.buildContent()
        })
        present(ac, animated: true)
    }
}

private final class SettingsRowView: UIControl {
    var onTap: (() -> Void)?
    var iconScale: CGFloat = 1 { didSet { iconImage.transform = CGAffineTransform(scaleX: iconScale, y: iconScale) } }

    private let iconHolder = UIView()
    private let iconImage = UIImageView()
    private let iconText = UILabel()
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
    private let divider = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        iconHolder.backgroundColor = .clear

        iconImage.contentMode = .scaleAspectFit
        iconImage.tintColor = TMETheme.Colors.accent

        iconText.font = TMETheme.Fonts.titleSemibold(14)
        iconText.textColor = TMETheme.Colors.accent
        iconText.textAlignment = .center

        titleLabel.font = TMETheme.Fonts.body(17)
        titleLabel.textColor = .label

        detailLabel.font = TMETheme.Fonts.body(15)
        detailLabel.textColor = .secondaryLabel
        detailLabel.textAlignment = .right
        detailLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        chevron.tintColor = .tertiaryLabel

        divider.backgroundColor = UIColor.separator.withAlphaComponent(0.35)

        addSubview(iconHolder)
        iconHolder.addSubview(iconImage)
        iconHolder.addSubview(iconText)
        addSubview(titleLabel)
        addSubview(detailLabel)
        addSubview(chevron)
        addSubview(divider)

        setHeight(56)

        iconHolder.pinLeft(to: leadingAnchor, 14)
        iconHolder.pinCenterY(to: centerYAnchor)
        iconHolder.setWidth(38)
        iconHolder.setHeight(38)

        iconImage.pinCenterX(to: iconHolder.centerXAnchor)
        iconImage.pinCenterY(to: iconHolder.centerYAnchor)
        iconImage.setWidth(28)
        iconImage.setHeight(28)

        iconText.pinCenterX(to: iconHolder.centerXAnchor)
        iconText.pinCenterY(to: iconHolder.centerYAnchor)

        chevron.pinRight(to: trailingAnchor, 14)
        chevron.pinCenterY(to: centerYAnchor)

        detailLabel.pinRight(to: chevron.leadingAnchor, 8)
        detailLabel.pinCenterY(to: centerYAnchor)

        titleLabel.pinLeft(to: iconHolder.trailingAnchor, 12)
        titleLabel.pinRight(to: detailLabel.leadingAnchor, 8, .lsOE)
        titleLabel.pinCenterY(to: centerYAnchor)

        divider.pinLeft(to: titleLabel.leadingAnchor)
        divider.pinRight(to: trailingAnchor)
        divider.pinBottom(to: bottomAnchor)
        divider.setHeight(Double(1.0 / UIScreen.main.scale))

        addTarget(self, action: #selector(tapped), for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(icon: UIImage?, iconText: String?, title: String, detail: String?, showsChevron: Bool) {
        titleLabel.text = title
        detailLabel.text = detail
        detailLabel.isHidden = (detail == nil)

        chevron.isHidden = !showsChevron
        isAccessibilityElement = true
        accessibilityLabel = title
        accessibilityTraits = showsChevron ? [.button] : []

        if let icon {
            iconImage.image = icon
            iconImage.isHidden = false
            self.iconText.text = nil
            self.iconText.isHidden = true
        } else if let iconText {
            self.iconText.text = iconText
            self.iconText.isHidden = false
            iconImage.image = nil
            iconImage.isHidden = true
        } else {
            self.iconText.text = nil
            self.iconText.isHidden = true
            iconImage.image = nil
            iconImage.isHidden = true
        }
    }

    override var isHighlighted: Bool {
        didSet {
            guard onTap != nil else { return }
            alpha = isHighlighted ? 0.6 : 1
        }
    }

    @objc private func tapped() {
        onTap?()
    }
}

extension TMESettingsViewController: TMESettingsDisplayLogic {
    func displayRows(_ viewModel: TMESettingsModel.Rows.ViewModel) {
        groups = viewModel.groups
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for group in groups {
            let rows: [UIView] = group.rows.map { r in
                let row = SettingsRowView()
                row.configure(
                    icon: UIImage(named: r.iconName) ?? UIImage(systemName: r.iconName),
                    iconText: nil,
                    title: r.title,
                    detail: r.detail,
                    showsChevron: r.showsChevron
                )
                if let s = r.iconScale {
                    row.iconScale = s
                }
                if let action = r.action {
                    row.onTap = { [weak self] in self?.interactor.didSelectAction(action) }
                } else {
                    row.onTap = nil
                }
                return row
            }
            contentStack.addArrangedSubview(makePillGroup(rows: rows))
        }
    }
}

extension TMESettingsViewController: TMESettingsRoutingLogic {
    func routeToMediaLibrary() {
        navigationController?.pushViewController(MediaLibraryBuilder.build(), animated: true)
    }

    func routeToAnnouncements() {
        navigationController?.pushViewController(AnnouncementsBuilder.build(), animated: true)
    }

    func routeToBackendURLPrompt() {
        presentBackendURLPrompt()
    }
}

