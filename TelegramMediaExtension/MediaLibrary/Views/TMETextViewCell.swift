import UIKit

// MARK: - Заметка: до 3000 символов, рост по высоте, плейсхолдер по центру

final class TMETextViewCell: UITableViewCell, UITextViewDelegate {
    static let defaultNotesMaxLength = 3000
    static let verticalPadding: CGFloat = 8
    static let textViewInsets = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)

    private let maxLength: Int
    private let onChange: (String) -> Void
    private let placeholder: String
    private let textView = UITextView()
    private let placeholderLabel = UILabel()

    weak var hostingTableView: UITableView?

    init(text: String, placeholder: String, maxLength: Int = TMETextViewCell.defaultNotesMaxLength, onChange: @escaping (String) -> Void) {
        self.maxLength = maxLength
        self.onChange = onChange
        self.placeholder = placeholder
        super.init(style: .default, reuseIdentifier: nil)

        selectionStyle = .none

        textView.font = TMETheme.Fonts.body(16)
        textView.backgroundColor = .clear
        textView.delegate = self
        textView.text = text
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainerInset = Self.textViewInsets
        textView.isScrollEnabled = false
        textView.textDragInteraction?.isEnabled = true
        textView.keyboardDismissMode = .interactive

        placeholderLabel.numberOfLines = 0
        updatePlaceholderAttributed()

        contentView.addSubview(textView)
        contentView.addSubview(placeholderLabel)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func updatePlaceholderAttributed() {
        let p = NSMutableParagraphStyle()
        p.alignment = .center
        placeholderLabel.attributedText = NSAttributedString(
            string: placeholder,
            attributes: [
                .font: TMETheme.Fonts.body(16),
                .foregroundColor: TMETheme.Colors.secondaryText,
                .paragraphStyle: p
            ]
        )
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let b = contentView.bounds.insetBy(dx: 0, dy: Self.verticalPadding)
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

extension UIEdgeInsets {
    var vertical: CGFloat { top + bottom }
}

extension MediaItemEditorViewController {
    func makeDisclosureCell(title: String, value: String) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.text = title
        cell.textLabel?.numberOfLines = 2
        cell.textLabel?.lineBreakMode = .byTruncatingTail
        cell.detailTextLabel?.text = value
        cell.detailTextLabel?.numberOfLines = 2
        cell.detailTextLabel?.lineBreakMode = .byTruncatingTail
        cell.accessoryType = .disclosureIndicator
        cell.backgroundConfiguration = UIBackgroundConfiguration.listGroupedCell()
        cell.selectionStyle = .default
        return cell
    }

    func makeTextFieldCell(title: String, value: String, placeholder: String, keyboard: UIKeyboardType, onChange: @escaping (String) -> Void) -> UITableViewCell {
        let cell = TMETextFieldCell(title: title, value: value, placeholder: placeholder, keyboard: keyboard, onChange: onChange)
        cell.backgroundConfiguration = UIBackgroundConfiguration.listGroupedCell()
        return cell
    }

    func makeIntCell(title: String, value: Int?, onChange: @escaping (Int?) -> Void) -> UITableViewCell {
        makeTextFieldCell(
            title: title,
            value: value.map(String.init) ?? "",
            placeholder: "—",
            keyboard: .numberPad
        ) { text in
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                onChange(nil)
            } else if let v = Int(trimmed) {
                onChange(v)
            }
        }
    }

    func makeTextViewCell(text: String, placeholder: String, maxLength: Int = TMETextViewCell.defaultNotesMaxLength, onChange: @escaping (String) -> Void) -> UITableViewCell {
        let cell = TMETextViewCell(text: text, placeholder: placeholder, maxLength: maxLength, onChange: onChange)
        cell.hostingTableView = tableView
        cell.backgroundConfiguration = UIBackgroundConfiguration.listGroupedCell()
        return cell
    }
}
