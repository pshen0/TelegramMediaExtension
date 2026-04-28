import UIKit

final class ThreadContextHeaderView: UIView {
    private let badge = UILabel()
    private let bubble = UIView()
    private let textLabel = UILabel()
    private let bottomDivider = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        badge.font = TMETheme.Fonts.body(12)
        badge.textColor = .secondaryLabel

        bubble.backgroundColor = .secondarySystemGroupedBackground
        bubble.layer.cornerRadius = 16
        if #available(iOS 13.0, *) { bubble.layer.cornerCurve = .continuous }

        textLabel.font = TMETheme.Fonts.body(15)
        textLabel.textColor = .label
        textLabel.numberOfLines = 0

        bottomDivider.backgroundColor = UIColor.separator.withAlphaComponent(0.35)

        addSubview(badge)
        addSubview(bubble)
        bubble.addSubview(textLabel)
        addSubview(bottomDivider)

        badge.pinLeft(to: self.leadingAnchor, 16)
        badge.pinRight(to: self.trailingAnchor, 16)
        badge.pinTop(to: self.topAnchor, 10)

        bubble.pinLeft(to: self.leadingAnchor, 16)
        bubble.pinRight(to: self.trailingAnchor, 16)
        bubble.pinTop(to: badge.bottomAnchor, 6)

        textLabel.pinLeft(to: bubble.leadingAnchor, 12)
        textLabel.pinRight(to: bubble.trailingAnchor, 12)
        textLabel.pinTop(to: bubble.topAnchor, 10)
        textLabel.pinBottom(to: bubble.bottomAnchor, 10)

        bottomDivider.pinLeft(to: self)
        bottomDivider.pinRight(to: self)
        bottomDivider.pinTop(to: bubble.bottomAnchor, 12)
        bottomDivider.setHeight(1.0 / UIScreen.main.scale)
        bottomDivider.pinBottom(to: self)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configureAsRootMessage(_ message: CommunityMessage) {
        badge.text = "Пост"
        textLabel.text = Self.displayText(for: message)
    }

    func configureAsParentComment(_ comment: CommunityComment) {
        badge.text = "Комментарий"
        textLabel.text = comment.text
    }

    private static func displayText(for message: CommunityMessage) -> String {
        switch message.kind {
        case .post:
            return message.text
        case .announcement:
            guard let a = message.announcement else { return message.text }
            let t = a.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? message.text : t
        }
    }
}
