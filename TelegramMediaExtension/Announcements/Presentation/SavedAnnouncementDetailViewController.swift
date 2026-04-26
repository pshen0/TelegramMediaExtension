import SafariServices
import UIKit

/// Карточка сохранённого анонса: баннер с нижним градиентом и заголовком на нём; блок деталей без прокрутки.
final class SavedAnnouncementDetailViewController: UIViewController {
    private let announcementId: UUID
    private let store = CommunityStore.shared

    private let bannerView = UIImageView()
    private var bannerHeightConstraint: NSLayoutConstraint!
    /// Было 260 pt — увеличение на ⅓: 260 × 4/3 (высота задаётся только после загрузки JPEG).
    private static let bannerImageBaseHeight: CGFloat = 260
    private static var bannerImageHeight: CGFloat { (bannerImageBaseHeight * 4.0 / 3.0).rounded() }

    private let muteOverlay = HeroBottomFadeView()
    private let heroTitleLabel = UILabel()
    private let detailsPanel = UIView()
    private let contentStack = UIStackView()
    private var lastLoadedAnnouncementImageFileName: String?
    private weak var announcementLinkButton: UIButton?

    private static let fieldSpacing: CGFloat = 16

    init(announcement: SavedAnnouncement) {
        announcementId = announcement.id
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func currentAnnouncement() -> SavedAnnouncement? {
        store.savedAnnouncements.first { $0.id == announcementId }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.title = ""

        bannerView.contentMode = .scaleAspectFill
        bannerView.clipsToBounds = true
        bannerView.backgroundColor = .black

        muteOverlay.translatesAutoresizingMaskIntoConstraints = false
        muteOverlay.isUserInteractionEnabled = false

        heroTitleLabel.font = TMETheme.Fonts.titleSemibold(22)
        heroTitleLabel.textColor = .white
        heroTitleLabel.numberOfLines = 3
        heroTitleLabel.lineBreakMode = .byTruncatingTail
        heroTitleLabel.layer.shadowColor = UIColor.black.cgColor
        heroTitleLabel.layer.shadowOpacity = 0.55
        heroTitleLabel.layer.shadowRadius = 5
        heroTitleLabel.layer.shadowOffset = CGSize(width: 0, height: 1)
        heroTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        contentStack.axis = .vertical
        contentStack.spacing = Self.fieldSpacing
        /// Низ стека не крепим к низу панели: панель тянется до safe area, и при привязке top+bottom `UIStackView`
        /// с `distribution == .fill` растягивает arranged views по вертикали — огромный пустой блок над «Дата и время».
        contentStack.isLayoutMarginsRelativeArrangement = true
        /// Верхний inset = расстоянию между полями (отступ от картинки до первого поля такой же).
        contentStack.layoutMargins = UIEdgeInsets(top: Self.fieldSpacing, left: 16, bottom: 20, right: 16)

        bannerView.translatesAutoresizingMaskIntoConstraints = false
        detailsPanel.translatesAutoresizingMaskIntoConstraints = false
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(bannerView)
        bannerView.addSubview(muteOverlay)
        bannerView.addSubview(heroTitleLabel)
        view.addSubview(detailsPanel)
        detailsPanel.addSubview(contentStack)
        detailsPanel.backgroundColor = .systemGroupedBackground
        detailsPanel.layer.cornerCurve = .continuous
        detailsPanel.layer.cornerRadius = 14
        detailsPanel.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        detailsPanel.clipsToBounds = true

        bannerHeightConstraint = bannerView.setHeight(0)

        bannerView.pinTop(to: view.topAnchor)
        bannerView.pinLeft(to: view)
        bannerView.pinRight(to: view)

        muteOverlay.pinLeft(to: bannerView)
        muteOverlay.pinRight(to: bannerView)
        muteOverlay.pinBottom(to: bannerView)
        muteOverlay.setHeight(140)

        heroTitleLabel.pinLeft(to: bannerView.leadingAnchor, 16)
        heroTitleLabel.pinRight(to: bannerView.trailingAnchor, 16)
        heroTitleLabel.pinBottom(to: bannerView.bottomAnchor, 16)

        detailsPanel.pinTop(to: bannerView.bottomAnchor)
        detailsPanel.pinLeft(to: view)
        detailsPanel.pinRight(to: view)
        detailsPanel.pinBottom(to: view.safeAreaLayoutGuide.bottomAnchor)

        contentStack.pinTop(to: detailsPanel.topAnchor)
        contentStack.pinLeft(to: detailsPanel.leadingAnchor)
        contentStack.pinRight(to: detailsPanel.trailingAnchor)
        contentStack.bottomAnchor.constraint(lessThanOrEqualTo: detailsPanel.bottomAnchor, constant: -20).isActive = true

        let edit = UIBarButtonItem(
            image: UIImage(systemName: "pencil"),
            style: .plain,
            target: self,
            action: #selector(editTapped)
        )
        edit.accessibilityLabel = "Изменить"
        navigationItem.rightBarButtonItem = edit
        applyEditBarButtonTint()

        store.loadIfNeeded()
        loadBannerImageIfNeeded()
        rebuildContentStack()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard currentAnnouncement() != nil else {
            navigationController?.popViewController(animated: true)
            return
        }
        loadBannerImageIfNeeded()
        rebuildContentStack()
        applyEditBarButtonTint()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyEditBarButtonTint()
        if let b = announcementLinkButton {
            applyAnnouncementLinkChrome(to: b)
        }
    }

    private func applyEditBarButtonTint() {
        let c = MediaLibraryHeaderBannerColor.catalogChromeAccent(for: traitCollection)
        navigationItem.rightBarButtonItem?.tintColor = c
    }

    private func applyAnnouncementLinkChrome(to btn: UIButton) {
        let c = MediaLibraryHeaderBannerColor.catalogChromeAccent(for: traitCollection)
        btn.setTitleColor(c, for: .normal)
        btn.tintColor = c
    }

    private func loadBannerImageIfNeeded() {
        guard let a = currentAnnouncement(), let url = CommunityStore.announcementImageURL(fileName: a.imageFileName) else {
            bannerView.image = nil
            bannerHeightConstraint.constant = 0
            muteOverlay.isHidden = true
            heroTitleLabel.isHidden = true
            lastLoadedAnnouncementImageFileName = nil
            return
        }

        if lastLoadedAnnouncementImageFileName == a.imageFileName, bannerView.image != nil, bannerHeightConstraint.constant > 0.5 {
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let data = try? Data(contentsOf: url)
            let image = data.flatMap { UIImage(data: $0) }
            DispatchQueue.main.async {
                guard let self, self.currentAnnouncement()?.imageFileName == a.imageFileName else { return }
                guard let image else {
                    self.bannerView.image = nil
                    self.bannerHeightConstraint.constant = 0
                    self.muteOverlay.isHidden = true
                    self.heroTitleLabel.isHidden = true
                    self.lastLoadedAnnouncementImageFileName = nil
                    self.rebuildContentStack()
                    return
                }
                self.bannerView.image = image
                self.bannerHeightConstraint.constant = Self.bannerImageHeight
                self.muteOverlay.isHidden = false
                self.heroTitleLabel.isHidden = false
                self.lastLoadedAnnouncementImageFileName = a.imageFileName
                self.view.setNeedsLayout()
                self.view.layoutIfNeeded()
                self.rebuildContentStack()
            }
        }
    }

    private func rebuildContentStack() {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        announcementLinkButton = nil
        guard let a = currentAnnouncement() else { return }

        heroTitleLabel.text = a.title

        let showHeroStrip = bannerView.image != nil && bannerHeightConstraint.constant > 0.5
        muteOverlay.isHidden = !showHeroStrip
        heroTitleLabel.isHidden = !showHeroStrip

        if !showHeroStrip {
            let title = UILabel()
            title.text = a.title
            title.font = TMETheme.Fonts.titleSemibold(22)
            title.textColor = .label
            title.numberOfLines = 0
            contentStack.addArrangedSubview(title)
        }

        addField(title: "Дата и время события", body: Self.formatDateTime(a.date))

        if let d = a.details?.trimmingCharacters(in: .whitespacesAndNewlines), !d.isEmpty {
            addField(title: "Описание", body: d)
        }

        addLinkSectionIfNeeded(raw: a.linkURL)

        if let loc = a.location {
            let locText: String
            if let t = loc.title, !t.isEmpty {
                locText = "\(t)\n\(String(format: "%.5f, %.5f", loc.latitude, loc.longitude))"
            } else {
                locText = String(format: "%.5f, %.5f", loc.latitude, loc.longitude)
            }
            addField(title: "Место", body: locText)
        }

        if let cid = a.sourceCommunityId, let name = store.communityTitle(id: cid) {
            addField(title: "Источник", body: "Сообщество: \(name)", secondary: false)
        } else {
            addField(title: "Источник", body: "Личный анонс", secondary: false)
        }
    }

    private func addField(title: String, body: String, secondary: Bool = false) {
        let box = UIStackView()
        box.axis = .vertical
        box.spacing = 6

        let t = UILabel()
        t.text = title
        t.font = TMETheme.Fonts.body(13)
        t.textColor = .secondaryLabel

        let b = UILabel()
        b.text = body
        b.font = TMETheme.Fonts.body(16)
        b.textColor = secondary ? .tertiaryLabel : .label
        b.numberOfLines = 0

        box.addArrangedSubview(t)
        box.addArrangedSubview(b)
        contentStack.addArrangedSubview(box)
    }

    private func addLinkSectionIfNeeded(raw: String?) {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return }

        /// Как в `CommunityMessageCell`: одна строка «Ссылка: …», акцент шапки медиатеки, открытие через `https://` если схемы нет.
        let btn = UIButton(type: .system)
        announcementLinkButton = btn
        btn.setTitle("Ссылка: \(trimmed)", for: .normal)
        btn.titleLabel?.font = TMETheme.Fonts.body(13)
        btn.titleLabel?.numberOfLines = 0
        btn.titleLabel?.lineBreakMode = .byWordWrapping
        btn.contentHorizontalAlignment = .leading
        btn.contentVerticalAlignment = .top
        btn.setContentHuggingPriority(.required, for: .vertical)
        btn.setContentCompressionResistancePriority(.required, for: .vertical)
        applyAnnouncementLinkChrome(to: btn)
        btn.accessibilityHint = "Открывает в браузере"
        btn.addAction(UIAction { [weak self] _ in
            self?.openAnnouncementLink(raw: trimmed)
        }, for: .touchUpInside)

        contentStack.addArrangedSubview(btn)
    }

    private func openAnnouncementLink(raw: String) {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        let urlString =
            t.lowercased().hasPrefix("http://") || t.lowercased().hasPrefix("https://")
            ? t
            : "https://\(t)"
        guard let url = URL(string: urlString) else { return }
        present(SFSafariViewController(url: url), animated: true)
    }

    @objc private func editTapped() {
        guard let a = currentAnnouncement() else { return }
        let ed = NewAnnouncementViewController(editingSavedAnnouncementId: a.id)
        navigationController?.pushViewController(ed, animated: true)
    }

    private static func formatDateTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }
}

// MARK: - Нижний градиент на баннере

private final class HeroBottomFadeView: UIView {
    private let gradient = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        gradient.colors = [
            UIColor.black.withAlphaComponent(0).cgColor,
            UIColor.black.withAlphaComponent(0.35).cgColor,
            UIColor.black.withAlphaComponent(0.75).cgColor
        ]
        gradient.locations = [0, 0.45, 1]
        gradient.startPoint = CGPoint(x: 0.5, y: 0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1)
        layer.insertSublayer(gradient, at: 0)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
    }
}
