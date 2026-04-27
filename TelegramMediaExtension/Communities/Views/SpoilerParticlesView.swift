import UIKit

final class SpoilerParticlesView: UIView {
    private let emitter = CAEmitterLayer()
    private var running = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        clipsToBounds = true
        layer.addSublayer(emitter)

        emitter.emitterShape = .rectangle
        emitter.renderMode = .additive
        emitter.seed = arc4random()
        emitter.opacity = 0.85
        emitter.birthRate = 0

        let cell = CAEmitterCell()
        cell.contents = Self.dotImage()?.cgImage
        cell.birthRate = 130
        cell.lifetime = 6.2
        cell.lifetimeRange = 1.2
        cell.velocity = 16
        cell.velocityRange = 12
        cell.emissionRange = .pi * 2
        cell.scale = 0.045
        cell.scaleRange = 0.025
        cell.alphaSpeed = -0.06
        cell.spin = 0.6
        cell.spinRange = 1.2
        cell.color = UIColor(white: 1, alpha: 0.9).cgColor

        emitter.emitterCells = [cell]
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        emitter.frame = bounds
        emitter.emitterPosition = CGPoint(x: bounds.midX, y: bounds.midY)
        emitter.emitterSize = CGSize(width: bounds.width, height: bounds.height)
    }

    func start() {
        guard !running else { return }
        running = true
        emitter.birthRate = 1
    }

    func stop() {
        guard running else { return }
        running = false
        emitter.birthRate = 0
    }

    private static func dotImage() -> UIImage? {
        let side: CGFloat = 10
        let r = side / 2
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        return renderer.image { ctx in
            ctx.cgContext.setFillColor(UIColor.white.cgColor)
            ctx.cgContext.addEllipse(in: CGRect(x: 0, y: 0, width: side, height: side))
            ctx.cgContext.fillPath()
            // мягкое свечение
            ctx.cgContext.setShadow(offset: .zero, blur: 3, color: UIColor.white.withAlphaComponent(0.6).cgColor)
            ctx.cgContext.addEllipse(in: CGRect(x: r - 1, y: r - 1, width: 2, height: 2))
            ctx.cgContext.fillPath()
        }
    }
}
