import UIKit

/// Горизонтально прокручиваемые вкладки; при смене — краткий «glass», затем светло-серая плашка (как сегмент в основном клиенте).
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
        addSubview(scrollView)

        for (index, title) in titles.enumerated() {
            let button = UIButton(type: .custom)
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
            button.titleLabel?.numberOfLines = 1
            button.contentEdgeInsets = UIEdgeInsets(top: 5, left: 12, bottom: 5, right: 12)
            button.layer.cornerRadius = 10
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
        let spacing: CGFloat = 8
        var x = side
        let h = bounds.height
        for button in tabButtons {
            button.sizeToFit()
            let fitting = button.sizeThatFits(CGSize(width: 1200, height: h))
            let btnH = max(30, fitting.height)
            let w = max(fitting.width, 44)
            button.frame = CGRect(x: x, y: floor((h - btnH) / 2), width: w, height: btnH)
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
        for (i, button) in tabButtons.enumerated() {
            button.layer.removeAllAnimations()
            button.subviews.compactMap { $0 as? UIVisualEffectView }.forEach { $0.removeFromSuperview() }
        }

        for (i, button) in tabButtons.enumerated() {
            let selected = i == selectedIndex
            if selected {
                let gray = selectedFill(for: button)
                if animated {
                    playGlassThenSettle(button: button, finalBackground: gray)
                } else {
                    button.backgroundColor = gray
                    button.setTitleColor(.label, for: .normal)
                }
            } else {
                let apply = {
                    button.backgroundColor = .clear
                    button.setTitleColor(.secondaryLabel, for: .normal)
                }
                if animated {
                    UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseOut], animations: apply)
                } else {
                    apply()
                }
            }
        }

        guard selectedIndex < tabButtons.count else { return }
        let button = tabButtons[selectedIndex]
        let rect = button.convert(button.bounds, to: scrollView)
        scrollView.scrollRectToVisible(rect.insetBy(dx: -32, dy: 0), animated: animated)
    }

    private func selectedFill(for button: UIButton) -> UIColor {
        let light = UIColor(white: 0.88, alpha: 1)
        return UIColor { tc in
            tc.userInterfaceStyle == .dark ? UIColor.tertiarySystemFill : light
        }.resolvedColor(with: button.traitCollection)
    }

    /// Краткий эффект стекла на время анимации перехода, затем светло-серый фон.
    private func playGlassThenSettle(button: UIButton, finalBackground: UIColor) {
        let blurStyle: UIBlurEffect.Style = {
            if #available(iOS 13.0, *) {
                return .systemChromeMaterial
            }
            return .light
        }()
        let ev = UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
        ev.frame = button.bounds
        ev.layer.cornerRadius = button.layer.cornerRadius
        ev.clipsToBounds = true
        ev.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        ev.isUserInteractionEnabled = false
        ev.alpha = 1
        button.insertSubview(ev, at: 0)

        button.setTitleColor(.label, for: .normal)
        button.backgroundColor = .clear

        UIView.animate(
            withDuration: 0.4,
            delay: 0,
            usingSpringWithDamping: 0.88,
            initialSpringVelocity: 0.35,
            options: [.curveEaseOut, .allowUserInteraction]
        ) {
            ev.alpha = 0
            button.backgroundColor = finalBackground
        } completion: { _ in
            ev.removeFromSuperview()
            button.backgroundColor = finalBackground
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateSelection(animated: false)
    }

    static let preferredHeight: CGFloat = 34
}
