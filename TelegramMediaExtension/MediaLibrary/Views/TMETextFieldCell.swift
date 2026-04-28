import UIKit

// MARK: - Ячейка с полем (заголовок слева многострочно по центру строки, поле справа с обрезкой)

final class TMETextFieldCell: UITableViewCell, UITextFieldDelegate {
    private let onChange: (String) -> Void
    let field = UITextField()
    private let titleView = UILabel()

    init(title: String, value: String, placeholder: String, keyboard: UIKeyboardType, onChange: @escaping (String) -> Void) {
        self.onChange = onChange
        super.init(style: .default, reuseIdentifier: nil)

        selectionStyle = .none

        titleView.text = title
        titleView.font = .preferredFont(forTextStyle: .body)
        titleView.textColor = .label
        titleView.numberOfLines = 2
        titleView.lineBreakMode = .byWordWrapping
        titleView.adjustsFontForContentSizeCategory = true
        titleView.setContentHuggingPriority(.required, for: .vertical)
        titleView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        field.text = value
        field.placeholder = placeholder
        field.font = .preferredFont(forTextStyle: .body)
        field.keyboardType = keyboard
        field.returnKeyType = .done
        field.textAlignment = .natural
        field.borderStyle = .none
        field.backgroundColor = .clear
        field.contentVerticalAlignment = .center
        field.clearButtonMode = .whileEditing
        field.adjustsFontSizeToFitWidth = false
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.addTarget(self, action: #selector(changed), for: .editingChanged)
        field.delegate = self

        contentView.addSubview(titleView)
        contentView.addSubview(field)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let bounds = contentView.bounds
        let marginL = contentView.layoutMargins.left
        let marginR = contentView.layoutMargins.right
        let innerW = bounds.width - marginL - marginR
        let titleMaxW = min(innerW * 0.38, 148)
        let h = bounds.height
        let titleSize = titleView.sizeThatFits(CGSize(width: titleMaxW, height: h - 8))
        let titleW = min(titleMaxW, ceil(titleSize.width))
        let titleH = min(ceil(titleSize.height), h - 8)
        titleView.frame = CGRect(x: marginL, y: (h - titleH) / 2, width: titleW, height: titleH)

        let spacing: CGFloat = 8
        let fieldX = marginL + titleW + spacing
        let fieldW = max(44, innerW - titleW - spacing)
        let fieldH = min(40, h - 8)
        field.frame = CGRect(x: fieldX, y: (h - fieldH) / 2, width: fieldW, height: fieldH)
    }

    @objc private func changed() {
        onChange(field.text ?? "")
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
