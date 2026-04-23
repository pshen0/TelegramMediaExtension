import PhotosUI
import UIKit

final class MediaItemEditorViewController: UITableViewController {
    enum Mode {
        case create
        /// Данные из каталога (TMDB и т.п.) — поля уже заполнены, пользователь правит и сохраняет.
        case createPrefilled(MediaItem)
        case edit(existing: MediaItem)

        var navigationTitle: String {
            switch self {
            case .create: return "Новый объект"
            case .createPrefilled: return "Новый объект"
            case .edit: return "Редактирование"
            }
        }
    }

    private let mode: Mode
    private let onSave: (MediaItem) -> Void

    private var item: MediaItem
    private let keyboardDismissOnTapOutside = MediaLibraryKeyboardDismissOnTapOutside()

    private enum Section: Int, CaseIterable {
        case main
        case metadata
        case progress
        case notes
        case hashtags
        case delete
    }

    init(mode: Mode, onSave: @escaping (MediaItem) -> Void) {
        self.mode = mode
        self.onSave = onSave

        switch mode {
        case .create:
            self.item = MediaItem(kind: .film, title: "", isManuallyCreated: true)
        case .createPrefilled(let draft):
            self.item = draft
        case .edit(let existing):
            self.item = existing
        }

        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = mode.navigationTitle
        tableView.backgroundColor = TMETheme.Colors.groupedBackground
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 52
        tableView.keyboardDismissMode = .interactive
        keyboardDismissOnTapOutside.attach(to: view)

        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Сохранить", style: .done, target: self, action: #selector(saveTapped))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance
        navigationItem.compactAppearance = appearance
    }

