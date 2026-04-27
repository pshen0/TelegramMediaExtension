import UIKit

private enum TabPill {
    static let cornerRadius: CGFloat = 11
    static let pillFillTag = 9_090
}

/// Горизонтально прокручиваемые вкладки: выбранная — сплошная подложка, остальные — прозрачные подписи.
final class MediaLibraryFolderTabsView: UIView {
    var selectedIndex: Int = 0 {
        didSet { updateSelection(animated: oldValue != selectedIndex) }
    }

    var onSelectionChange: ((Int) -> Void)?

    private let scrollView = UIScrollView()
    private var tabButtons: [UIButton] = []

    private let titles: [String]

    init(titles: [String]) {
        self.titles = titles
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.delaysContentTouches = false
        scrollView.backgroundColor = .clear
        addSubview(scrollView)

        for (index, title) in titles.enumerated() {
            let button = UIButton(type: .custom)
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
            button.titleLabel?.numberOfLines = 1
            button.contentEdgeInsets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
            button.layer.cornerRadius = TabPill.cornerRadius
            button.clipsToBounds = true
            button.tag = index
            button.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)
            scrollView.addSubview(button)
            tabButtons.append(button)
        }

        updateSelection(animated: false)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        scrollView.frame = bounds

        let side: CGFloat = 10
        let spacing: CGFloat = 6
        var x = side
        let h = bounds.height
        for button in tabButtons {
            button.sizeToFit()
            let fitting = button.sizeThatFits(CGSize(width: 1200, height: h))
            let btnH = max(22, min(fitting.height, h - 2))
            let w = max(fitting.width, 44)
            button.frame = CGRect(x: x, y: floor((h - btnH) / 2), width: w, height: btnH)
            button.layer.cornerRadius = TabPill.cornerRadius
            if let pill = button.viewWithTag(TabPill.pillFillTag) {
                pill.frame = button.bounds
                pill.layer.cornerRadius = TabPill.cornerRadius
            }
            x += w + spacing
        }
        scrollView.contentSize = CGSize(width: max(x + side - spacing, bounds.width + 1), height: h)
    }

    @objc private func tabTapped(_ sender: UIButton) {
        let idx = sender.tag
        guard idx != selectedIndex else { return }
        selectedIndex = idx
        onSelectionChange?(idx)
    }

    private func updateSelection(animated: Bool) {
        for button in tabButtons {
            button.layer.removeAllAnimations()
            button.viewWithTag(TabPill.pillFillTag)?.removeFromSuperview()
        }

        for (i, button) in tabButtons.enumerated() {
            let selected = i == selectedIndex
            if selected {
                applySelectedPillFill(to: button)
                button.setTitleColor(UIColor { tc in
                    tc.userInterfaceStyle == .dark ? UIColor.white.withAlphaComponent(0.95) : UIColor(white: 0.22, alpha: 1)
                }, for: .normal)
                button.backgroundColor = .clear
            } else {
                let apply = {
                    button.backgroundColor = .clear
                    button.setTitleColor(.secondaryLabel, for: .normal)
                }
                if animated {
                    UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseOut], animations: apply)
                } else {
                    apply()
                }
            }
        }

        guard selectedIndex < tabButtons.count else { return }
        let button = tabButtons[selectedIndex]
        let rect = button.convert(button.bounds, to: scrollView)
        scrollView.scrollRectToVisible(rect.insetBy(dx: -36, dy: 0), animated: animated)
    }

    private func applySelectedPillFill(to button: UIButton) {
        let fill = UIView()
        fill.tag = TabPill.pillFillTag
        fill.backgroundColor = UIColor { tc in
            tc.userInterfaceStyle == .dark ? UIColor(white: 0.28, alpha: 1) : UIColor(white: 0.91, alpha: 1)
        }
        fill.frame = button.bounds
        fill.layer.cornerRadius = TabPill.cornerRadius
        fill.clipsToBounds = true
        fill.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        fill.isUserInteractionEnabled = false
        button.insertSubview(fill, at: 0)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateSelection(animated: false)
    }

    static let preferredHeight: CGFloat = 26
}
