import UIKit

/// Круглая кнопка с тонким материалом для `navigationItem` (как на карточке медиатеки).
final class LiquidGlassBarButtonView: UIView {
    private static let side: CGFloat = 34
    private let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialLight))
    private let button = UIButton(type: .system)
    private let action: () -> Void

    init(symbolName: String, accessibilityLabel: String, action: @escaping () -> Void) {
        self.action = action
        super.init(frame: CGRect(origin: .zero, size: CGSize(width: Self.side, height: Self.side)))

        isAccessibilityElement = true
        self.accessibilityLabel = accessibilityLabel
        accessibilityTraits = [.button]

        blur.isUserInteractionEnabled = false
        blur.layer.cornerRadius = Self.side / 2
        if #available(iOS 13.0, *) {
            blur.layer.cornerCurve = .continuous
        }
        blur.clipsToBounds = true

        let cfg = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        button.setImage(UIImage(systemName: symbolName, withConfiguration: cfg), for: .normal)
        button.tintColor = UIColor { tc in
            tc.userInterfaceStyle == .dark ? UIColor(white: 0.92, alpha: 1) : UIColor(white: 0.28, alpha: 1)
        }
        button.addTarget(self, action: #selector(tapped), for: .touchUpInside)

        addSubview(blur)
        addSubview(button)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var intrinsicContentSize: CGSize { CGSize(width: Self.side, height: Self.side) }

    override func layoutSubviews() {
        super.layoutSubviews()
        blur.frame = bounds
        button.frame = bounds
    }

    func setSymbolName(_ symbolName: String) {
        let cfg = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        button.setImage(UIImage(systemName: symbolName, withConfiguration: cfg), for: .normal)
    }

    func updateBlurStyle(for trait: UITraitCollection) {
        let style: UIBlurEffect.Style = trait.userInterfaceStyle == .dark ? .systemThinMaterialDark : .systemThinMaterialLight
        blur.effect = UIBlurEffect(style: style)
    }

    @objc private func tapped() {
        action()
    }
}
