import UIKit

/// Поле «подпись слева — ввод справа» как в форме анонса (`NewAnnouncementViewController`).
final class CommunityTextFieldCell: UITableViewCell, UITextFieldDelegate {
    private let onChange: (String) -> Void
    private let titleView = UILabel()
    let field = UITextField()

    init(title: String, value: String, placeholder: String, keyboard: UIKeyboardType, onChange: @escaping (String) -> Void) {
        self.onChange = onChange
        super.init(style: .default, reuseIdentifier: nil)
        selectionStyle = .none

        titleView.text = title
        titleView.font = .preferredFont(forTextStyle: .body)
        titleView.textColor = .label
        titleView.numberOfLines = 2
        titleView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        field.text = value
        field.placeholder = placeholder
        field.font = .preferredFont(forTextStyle: .body)
        field.keyboardType = keyboard
        field.returnKeyType = .done
        field.clearButtonMode = .whileEditing
        field.addTarget(self, action: #selector(changed), for: .editingChanged)
        field.delegate = self

        contentView.addSubview(titleView)
        contentView.addSubview(field)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let b = contentView.bounds
        let ml = contentView.layoutMargins.left
        let mr = contentView.layoutMargins.right
        let innerW = b.width - ml - mr
        let titleMaxW = min(innerW * 0.42, 160)
        let h = b.height
        let titleSize = titleView.sizeThatFits(CGSize(width: titleMaxW, height: h - 8))
        let titleW = min(titleMaxW, ceil(titleSize.width))
        let titleH = min(ceil(titleSize.height), h - 8)
        titleView.frame = CGRect(x: ml, y: (h - titleH) / 2, width: titleW, height: titleH)

        let spacing: CGFloat = 10
        let fx = ml + titleW + spacing
        let fw = max(44, innerW - titleW - spacing)
        field.frame = CGRect(x: fx, y: (h - 40) / 2, width: fw, height: 40)
    }

    @objc private func changed() {
        onChange(field.text ?? "")
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

/// Многострочное поле как в описании анонса.
final class CommunityTextViewCell: UITableViewCell, UITextViewDelegate {
    private let maxLength: Int
    private let onChange: (String) -> Void
    private let placeholder: String
    private let textView = UITextView()
    private let placeholderLabel = UILabel()
    weak var hostingTableView: UITableView?

    init(text: String, placeholder: String, maxLength: Int, onChange: @escaping (String) -> Void) {
        self.maxLength = maxLength
        self.onChange = onChange
        self.placeholder = placeholder
        super.init(style: .default, reuseIdentifier: nil)
        selectionStyle = .none

        textView.font = TMETheme.Fonts.body(16)
        textView.backgroundColor = .clear
        textView.delegate = self
        textView.text = text
        textView.textContainerInset = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        textView.isScrollEnabled = false

        placeholderLabel.numberOfLines = 0
        placeholderLabel.font = TMETheme.Fonts.body(16)
        placeholderLabel.textColor = TMETheme.Colors.secondaryText
        placeholderLabel.textAlignment = .center
        placeholderLabel.text = placeholder

        contentView.addSubview(textView)
        contentView.addSubview(placeholderLabel)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let b = contentView.bounds.insetBy(dx: 0, dy: 8)
        textView.frame = b

        if textView.text.isEmpty {
            placeholderLabel.isHidden = false
            let innerW = max(0, b.width - textView.textContainerInset.left - textView.textContainerInset.right)
            let sz = placeholderLabel.sizeThatFits(CGSize(width: innerW, height: CGFloat.greatestFiniteMagnitude))
            placeholderLabel.frame = CGRect(
                x: b.minX + (b.width - min(innerW, sz.width)) / 2,
                y: b.minY + (b.height - sz.height) / 2,
                width: min(innerW, sz.width),
                height: sz.height
            )
        } else {
            placeholderLabel.isHidden = true
        }
    }

    func textViewDidChange(_ textView: UITextView) {
        onChange(textView.text)
        setNeedsLayout()
        hostingTableView?.performBatchUpdates({}, completion: nil)
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let current = textView.text ?? ""
        guard let r = Range(range, in: current) else { return true }
        let next = current.replacingCharacters(in: r, with: text)
        return next.count <= maxLength
    }
}

/// Аватар и кнопка смены фото для экрана редактирования сообщества.
final class CommunityAvatarEditCell: UITableViewCell {
    static let reuseId = "CommunityAvatarEditCell"

    let avatarView = UIImageView()
    let changePhotoButton = UIButton(type: .system)
    var onPhotoAction: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none

        avatarView.translatesAutoresizingMaskIntoConstraints = false
        avatarView.layer.cornerRadius = 50
        if #available(iOS 13.0, *) {
            avatarView.layer.cornerCurve = .continuous
        }
        avatarView.clipsToBounds = true
        avatarView.contentMode = .scaleAspectFill
        avatarView.isUserInteractionEnabled = true

        changePhotoButton.translatesAutoresizingMaskIntoConstraints = false
        changePhotoButton.setTitle("Сменить фото", for: .normal)
        changePhotoButton.titleLabel?.font = TMETheme.Fonts.body(15)
        changePhotoButton.setTitleColor(.label, for: .normal)
        changePhotoButton.addTarget(self, action: #selector(photoTapped), for: .touchUpInside)

        contentView.addSubview(avatarView)
        contentView.addSubview(changePhotoButton)

        avatarView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(photoTapped)))

        NSLayoutConstraint.activate([
            avatarView.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor, constant: 16),
            avatarView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: 100),
            avatarView.heightAnchor.constraint(equalToConstant: 100),

            changePhotoButton.topAnchor.constraint(equalTo: avatarView.bottomAnchor, constant: 12),
            changePhotoButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            changePhotoButton.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor, constant: -16)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func photoTapped() {
        onPhotoAction?()
    }
}