    @objc private func saveTapped() {
        let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty {
            let alert = UIAlertController(title: "Введите название", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ок", style: .default))
            present(alert, animated: true)
            return
        }
        if item.progress.hasTotalLessThanCurrent {
            let alert = UIAlertController(
                title: "Прогресс",
                message: "«Всего» не может быть меньше текущего значения. Исправьте поля и попробуйте снова.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Ок", style: .default))
            present(alert, animated: true)
            return
        }
        item.title = title
        onSave(item)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else { return 0 }
        switch section {
        case .main: return 3
        case .metadata: return 5
        case .progress:
            if item.kind == .series { return 3 }
            return 2
        case .notes: return 1
        case .hashtags: return 1
        case .delete:
            switch mode {
            case .create, .createPrefilled:
                return 0
            case .edit:
                return 1
            }
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let section = Section(rawValue: section) else { return nil }
        switch section {
        case .main: return nil
        case .metadata: return "Карточка"
        case .progress: return "Прогресс"
        case .notes: return "Заметка / рецензия"
        case .hashtags: return "Хэштеги"
        case .delete: return nil
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard let section = Section(rawValue: section) else { return nil }
        switch section {
        case .metadata:
            return "Год, жанр, рейтинг (0–5), описание и обложка — как в публичных карточках."
        case .progress:
            switch item.kind {
            case .film: return "Для фильма — минуты (пример). Сохранение возможно, если «Всего» не меньше текущего значения."
            case .series: return "Сезон и эпизод. Сохранение возможно, если «Всего» не меньше текущего эпизода."
            case .book: return "Для книги — глава. Сохранение возможно, если «Всего» не меньше текущей."
            case .musicAlbum: return "Для альбома — трек. Сохранение возможно, если «Всего» не меньше текущего."
            }
        case .hashtags:
            return "Можно через запятую: #fantasy, books, reread"
        case .notes:
            return "До \(TMETextViewCell.defaultNotesMaxLength) символов."
        default:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = Section(rawValue: indexPath.section) else { return UITableViewCell() }

        switch section {
        case .main:
            switch indexPath.row {
            case 0:
                return makeTextFieldCell(
                    title: "Название",
                    value: item.title,
                    placeholder: "Введите название",
                    keyboard: .default
                ) { [weak self] text in
                    self?.item.title = text
                }
            case 1:
                return makeDisclosureCell(title: "Тип", value: item.kind.title)
            default:
                return makeDisclosureCell(title: "Статус", value: item.status.title)
            }
        case .metadata:
            switch indexPath.row {
            case 0:
                return makeIntCell(title: "Год", value: item.year) { [weak self] v in
                    self?.item.year = v
                }
            case 1:
                return makeTextFieldCell(title: "Жанр", value: item.genre ?? "", placeholder: "Драма, Sci-Fi…", keyboard: .default) { [weak self] t in
                    let s = t.trimmingCharacters(in: .whitespacesAndNewlines)
                    self?.item.genre = s.isEmpty ? nil : s
                }
            case 2:
                return makeTextFieldCell(
                    title: "Рейтинг",
                    value: item.rating.map { String(format: "%.1f", $0) } ?? "",
                    placeholder: "0…5",
                    keyboard: .decimalPad
                ) { [weak self] text in
                    let t = text.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespacesAndNewlines)
                    if t.isEmpty {
                        self?.item.rating = nil
                    } else if let v = Double(t) {
                        self?.item.rating = min(5, max(0, v))
                    }
                }
            case 3:
                return makeTextViewCell(
                    text: item.synopsis ?? "",
                    placeholder: "Краткое описание…",
                    maxLength: 4000
                ) { [weak self] text in
                    self?.item.synopsis = text.isEmpty ? nil : text
                }
            default:
                return makeDisclosureCell(title: "Обложка", value: item.coverFileName != nil ? "Загружена" : "Выбрать…")
            }
        case .progress:
            if item.kind == .series {
                switch indexPath.row {
                case 0:
                    return makeIntCell(title: "Сезон", value: item.progress.season) { [weak self] v in
                        self?.item.progress.season = v
                    }
                case 1:
                    return makeIntCell(title: "Эпизод (тек.)", value: item.progress.current) { [weak self] v in
                        self?.item.progress.current = v
                    }
                default:
                    return makeIntCell(title: "Эпизодов (всего)", value: item.progress.total) { [weak self] v in
                        self?.item.progress.total = v
                    }
                }
            } else if indexPath.row == 0 {
                return makeIntCell(title: "Текущий", value: item.progress.current) { [weak self] v in
                    self?.item.progress.current = v
                }
            } else {
                return makeIntCell(title: "Всего", value: item.progress.total) { [weak self] v in
                    self?.item.progress.total = v
                }
            }
        case .notes:
            return makeTextViewCell(text: item.notes, placeholder: "Добавьте заметку или рецензию...") { [weak self] text in
                self?.item.notes = text
            }
        case .hashtags:
            return makeTextFieldCell(
                title: "Хэштеги",
                value: item.hashtags.map { "#\($0)" }.joined(separator: ", "),
                placeholder: "#tag1, #tag2",
                keyboard: .default
            ) { [weak self] text in
                self?.item.hashtags = MediaHashtag.parseList(text)
            }
        case .delete:
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = "Удалить объект"
            cell.textLabel?.textAlignment = .center
            cell.textLabel?.textColor = .systemRed
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let section = Section(rawValue: indexPath.section) else { return }

        if section == .main {
            switch indexPath.row {
            case 1:
                showKindPicker()
            case 2:
                showStatusPicker()
            default:
                break
            }
        } else if section == .metadata && indexPath.row == 4 {
            presentCoverPicker()
        } else if section == .delete {
            confirmDelete()
        }
    }

    private func confirmDelete() {
        guard case .edit(let existing) = mode else { return }
        let alert = UIAlertController(title: "Удалить?", message: existing.title, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Удалить", style: .destructive) { [weak self] _ in
            MediaLibraryStore.shared.delete(id: existing.id)
            self?.navigationController?.popViewController(animated: true)
        })
        present(alert, animated: true)
    }

    private func showKindPicker() {
        let sheet = UIAlertController(title: "Тип", message: nil, preferredStyle: .actionSheet)
        for kind in MediaItemKind.allCases {
            sheet.addAction(UIAlertAction(title: kind.title, style: .default) { [weak self] _ in
                self?.item.kind = kind
                self?.tableView.reloadData()
            })
        }
        sheet.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        present(sheet, animated: true)
    }

    private func showStatusPicker() {
        let sheet = UIAlertController(title: "Статус", message: nil, preferredStyle: .actionSheet)
        for status in MediaWatchStatus.allCases {
            sheet.addAction(UIAlertAction(title: status.title, style: .default) { [weak self] _ in
                self?.item.status = status
                self?.tableView.reloadData()
            })
        }
        sheet.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        present(sheet, animated: true)
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let section = Section(rawValue: indexPath.section) else { return UITableView.automaticDimension }
        if section == .notes {
            return heightForNotesRow(tableViewWidth: tableView.bounds.width)
        }
        if section == .metadata && indexPath.row == 3 {
            return heightForSynopsisRow(tableViewWidth: tableView.bounds.width)
        }
        return UITableView.automaticDimension
    }

    private func heightForNotesRow(tableViewWidth: CGFloat) -> CGFloat {
        let text = item.notes
        let font = TMETheme.Fonts.body(16)
        let w = max(0, tableViewWidth - 64)
        let rect = (text as NSString).boundingRect(
            with: CGSize(width: w, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        let textBlock = ceil(rect.height)
        let vertical = TMETextViewCell.verticalPadding * 2 + TMETextViewCell.textViewInsets.vertical
        return max(120, textBlock + vertical)
    }

    private func heightForSynopsisRow(tableViewWidth: CGFloat) -> CGFloat {
        let text = item.synopsis ?? ""
        let font = TMETheme.Fonts.body(16)
        let w = max(0, tableViewWidth - 64)
        let rect = (text as NSString).boundingRect(
            with: CGSize(width: w, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        let textBlock = ceil(rect.height)
        let vertical = TMETextViewCell.verticalPadding * 2 + TMETextViewCell.textViewInsets.vertical
        return max(100, textBlock + vertical)
    }

    private func presentCoverPicker() {
        if #available(iOS 14.0, *) {
            var c = PHPickerConfiguration()
            c.filter = .images
            c.selectionLimit = 1
            let p = PHPickerViewController(configuration: c)
            p.delegate = self
            present(p, animated: true)
        }
    }
}

@available(iOS 14.0, *)
extension MediaItemEditorViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let pr = results.first else { return }
        if pr.itemProvider.canLoadObject(ofClass: UIImage.self) {
            pr.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] obj, _ in
                DispatchQueue.main.async {
                    guard let self, let img = obj as? UIImage, let data = img.jpegData(compressionQuality: 0.88) else { return }
                    do {
                        let name = try MediaLibraryStore.shared.saveCoverJPEG(data)
                        self.item.coverFileName = name
                        self.tableView.reloadSections(IndexSet(integer: Section.metadata.rawValue), with: .none)
                    } catch {}
                }
            }
        }
    }
}

// MARK: - Ячейка с полем (заголовок слева многострочно по центру строки, поле справа с обрезкой)

private final class TMETextFieldCell: UITableViewCell, UITextFieldDelegate {
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

// MARK: - Заметка: до 3000 символов, рост по высоте, плейсхолдер по центру

private final class TMETextViewCell: UITableViewCell, UITextViewDelegate {
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

private extension UIEdgeInsets {
    var vertical: CGFloat { top + bottom }
}

private extension MediaItemEditorViewController {
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
            // Невалидный фрагмент (редко с numberPad) — не затираем модель вызовом onChange(nil).
        }
    }

    func makeTextViewCell(text: String, placeholder: String, maxLength: Int = TMETextViewCell.defaultNotesMaxLength, onChange: @escaping (String) -> Void) -> UITableViewCell {
        let cell = TMETextViewCell(text: text, placeholder: placeholder, maxLength: maxLength, onChange: onChange)
        cell.hostingTableView = tableView
        cell.backgroundConfiguration = UIBackgroundConfiguration.listGroupedCell()
        return cell
    }
}
