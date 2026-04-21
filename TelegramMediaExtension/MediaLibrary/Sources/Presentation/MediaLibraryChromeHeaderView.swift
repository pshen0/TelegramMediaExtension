import UIKit

/// Шапка: компактный градиент (~12.5% высоты экрана) → UISearchBar → вкладки в скруглённой карточке с тенью.
final class MediaLibraryChromeHeaderView: UIView {
    private let bannerGradientView = MediaLibraryBannerGradientView()

    let searchBar = UISearchBar()
    /// Внешний контейнер только для тени (без `masksToBounds`).
    private let tabsCardShadowContainer = UIView()
    /// Внутри — скругление и обрезка контента.
    private let tabsCardClipView = UIView()
    let folderTabs: MediaLibraryFolderTabsView

    /// Точная высота шапки (должна совпадать с `layoutSubviews`). Раньше статическая оценка занижала высоту `UISearchBar` (~56 vs 40) — список наезжал на сегмент.
    func preferredHeight(forWidth width: CGFloat) -> CGFloat {
        let screenH = window?.windowScene?.screen.bounds.height ?? UIScreen.main.bounds.height
        let bannerH = screenH * Self.bannerHeightFraction
        let gradientH = bannerH + topSafeInset
        let searchSize = searchBar.sizeThatFits(CGSize(width: width, height: 120))
        let searchH = max(Self.searchMinHeight, searchSize.height)
        let tabsCardH = MediaLibraryFolderTabsView.preferredHeight + Self.tabsCardVerticalPadding * 2
        let raw = gradientH + Self.searchTopSpacing + searchH + Self.searchToTabsSpacing + tabsCardH
        // Округление до пикселя: иначе `sizeThatFits` у поиска может «плавать» между проходами layout и зациклить `viewDidLayoutSubviews`.
        return ceil(raw * UIScreen.main.scale) / UIScreen.main.scale
    }

    /// Раньше было 25%; шапка ~вдвое ниже по вертикали.
    private static let bannerHeightFraction: CGFloat = 0.125
    private static let searchMinHeight: CGFloat = 40

    private static let searchTopSpacing: CGFloat = 2
    private static let searchToTabsSpacing: CGFloat = 3
    private static let tabsCardVerticalPadding: CGFloat = 2

    /// Обновляется из VC (`view.safeAreaInsets.top`), чтобы градиент был виден под прозрачным navigation bar.
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

        backgroundColor = .clear

        bannerGradientView.isUserInteractionEnabled = false
        addSubview(bannerGradientView)

        searchBar.placeholder = "Поиск"
        searchBar.searchBarStyle = .minimal
        searchBar.backgroundColor = .clear
        searchBar.barTintColor = .clear
        searchBar.isTranslucent = true
        searchBar.setShowsCancelButton(false, animated: false)
        if #available(iOS 13.0, *) {
            let tf = searchBar.searchTextField
            tf.autocapitalizationType = .none
            tf.returnKeyType = .search
        }
        addSubview(searchBar)

        tabsCardShadowContainer.layer.masksToBounds = false
        tabsCardShadowContainer.layer.shadowColor = UIColor.black.cgColor
        tabsCardShadowContainer.layer.shadowOpacity = 0.08
        tabsCardShadowContainer.layer.shadowOffset = CGSize(width: 0, height: 2)
        tabsCardShadowContainer.layer.shadowRadius = 10
        addSubview(tabsCardShadowContainer)

        tabsCardClipView.backgroundColor = UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(white: 0.22, alpha: 1)
                : UIColor(white: 0.96, alpha: 1)
        }
        tabsCardClipView.layer.cornerRadius = 14
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

    override func layoutSubviews() {
        super.layoutSubviews()
        let w = bounds.width
        let screenH = window?.windowScene?.screen.bounds.height ?? UIScreen.main.bounds.height
        let bannerH = screenH * Self.bannerHeightFraction
        let top = topSafeInset
        let gradientH = bannerH + top

        bannerGradientView.frame = CGRect(x: 0, y: 0, width: w, height: gradientH)

        let searchSize = searchBar.sizeThatFits(CGSize(width: w, height: 120))
        let searchH = max(Self.searchMinHeight, searchSize.height)
        searchBar.frame = CGRect(x: 0, y: gradientH + Self.searchTopSpacing, width: w, height: searchH)

        let sideInset: CGFloat = 16
        let cardW = w - sideInset * 2
        let tabsCardH = MediaLibraryFolderTabsView.preferredHeight + Self.tabsCardVerticalPadding * 2
        let cardY = searchBar.frame.maxY + Self.searchToTabsSpacing
        tabsCardShadowContainer.frame = CGRect(x: sideInset, y: cardY, width: cardW, height: tabsCardH)
        tabsCardClipView.frame = tabsCardShadowContainer.bounds
        folderTabs.frame = CGRect(
            x: 0,
            y: Self.tabsCardVerticalPadding,
            width: cardW,
            height: MediaLibraryFolderTabsView.preferredHeight
        )

        updateTabsCardShadowPath()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        tabsCardClipView.backgroundColor = UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(white: 0.22, alpha: 1)
                : UIColor(white: 0.96, alpha: 1)
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

// MARK: - Градиент в шапке (скроллится с таблицей)

private final class MediaLibraryBannerGradientView: UIView {
    private let gradientLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        layer.addSublayer(gradientLayer)
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        gradientLayer.locations = [0, 0.55, 1]
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
        updateColors()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateColors()
    }

    private func updateColors() {
        let paper = UIColor.systemBackground.resolvedColor(with: traitCollection)
        let accent = UIColor.systemBlue.resolvedColor(with: traitCollection)
        let isDark = traitCollection.userInterfaceStyle == .dark
        let top = accent.withAlphaComponent(isDark ? 0.45 : 0.34)
        let mid = accent.withAlphaComponent(isDark ? 0.22 : 0.16)
        gradientLayer.colors = [top.cgColor, mid.cgColor, paper.cgColor]
    }
}
