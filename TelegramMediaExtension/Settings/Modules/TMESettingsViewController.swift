import UIKit

final class TMESettingsViewController: UIViewController {
    private let header = UIView()
    private let headerAvatar = UIImageView()
    private let headerName = UILabel()
    private let headerMeta = UILabel()
    private var headerEditButton: LiquidGlassBarButtonView?
    private var headerQRButton: LiquidGlassBarButtonView?

    private let contentStack = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()

        title = nil
        view.backgroundColor = .systemBackground
        navigationItem.largeTitleDisplayMode = .never

        buildHeader()
        buildContent()
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
        header.translatesAutoresizingMaskIntoConstraints = false
        header.backgroundColor = UIColor(red: 0.53, green: 0.42, blue: 0.77, alpha: 1)

        headerAvatar.translatesAutoresizingMaskIntoConstraints = false
        headerAvatar.contentMode = .scaleAspectFill
        headerAvatar.clipsToBounds = true
        headerAvatar.layer.cornerRadius = 50
        if #available(iOS 13.0, *) {
            headerAvatar.layer.cornerCurve = .continuous
        }
        // Мок-аватар из ассетов.
        headerAvatar.image = UIImage(named: "cat1")
        headerAvatar.tintColor = nil
        headerAvatar.backgroundColor = UIColor.white.withAlphaComponent(0.12)

        headerName.translatesAutoresizingMaskIntoConstraints = false
        headerName.font = TMETheme.Fonts.titleSemibold(28)
        headerName.textColor = .white
        headerName.textAlignment = .center
        headerName.text = "Какой-то Мявкин"
        headerName.numberOfLines = 1
        headerName.adjustsFontSizeToFitWidth = true
        headerName.minimumScaleFactor = 0.75

        headerMeta.translatesAutoresizingMaskIntoConstraints = false
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
        edit.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(edit)

        let qr = LiquidGlassBarButtonView(symbolName: "qrcode.viewfinder", accessibilityLabel: "Сканировать QR", symbolPointSize: 17, side: 42) {}
        qr.updateBlurStyle(for: traitCollection)
        qr.isUserInteractionEnabled = false
        headerQRButton = qr
        qr.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(qr)

        view.addSubview(header)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 276),

            edit.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16),
            edit.topAnchor.constraint(equalTo: header.safeAreaLayoutGuide.topAnchor, constant: 10),
            edit.widthAnchor.constraint(equalToConstant: 72),
            edit.heightAnchor.constraint(equalToConstant: 42),

            qr.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
            qr.topAnchor.constraint(equalTo: header.safeAreaLayoutGuide.topAnchor, constant: 10),
            qr.widthAnchor.constraint(equalToConstant: 42),
            qr.heightAnchor.constraint(equalToConstant: 42),

            headerAvatar.centerXAnchor.constraint(equalTo: header.centerXAnchor),
            headerAvatar.topAnchor.constraint(equalTo: header.safeAreaLayoutGuide.topAnchor, constant: 10),
            headerAvatar.widthAnchor.constraint(equalToConstant: 100),
            headerAvatar.heightAnchor.constraint(equalToConstant: 100),

            headerName.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
            headerName.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16),
            headerName.topAnchor.constraint(equalTo: headerAvatar.bottomAnchor, constant: 14),

            headerMeta.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
            headerMeta.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16),
            headerMeta.topAnchor.constraint(equalTo: headerName.bottomAnchor, constant: 6),
            headerMeta.bottomAnchor.constraint(lessThanOrEqualTo: header.bottomAnchor, constant: -14)
        ])
    }

    private func buildContent() {
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 20

        let block1 = makePillGroup(rows: [
            makeStaticRow(icon: "face.smiling", title: "Сменить эмодзи-статус", iconScale: 0.85),
            makeStaticRow(icon: "paintpalette", title: "Изменить цвет профиля"),
            makeStaticRow(icon: "camera", title: "Изменить фотографию")
        ])

        let myProfileGroup = makePillGroup(rows: [
            makeStaticRow(icon: "profile", title: "Мой профиль", showsChevron: true)
        ])

        let libraryGroup = makePillGroup(rows: [
            makeNavigationRow(icon: "media", title: "Медиатека") { [weak self] in
                self?.navigationController?.pushViewController(MediaLibraryBuilder.build(), animated: true)
            },
            makeNavigationRow(icon: "anounce", title: "Мои анонсы") { [weak self] in
                self?.navigationController?.pushViewController(AnnouncementsBuilder.build(), animated: true)
            }
        ])

        [block1, myProfileGroup, libraryGroup].forEach { contentStack.addArrangedSubview($0) }

        view.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 22),
            contentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }

    private func makePillGroup(rows: [UIView]) -> UIView {
        let clip = UIView()
        clip.translatesAutoresizingMaskIntoConstraints = false
        clip.backgroundColor = UIColor { tc in
            tc.userInterfaceStyle == .dark ? UIColor(white: 0.12, alpha: 1) : UIColor(white: 0.96, alpha: 1)
        }
        clip.layer.cornerRadius = 24
        if #available(iOS 13.0, *) { clip.layer.cornerCurve = .continuous }
        clip.clipsToBounds = true

        let stack = UIStackView(arrangedSubviews: rows)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 0
        clip.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: clip.topAnchor),
            stack.leadingAnchor.constraint(equalTo: clip.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: clip.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: clip.bottomAnchor)
        ])
        return clip
    }

    private func makeStaticRow(icon: String, title: String, showsChevron: Bool = false, iconScale: CGFloat? = nil) -> UIView {
        let row = SettingsRowView()
        row.configure(icon: UIImage(named: icon) ?? UIImage(systemName: icon), iconText: nil, title: title, detail: nil, showsChevron: showsChevron)
        if let iconScale {
            row.iconScale = iconScale
        }
        row.onTap = nil
        return row
    }

    private func makeStaticRow(iconText: String, title: String) -> UIView {
        let row = SettingsRowView()
        row.configure(icon: nil, iconText: iconText, title: title, detail: nil, showsChevron: false)
        row.onTap = nil
        return row
    }

    private func makeNavigationRow(icon: String, title: String, onTap: @escaping () -> Void) -> UIView {
        let row = SettingsRowView()
        row.configure(icon: UIImage(named: icon) ?? UIImage(systemName: icon), iconText: nil, title: title, detail: nil, showsChevron: true)
        row.onTap = onTap
        return row
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

        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear

        iconHolder.translatesAutoresizingMaskIntoConstraints = false
        // Без серых квадратов под иконками — как в Telegram.
        iconHolder.backgroundColor = .clear

        iconImage.translatesAutoresizingMaskIntoConstraints = false
        iconImage.contentMode = .scaleAspectFit
        iconImage.tintColor = TMETheme.Colors.accent

        iconText.translatesAutoresizingMaskIntoConstraints = false
        iconText.font = TMETheme.Fonts.titleSemibold(14)
        iconText.textColor = TMETheme.Colors.accent
        iconText.textAlignment = .center

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = TMETheme.Fonts.body(17)
        titleLabel.textColor = .label

        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.font = TMETheme.Fonts.body(15)
        detailLabel.textColor = .secondaryLabel
        detailLabel.textAlignment = .right
        detailLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.tintColor = .tertiaryLabel

        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.backgroundColor = UIColor.separator.withAlphaComponent(0.35)

        addSubview(iconHolder)
        iconHolder.addSubview(iconImage)
        iconHolder.addSubview(iconText)
        addSubview(titleLabel)
        addSubview(detailLabel)
        addSubview(chevron)
        addSubview(divider)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 54),

            iconHolder.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            iconHolder.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconHolder.widthAnchor.constraint(equalToConstant: 34),
            iconHolder.heightAnchor.constraint(equalToConstant: 34),

            iconImage.centerXAnchor.constraint(equalTo: iconHolder.centerXAnchor),
            iconImage.centerYAnchor.constraint(equalTo: iconHolder.centerYAnchor),
            iconImage.widthAnchor.constraint(equalToConstant: 24),
            iconImage.heightAnchor.constraint(equalToConstant: 24),

            iconText.centerXAnchor.constraint(equalTo: iconHolder.centerXAnchor),
            iconText.centerYAnchor.constraint(equalTo: iconHolder.centerYAnchor),

            chevron.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            chevron.centerYAnchor.constraint(equalTo: centerYAnchor),

            detailLabel.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -8),
            detailLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            detailLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 0),

            titleLabel.leadingAnchor.constraint(equalTo: iconHolder.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: detailLabel.leadingAnchor, constant: -8),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            divider.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: trailingAnchor),
            divider.bottomAnchor.constraint(equalTo: bottomAnchor),
            divider.heightAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale)
        ])

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

