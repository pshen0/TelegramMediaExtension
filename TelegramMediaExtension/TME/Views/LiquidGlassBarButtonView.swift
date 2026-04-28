import UIKit

final class LiquidGlassBarButtonView: UIView {
    private static let defaultSide: CGFloat = 34
    private let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialLight))
    private let button = UIButton(type: .system)
    private let action: () -> Void
    private let symbolPointSize: CGFloat
    private let showsBackground: Bool
    private var size: CGSize

    init(
        symbolName: String,
        accessibilityLabel: String,
        symbolPointSize: CGFloat = 13,
        showsBackground: Bool = true,
        side: CGFloat = LiquidGlassBarButtonView.defaultSide,
        action: @escaping () -> Void
    ) {
        self.action = action
        self.symbolPointSize = symbolPointSize
        self.showsBackground = showsBackground
        self.size = CGSize(width: side, height: side)
        super.init(frame: CGRect(origin: .zero, size: self.size))

        isAccessibilityElement = true
        self.accessibilityLabel = accessibilityLabel
        accessibilityTraits = [.button]

        blur.isUserInteractionEnabled = false
        blur.layer.cornerRadius = self.size.height / 2
        if #available(iOS 13.0, *) {
            blur.layer.cornerCurve = .continuous
        }
        blur.clipsToBounds = true
        blur.isHidden = !showsBackground

        let cfg = UIImage.SymbolConfiguration(pointSize: symbolPointSize, weight: .semibold)
        button.setImage(UIImage(systemName: symbolName, withConfiguration: cfg), for: .normal)
        button.tintColor = UIColor { tc in
            tc.userInterfaceStyle == .dark ? UIColor(white: 0.92, alpha: 1) : UIColor(white: 0.28, alpha: 1)
        }
        button.addTarget(self, action: #selector(tapped), for: .touchUpInside)

        addSubview(blur)
        addSubview(button)
    }

    init(
        title: String,
        accessibilityLabel: String,
        showsBackground: Bool = true,
        side: CGFloat = LiquidGlassBarButtonView.defaultSide,
        titleFont: UIFont = TMETheme.Fonts.body(15),
        action: @escaping () -> Void
    ) {
        self.action = action
        self.symbolPointSize = 0
        self.showsBackground = showsBackground
        self.size = CGSize(width: side, height: side)
        super.init(frame: CGRect(origin: .zero, size: self.size))

        isAccessibilityElement = true
        self.accessibilityLabel = accessibilityLabel
        accessibilityTraits = [.button]

        blur.isUserInteractionEnabled = false
        blur.layer.cornerRadius = self.size.height / 2
        if #available(iOS 13.0, *) {
            blur.layer.cornerCurve = .continuous
        }
        blur.clipsToBounds = true
        blur.isHidden = !showsBackground

        button.setTitle(title, for: .normal)
        button.titleLabel?.font = titleFont
        button.setTitleColor(UIColor { tc in
            tc.userInterfaceStyle == .dark ? UIColor(white: 0.92, alpha: 1) : UIColor(white: 0.28, alpha: 1)
        }, for: .normal)
        button.addTarget(self, action: #selector(tapped), for: .touchUpInside)

        addSubview(blur)
        addSubview(button)
    }

    convenience init(
        title: String,
        accessibilityLabel: String,
        showsBackground: Bool = true,
        size: CGSize,
        titleFont: UIFont = TMETheme.Fonts.body(15),
        action: @escaping () -> Void
    ) {
        self.init(
            title: title,
            accessibilityLabel: accessibilityLabel,
            showsBackground: showsBackground,
            side: max(size.width, size.height),
            titleFont: titleFont,
            action: action
        )
        setSize(size)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var intrinsicContentSize: CGSize { size }

    func setSize(_ size: CGSize) {
        self.size = size
        frame = CGRect(origin: .zero, size: size)
        blur.layer.cornerRadius = size.height / 2
        setNeedsLayout()
        invalidateIntrinsicContentSize()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        blur.frame = bounds
        button.frame = bounds
    }

    func setSymbolName(_ symbolName: String) {
        let cfg = UIImage.SymbolConfiguration(pointSize: symbolPointSize, weight: .semibold)
        button.setImage(UIImage(systemName: symbolName, withConfiguration: cfg), for: .normal)
    }

    func updateBlurStyle(for trait: UITraitCollection) {
        guard showsBackground else { return }
        let style: UIBlurEffect.Style = trait.userInterfaceStyle == .dark ? .systemThinMaterialDark : .systemThinMaterialLight
        blur.effect = UIBlurEffect(style: style)
    }

    @objc private func tapped() {
        action()
    }
}
