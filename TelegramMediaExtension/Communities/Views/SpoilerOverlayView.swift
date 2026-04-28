import UIKit

// MARK: - Spoiler overlay

final class SpoilerOverlayView: UIControl {
    var onTap: (() -> Void)?

    var title: String = "" { didSet { titleLabel.text = title; updateAccessibility() } }
    var subtitle: String = "" { didSet { subtitleLabel.text = subtitle; updateAccessibility() } }

    private let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    private let dim = UIView()
    private let particles = SpoilerParticlesView()

    private let pill = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = true
        accessibilityTraits = [.button]
        clipsToBounds = true
        layer.cornerRadius = 16
        if #available(iOS 13.0, *) { layer.cornerCurve = .continuous }

        addTarget(self, action: #selector(tapped), for: .touchUpInside)

        blur.isUserInteractionEnabled = false
        dim.isUserInteractionEnabled = false
        particles.isUserInteractionEnabled = false
        dim.backgroundColor = UIColor.black.withAlphaComponent(0.20)

        pill.isUserInteractionEnabled = false
        pill.clipsToBounds = true
        pill.layer.cornerRadius = 12
        if #available(iOS 13.0, *) { pill.layer.cornerCurve = .continuous }

        titleLabel.font = TMETheme.Fonts.body(13)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 2
        titleLabel.textAlignment = .center

        subtitleLabel.font = TMETheme.Fonts.body(13)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 2
        subtitleLabel.textAlignment = .center

        addSubview(blur)
        addSubview(dim)
        addSubview(particles)
        addSubview(pill)

        pill.contentView.addSubview(titleLabel)
        pill.contentView.addSubview(subtitleLabel)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func tapped() {
        onTap?()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            particles.stop()
        } else if !isHidden {
            particles.start()
        }
    }

    override var isHidden: Bool {
        didSet {
            if isHidden {
                particles.stop()
            } else if window != nil {
                particles.start()
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        blur.frame = bounds
        dim.frame = bounds
        particles.frame = bounds

        let maxW = min(bounds.width - 16, 220)

        let pad: CGFloat = 6
        let interLine: CGFloat = 3
        let maxInnerW = max(60, maxW - pad * 2)

        let titleSize = titleLabel.sizeThatFits(CGSize(width: maxInnerW, height: 200))
        let subSize = subtitleLabel.sizeThatFits(CGSize(width: maxInnerW, height: 200))
        let usedInnerW = min(maxInnerW, max(ceil(titleSize.width), ceil(subSize.width)))
        let contentW = max(120, min(maxW, usedInnerW + pad * 2))
        let innerW = contentW - pad * 2

        let titleH = ceil(titleLabel.sizeThatFits(CGSize(width: innerW, height: 200)).height)
        let subH = ceil(subtitleLabel.sizeThatFits(CGSize(width: innerW, height: 200)).height)
        let totalH = pad + titleH + interLine + subH + pad

        pill.bounds = CGRect(x: 0, y: 0, width: contentW, height: totalH)
        pill.center = CGPoint(x: bounds.midX, y: bounds.midY)

        var y: CGFloat = pad
        titleLabel.frame = CGRect(x: pad, y: y, width: innerW, height: titleH)
        y = titleLabel.frame.maxY + interLine
        subtitleLabel.frame = CGRect(x: pad, y: y, width: innerW, height: subH)
    }

    private func updateAccessibility() {
        let t = title.isEmpty ? "Спойлер" : title
        let s = subtitle.isEmpty ? "" : ", \(subtitle)"
        accessibilityLabel = "Спойлер: \(t)\(s)"
        accessibilityHint = "Нажмите, чтобы показать"
    }
}

