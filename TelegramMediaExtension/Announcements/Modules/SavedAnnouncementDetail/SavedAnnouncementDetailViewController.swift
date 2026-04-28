import SafariServices
import UIKit

final class SavedAnnouncementDetailViewController: UIViewController {

    private let interactor: SavedAnnouncementDetailInteractor

    private let bannerView = UIImageView()
    private var bannerHeightConstraint: NSLayoutConstraint!
    private static let bannerImageBaseHeight: CGFloat = 260
    private static var bannerImageHeight: CGFloat { (bannerImageBaseHeight * 4.0 / 3.0).rounded() }

    private let muteOverlay = HeroBottomFadeView()
    private let heroTitleLabel = UILabel()
    private let detailsPanel = UIView()
    private let contentStack = UIStackView()
    private var lastLoadedAnnouncementImageFileName: String?
    private weak var announcementLinkButton: UIButton?

    private static let fieldSpacing: CGFloat = 16

    init(interactor: SavedAnnouncementDetailInteractor) {
        self.interactor = interactor
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private var bannerShowsHeroStrip: Bool {
        bannerView.image != nil && bannerHeightConstraint.constant > 0.5
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.title = ""

        bannerView.contentMode = .scaleAspectFill
        bannerView.clipsToBounds = true
        bannerView.backgroundColor = .black

        muteOverlay.isUserInteractionEnabled = false

        heroTitleLabel.font = TMETheme.Fonts.titleSemibold(22)
        heroTitleLabel.textColor = .white
        heroTitleLabel.numberOfLines = 3
        heroTitleLabel.lineBreakMode = .byTruncatingTail
        heroTitleLabel.layer.shadowColor = UIColor.black.cgColor
        heroTitleLabel.layer.shadowOpacity = 0.55
        heroTitleLabel.layer.shadowRadius = 5
        heroTitleLabel.layer.shadowOffset = CGSize(width: 0, height: 1)

        contentStack.axis = .vertical
        contentStack.spacing = Self.fieldSpacing
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.layoutMargins = UIEdgeInsets(top: Self.fieldSpacing, left: 16, bottom: 20, right: 16)

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
        contentStack.pinBottom(to: detailsPanel.bottomAnchor, 20, .lsOE)

        let edit = UIBarButtonItem(
            image: UIImage(systemName: "pencil"),
            style: .plain,
            target: self,
            action: #selector(editTapped)
        )
        edit.accessibilityLabel = "Изменить"
        navigationItem.rightBarButtonItem = edit

        interactor.viewDidLoad(SavedAnnouncementDetailModel.ViewDidLoad.Request())
        loadBannerImageIfNeeded()
        interactor.refreshDisplay(SavedAnnouncementDetailModel.RefreshDisplay.Request(heroStripVisible: bannerShowsHeroStrip))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        interactor.viewWillAppear(SavedAnnouncementDetailModel.ViewWillAppear.Request())
        loadBannerImageIfNeeded()
        interactor.refreshDisplay(SavedAnnouncementDetailModel.RefreshDisplay.Request(heroStripVisible: bannerShowsHeroStrip))
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if let b = announcementLinkButton {
            applyAnnouncementLinkChrome(to: b)
        }
    }

    private func applyAnnouncementLinkChrome(to btn: UIButton) {
        let c = MediaLibraryHeaderBannerColor.catalogChromeAccent(for: traitCollection)
        btn.setTitleColor(c, for: .normal)
        btn.tintColor = c
    }

    private func loadBannerImageIfNeeded() {
        guard let a = storeAnnouncementSnapshot(), let url = CommunityStore.announcementImageURL(fileName: a.imageFileName) else {
            bannerView.image = nil
            bannerHeightConstraint.constant = 0
            muteOverlay.isHidden = true
            heroTitleLabel.isHidden = true
            lastLoadedAnnouncementImageFileName = nil
            interactor.refreshDisplay(SavedAnnouncementDetailModel.RefreshDisplay.Request(heroStripVisible: false))
            return
        }

        if lastLoadedAnnouncementImageFileName == a.imageFileName, bannerView.image != nil, bannerHeightConstraint.constant > 0.5 {
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let data = try? Data(contentsOf: url)
            let image = data.flatMap { UIImage(data: $0) }
            DispatchQueue.main.async {
                guard let self, self.storeAnnouncementSnapshot()?.imageFileName == a.imageFileName else { return }
                guard let image else {
                    self.bannerView.image = nil
                    self.bannerHeightConstraint.constant = 0
                    self.muteOverlay.isHidden = true
                    self.heroTitleLabel.isHidden = true
                    self.lastLoadedAnnouncementImageFileName = nil
                    self.interactor.refreshDisplay(SavedAnnouncementDetailModel.RefreshDisplay.Request(heroStripVisible: false))
                    return
                }
                self.bannerView.image = image
                self.bannerHeightConstraint.constant = Self.bannerImageHeight
                self.muteOverlay.isHidden = false
                self.heroTitleLabel.isHidden = false
                self.lastLoadedAnnouncementImageFileName = a.imageFileName
                self.view.setNeedsLayout()
                self.view.layoutIfNeeded()
                self.interactor.refreshDisplay(SavedAnnouncementDetailModel.RefreshDisplay.Request(heroStripVisible: self.bannerShowsHeroStrip))
            }
        }
    }

    private func storeAnnouncementSnapshot() -> SavedAnnouncement? {
        CommunityStore.shared.savedAnnouncements.first { $0.id == interactor.announcementId }
    }

    @objc private func editTapped() {
        interactor.editTap(SavedAnnouncementDetailModel.EditTap.Request())
    }
}

// MARK: - SavedAnnouncementDetailDisplayLogic

extension SavedAnnouncementDetailViewController: SavedAnnouncementDetailDisplayLogic {

    func displayDetail(_ viewModel: SavedAnnouncementDetailModel.LoadAnnouncement.ViewModel) {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        announcementLinkButton = nil

        heroTitleLabel.text = viewModel.heroTitle

        let showHeroStrip = viewModel.showHeroChrome
        muteOverlay.isHidden = !showHeroStrip
        heroTitleLabel.isHidden = !showHeroStrip

        for row in viewModel.rows {
            switch row {
            case .inlineTitle(let text):
                let title = UILabel()
                title.text = text
                title.font = TMETheme.Fonts.titleSemibold(22)
                title.textColor = .label
                title.numberOfLines = 0
                contentStack.addArrangedSubview(title)

            case .field(let title, let body, let secondary):
                addField(title: title, body: body, secondary: secondary)

            case .linkButton(let trimmed):
                addLinkSection(trimmed: trimmed)
            }
        }
    }
}

// MARK: - SavedAnnouncementDetailRoutingLogic

extension SavedAnnouncementDetailViewController: SavedAnnouncementDetailRoutingLogic {

    func popBecauseAnnouncementRemoved() {
        navigationController?.popViewController(animated: true)
    }

    func showEditSavedAnnouncement(id: UUID) {
        let ed = NewAnnouncementBuilder.buildEditingSavedAnnouncement(id: id)
        navigationController?.pushViewController(ed, animated: true)
    }

    func presentSafari(url: URL) {
        present(SFSafariViewController(url: url), animated: true)
    }
}

// MARK: - Content

private extension SavedAnnouncementDetailViewController {

    func addField(title: String, body: String, secondary: Bool = false) {
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

    func addLinkSection(trimmed: String) {
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
            self?.interactor.openLink(SavedAnnouncementDetailModel.OpenLink.Request(trimmed: trimmed))
        }, for: .touchUpInside)

        contentStack.addArrangedSubview(btn)
    }
}
