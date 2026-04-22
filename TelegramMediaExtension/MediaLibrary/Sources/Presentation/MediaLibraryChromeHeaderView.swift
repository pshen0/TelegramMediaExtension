import UIKit

/// Шапка: компактная цветная полоса + продолжение цвета вверх при bounce, поиск с узкой строкой и круглой кнопкой закрытия справа (как система).
final class MediaLibraryChromeHeaderView: UIView {
    /// Тап по цветной полосе над поиском — выбор цвета шапки.
    var onBannerTap: (() -> Void)?

    var onSearchDismiss: (() -> Void)?

    private let headerBaseFill = UIView()
    private let bannerSolidView = UIView()
    private let duckImageView = UIImageView()

    let searchBar = UISearchBar()

    private let searchDismissContainer = UIView()
    private let searchDismissGlass = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialLight))
    private let searchDismissButton = UIButton(type: .system)

    private let tabsCardShadowContainer = UIView()
    private let tabsCardClipView = UIView()
    let folderTabs: MediaLibraryFolderTabsView

    private var scrollFadeProgress: CGFloat = -1

    private(set) var showsSearchDismissButton = false

    func setShowsSearchDismiss(_ visible: Bool, animated: Bool) {
        guard visible != showsSearchDismissButton else { return }

        if visible {
            searchDismissContainer.isHidden = false
            searchDismissContainer.alpha = 0
            if animated {
                showsSearchDismissButton = false
                layoutSearchRowAndTabs()
                showsSearchDismissButton = true
                UIView.animate(withDuration: 0.28, delay: 0, options: [.curveEaseInOut]) {
                    self.layoutSearchRowAndTabs()
                    self.searchDismissContainer.alpha = 1
                }
            } else {
                showsSearchDismissButton = true
                layoutSearchRowAndTabs()
                searchDismissContainer.alpha = 1
            }
        } else {
            if animated {
                UIView.animate(withDuration: 0.28, delay: 0, options: [.curveEaseInOut]) {
                    self.showsSearchDismissButton = false
                    self.layoutSearchRowAndTabs()
                    self.searchDismissContainer.alpha = 0
                } completion: { _ in
                    self.searchDismissContainer.isHidden = true
                }
            } else {
                showsSearchDismissButton = false
                searchDismissContainer.alpha = 0
                searchDismissContainer.isHidden = true
                layoutSearchRowAndTabs()
            }
        }
    }

    func setScrollFadeProgress(_ progress: CGFloat) {
        let p = min(1, max(0, progress))
        guard abs(p - scrollFadeProgress) > 0.001 else { return }
        scrollFadeProgress = p
        bannerSolidView.alpha = 1 - p
    }

    func coloredBannerHeight(forWidth width: CGFloat) -> CGFloat {
        let screenH = window?.windowScene?.screen.bounds.height ?? UIScreen.main.bounds.height
        let bannerH = screenH * Self.bannerHeightFraction
        return bannerH + topSafeInset
    }

    func preferredHeight(forWidth width: CGFloat) -> CGFloat {
        let gradientH = coloredBannerHeight(forWidth: width)
        let dismissReserve: CGFloat = Self.searchDismissSize + Self.searchDismissSpacing
        let searchAvailW = width - Self.searchHorizontalInset * 2 - dismissReserve
        let searchSize = searchBar.sizeThatFits(CGSize(width: max(120, searchAvailW), height: 120))
        let searchH = max(Self.searchMinHeight, searchSize.height)
        let tabsCardH = MediaLibraryFolderTabsView.preferredHeight + Self.tabsCardVerticalPadding * 2
        let raw = gradientH + Self.searchTopSpacing + searchH + Self.searchToTabsSpacing + tabsCardH
        return ceil(raw * UIScreen.main.scale) / UIScreen.main.scale
    }

    private static let bannerHeightFraction: CGFloat = (1.0 / 8.0) * (6.0 / 5.0)

    private static var bannerUpwardPaint: CGFloat {
        max(640, UIScreen.main.bounds.height * 0.9)
    }

    private static let searchMinHeight: CGFloat = 36
    private static let searchTopSpacing: CGFloat = 2
    private static let searchToTabsSpacing: CGFloat = 4
    private static let tabsCardVerticalPadding: CGFloat = 6

    private static let searchHorizontalInset: CGFloat = 12
    private static let searchDismissSpacing: CGFloat = 8
    private static let searchDismissSize: CGFloat = 34

    private(set) var topSafeInset: CGFloat = 0 {
        didSet {
            if oldValue != topSafeInset {
                setNeedsLayout()
            }
        }
    }

    func setTopSafeInset(_ inset: CGFloat) {
        topSafeInset = inset
    }

    init() {
        let tabTitles = ["Все"] + MediaWatchStatus.allCases.map(\.title)
        folderTabs = MediaLibraryFolderTabsView(titles: tabTitles)
        super.init(frame: .zero)

        clipsToBounds = false
        backgroundColor = .clear

        headerBaseFill.backgroundColor = .systemBackground
        headerBaseFill.isUserInteractionEnabled = false
        addSubview(headerBaseFill)

        bannerSolidView.isUserInteractionEnabled = true
        bannerSolidView.isAccessibilityElement = true
        bannerSolidView.accessibilityLabel = "Цвет шапки"
        bannerSolidView.accessibilityHint = "Открывает выбор цвета верхней полосы."
        applyBannerBackgroundColor()
        let tap = UITapGestureRecognizer(target: self, action: #selector(bannerTapped))
        bannerSolidView.addGestureRecognizer(tap)
        addSubview(bannerSolidView)

        if let duck = UIImage(named: "duck") {
            duckImageView.image = duck
            duckImageView.contentMode = .scaleAspectFit
            duckImageView.isUserInteractionEnabled = false
            duckImageView.accessibilityIgnoresInvertColors = true
            addSubview(duckImageView)
        }

        searchBar.placeholder = "Поиск"
        searchBar.searchBarStyle = .minimal
        searchBar.backgroundColor = .clear
        searchBar.barTintColor = .clear
        searchBar.isTranslucent = false
        searchBar.setShowsCancelButton(false, animated: false)
        configureSearchBarChrome()
        addSubview(searchBar)

        searchDismissGlass.isUserInteractionEnabled = false
        searchDismissGlass.layer.cornerRadius = Self.searchDismissSize / 2
        if #available(iOS 13.0, *) {
            searchDismissGlass.layer.cornerCurve = .continuous
        }
        searchDismissGlass.clipsToBounds = true
        updateSearchDismissGlassEffect()
        searchDismissContainer.addSubview(searchDismissGlass)

        let cfg = UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)
        searchDismissButton.setImage(UIImage(systemName: "xmark", withConfiguration: cfg), for: .normal)
        searchDismissButton.tintColor = UIColor { tc in
            tc.userInterfaceStyle == .dark ? UIColor(white: 0.88, alpha: 1) : UIColor(white: 0.38, alpha: 1)
        }
        searchDismissButton.addTarget(self, action: #selector(searchDismissTapped), for: .touchUpInside)
        searchDismissButton.accessibilityLabel = "Закрыть клавиатуру"
        searchDismissContainer.addSubview(searchDismissButton)

        searchDismissContainer.alpha = 0
        searchDismissContainer.isHidden = true
        addSubview(searchDismissContainer)

        tabsCardShadowContainer.layer.masksToBounds = false
        tabsCardShadowContainer.layer.shadowColor = UIColor.black.cgColor
        tabsCardShadowContainer.layer.shadowOpacity = 0.14
        tabsCardShadowContainer.layer.shadowOffset = CGSize(width: 0, height: 3)
        tabsCardShadowContainer.layer.shadowRadius = 12
        addSubview(tabsCardShadowContainer)

        tabsCardClipView.backgroundColor = cardBackgroundColor()
        tabsCardClipView.layer.cornerRadius = 18
        if #available(iOS 13.0, *) {
            tabsCardClipView.layer.cornerCurve = .continuous
        }
        tabsCardClipView.layer.masksToBounds = true
        tabsCardShadowContainer.addSubview(tabsCardClipView)
        tabsCardClipView.addSubview(folderTabs)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func cardBackgroundColor() -> UIColor {
        UIColor { tc in
            tc.userInterfaceStyle == .dark ? UIColor(white: 0.14, alpha: 1) : .white
        }
    }

    @objc private func bannerTapped() {
        onBannerTap?()
    }

    func refreshBannerBackgroundColor() {
        applyBannerBackgroundColor()
    }

    private func applyBannerBackgroundColor() {
        bannerSolidView.backgroundColor = MediaLibraryHeaderBannerColor.resolved(for: traitCollection)
    }

    @objc private func searchDismissTapped() {
        onSearchDismiss?()
    }

    private func configureSearchBarChrome() {
        guard #available(iOS 13.0, *) else { return }
        let tf = searchBar.searchTextField
        let fieldBg = UIColor { tc in
            tc.userInterfaceStyle == .dark ? UIColor(white: 0.28, alpha: 1) : UIColor(white: 0.91, alpha: 1)
        }
        let textCol = UIColor { tc in
            tc.userInterfaceStyle == .dark ? UIColor(white: 0.82, alpha: 1) : UIColor(white: 0.35, alpha: 1)
        }
        let hintCol = UIColor { tc in
            tc.userInterfaceStyle == .dark ? UIColor(white: 0.55, alpha: 1) : UIColor(white: 0.48, alpha: 1)
        }
        tf.backgroundColor = fieldBg.resolvedColor(with: traitCollection)
        tf.textColor = textCol.resolvedColor(with: tf.traitCollection)
        tf.attributedPlaceholder = NSAttributedString(
            string: searchBar.placeholder ?? "Поиск",
            attributes: [.foregroundColor: hintCol.resolvedColor(with: tf.traitCollection)]
        )
        tf.layer.cornerRadius = Self.searchFieldCornerRadius
        tf.clipsToBounds = true
        tf.borderStyle = .none
        tf.leftView?.tintColor = textCol.resolvedColor(with: tf.traitCollection)
        if let lv = tf.leftView as? UIImageView {
            lv.tintColor = textCol.resolvedColor(with: tf.traitCollection)
        }
        searchBar.searchTextField.backgroundColor = fieldBg.resolvedColor(with: traitCollection)
    }

    private static let searchFieldCornerRadius: CGFloat = 20

    override func layoutSubviews() {
        super.layoutSubviews()
        let w = bounds.width
        let gradientH = coloredBannerHeight(forWidth: w)
        let up = Self.bannerUpwardPaint

        headerBaseFill.frame = bounds
        bannerSolidView.frame = CGRect(x: 0, y: -up, width: w, height: up + gradientH)

        layoutDuckInBanner(width: w, bannerHeight: gradientH)

        layoutSearchRowAndTabs()

        updateTabsCardShadowPath()
        tintSearchBarAccessoryViews()
    }

    private func layoutDuckInBanner(width w: CGFloat, bannerHeight gradientH: CGFloat) {
        guard duckImageView.superview != nil, duckImageView.image != nil else { return }

        let insetTop = topSafeInset
        let contentH = max(0, gradientH - insetTop)
        let horizontalPadding: CGFloat = 24
        let verticalPadding: CGFloat = 8
        let maxW = max(1, w - horizontalPadding * 2)
        let maxH = max(1, contentH - verticalPadding * 2)

        let src = duckImageView.image!.size
        guard src.width > 0, src.height > 0 else {
            duckImageView.frame = .zero
            return
        }
        let scale = min(maxW / src.width, maxH / src.height)
        let duckW = src.width * scale
        let duckH = src.height * scale
        duckImageView.frame = CGRect(
            x: (w - duckW) / 2,
            y: insetTop + (contentH - duckH) / 2,
            width: duckW,
            height: duckH
        )
    }

    private func layoutSearchRowAndTabs() {
        let w = bounds.width
        let gradientH = coloredBannerHeight(forWidth: w)

        let searchSize = searchBar.sizeThatFits(CGSize(width: w, height: 120))
        let searchH = max(Self.searchMinHeight, searchSize.height)
        let y = gradientH + Self.searchTopSpacing

        let side = Self.searchHorizontalInset
        let dismissW = Self.searchDismissSize
        let gap = Self.searchDismissSpacing

        let searchW: CGFloat
        if showsSearchDismissButton {
            searchW = w - side * 2 - gap - dismissW
        } else {
            searchW = w - side * 2
        }

        searchBar.frame = CGRect(x: side, y: y, width: max(60, searchW), height: searchH)

        searchDismissGlass.frame = CGRect(origin: .zero, size: CGSize(width: dismissW, height: dismissW))
        searchDismissButton.frame = searchDismissGlass.frame
        searchDismissContainer.bounds = CGRect(x: 0, y: 0, width: dismissW, height: dismissW)
        searchDismissContainer.center = CGPoint(x: w - side - dismissW / 2, y: y + searchH / 2)

        let tabsCardH = MediaLibraryFolderTabsView.preferredHeight + Self.tabsCardVerticalPadding * 2
        let cardInset: CGFloat = 16
        let cardW = w - cardInset * 2
        let cardY = searchBar.frame.maxY + Self.searchToTabsSpacing
        tabsCardShadowContainer.frame = CGRect(x: cardInset, y: cardY, width: cardW, height: tabsCardH)
        tabsCardClipView.frame = tabsCardShadowContainer.bounds
        folderTabs.frame = CGRect(
            x: 0,
            y: Self.tabsCardVerticalPadding,
            width: cardW,
            height: MediaLibraryFolderTabsView.preferredHeight
        )
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyBannerBackgroundColor()
        tabsCardClipView.backgroundColor = cardBackgroundColor()
        configureSearchBarChrome()
        tintSearchBarAccessoryViews()
        updateSearchDismissGlassEffect()
    }

    private func updateSearchDismissGlassEffect() {
        let style: UIBlurEffect.Style = traitCollection.userInterfaceStyle == .dark ? .systemThinMaterialDark : .systemThinMaterialLight
        searchDismissGlass.effect = UIBlurEffect(style: style)
    }

    private func tintSearchBarAccessoryViews() {
        guard #available(iOS 13.0, *) else { return }
        let tf = searchBar.searchTextField
        let textCol = UIColor { tc in
            tc.userInterfaceStyle == .dark ? UIColor(white: 0.82, alpha: 1) : UIColor(white: 0.35, alpha: 1)
        }.resolvedColor(with: tf.traitCollection)
        tf.leftView?.tintColor = textCol
        tf.leftViewMode = .always
        if let stack = tf.leftView as? UIStackView {
            for v in stack.arrangedSubviews {
                v.tintColor = textCol
            }
        }
    }

    private func updateTabsCardShadowPath() {
        let r = tabsCardClipView.layer.cornerRadius
        tabsCardShadowContainer.layer.shadowPath = UIBezierPath(
            roundedRect: tabsCardShadowContainer.bounds,
            cornerRadius: r
        ).cgPath
    }
}
