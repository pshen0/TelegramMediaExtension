import MapKit
import PhotosUI
import UIKit

final class NewAnnouncementViewController: UITableViewController {
    private let store = CommunityStore.shared
    private let communityId: UUID

    private var titleText: String = ""
    private var date: Date = Date().addingTimeInterval(60 * 60 * 24)
    private var detailsText: String = ""
    private var linkText: String = ""
    private var pickedLocation: CommunityLocation?
    private var imageFileName: String?
    private var mediaLibraryChromeObserver: NSObjectProtocol?

    init(communityId: UUID) {
        self.communityId = communityId
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.titleView = makeNavTitleView("Новый анонс")
        tableView.backgroundColor = TMETheme.Colors.groupedBackground

        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Отмена", style: .plain, target: self, action: #selector(cancelTapped))
        // Компактнее, чтобы не «съедать» место заголовка
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "checkmark"), style: .done, target: self, action: #selector(publishTapped))
        navigationItem.rightBarButtonItem?.accessibilityLabel = "Опубликовать"

        applyMediaLibraryChromeToNavigation()
        mediaLibraryChromeObserver = NotificationCenter.default.addObserver(
            forName: .mediaLibraryBannerColorDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyMediaLibraryChromeToNavigation()
        }
    }

    deinit {
        if let mediaLibraryChromeObserver {
            NotificationCenter.default.removeObserver(mediaLibraryChromeObserver)
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyMediaLibraryChromeToNavigation()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyMediaLibraryChromeToNavigation()
    }

    private func applyMediaLibraryChromeToNavigation() {
        let c = MediaLibraryHeaderBannerColor.catalogChromeAccent(for: traitCollection)
        navigationItem.leftBarButtonItem?.tintColor = c
        navigationItem.rightBarButtonItem?.tintColor = c
        navigationController?.navigationBar.tintColor = c
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func publishTapped() {
        let t = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty {
            let alert = UIAlertController(title: "Введите заголовок", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ок", style: .default))
            present(alert, animated: true)
            return
        }
        store.addAnnouncement(
            communityId: communityId,
            title: t,
            date: date,
            details: detailsText,
            imageFileName: imageFileName,
            linkURL: linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : linkText,
            location: pickedLocation
        )
        dismiss(animated: true)
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 3 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 3 // title + date + image
        case 1: return 2 // link + location
        default: return 1 // details
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "Событие"
        case 1: return "Вложения"
        default: return "Описание"
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 && indexPath.row == 0 {
            return makeTextFieldCell(title: "Заголовок", value: titleText, placeholder: "Премьера, релиз…") { [weak self] t in
                self?.titleText = t
            }
        }
        if indexPath.section == 0 && indexPath.row == 1 {
            let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
            cell.textLabel?.text = "Дата"
            cell.detailTextLabel?.text = Self.formatDate(date)
            cell.accessoryType = .disclosureIndicator
            cell.backgroundConfiguration = UIBackgroundConfiguration.listGroupedCell()
            return cell
        }
        if indexPath.section == 0 && indexPath.row == 2 {
            let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
            cell.textLabel?.text = "Картинка"
            cell.detailTextLabel?.text = imageFileName == nil ? "Добавить" : "Выбрана"
            cell.accessoryType = .disclosureIndicator
            cell.backgroundConfiguration = UIBackgroundConfiguration.listGroupedCell()
            return cell
        }
        if indexPath.section == 1 && indexPath.row == 0 {
            return makeTextFieldCell(title: "Ссылка", value: linkText, placeholder: "https://…") { [weak self] t in
                self?.linkText = t
            }
        }
        if indexPath.section == 1 && indexPath.row == 1 {
            let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
            cell.textLabel?.text = "Место"
            cell.detailTextLabel?.text = pickedLocation?.title ?? (pickedLocation == nil ? "Добавить" : "Выбрано")
            cell.accessoryType = .disclosureIndicator
            cell.backgroundConfiguration = UIBackgroundConfiguration.listGroupedCell()
            return cell
        }
        return makeTextViewCell(text: detailsText, placeholder: "Кратко: что и где будет…") { [weak self] t in
            self?.detailsText = t
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 && indexPath.row == 1 {
            let picker = DatePickerSheet(date: date) { [weak self] d in
                self?.date = d
                self?.tableView.reloadRows(at: [indexPath], with: .none)
            }
            let nav = UINavigationController(rootViewController: picker)
            nav.modalPresentationStyle = .pageSheet
            present(nav, animated: true)
        } else if indexPath.section == 0 && indexPath.row == 2 {
            presentImagePicker()
        } else if indexPath.section == 1 && indexPath.row == 1 {
            let picker = MapPointPickerViewController { [weak self] loc in
                self?.pickedLocation = loc
                self?.tableView.reloadRows(at: [indexPath], with: .none)
            }
            let nav = UINavigationController(rootViewController: picker)
            nav.modalPresentationStyle = .pageSheet
            present(nav, animated: true)
        }
    }

    private func makeNavTitleView(_ title: String) -> UIView {
        let label = UILabel()
        label.text = title
        label.font = TMETheme.Fonts.titleSemibold(17)
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.72
        label.lineBreakMode = .byClipping
        label.textAlignment = .center
        return label
    }

    private func presentImagePicker() {
        guard #available(iOS 14.0, *) else { return }
        var c = PHPickerConfiguration()
        c.filter = .images
        c.selectionLimit = 1
        let p = PHPickerViewController(configuration: c)
        p.delegate = self
        present(p, animated: true)
    }

    private static func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }
}

private final class DatePickerSheet: UIViewController {
    private let onPick: (Date) -> Void
    private let picker = UIDatePicker()

    init(date: Date, onPick: @escaping (Date) -> Void) {
        self.onPick = onPick
        super.init(nibName: nil, bundle: nil)
        picker.date = date
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Дата"
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Готово", style: .done, target: self, action: #selector(doneTapped))
        applyMediaLibraryChromeToNavigationBar()

        picker.preferredDatePickerStyle = .wheels
        picker.datePickerMode = .dateAndTime

        view.addSubview(picker)
        picker.pinLeft(to: view)
        picker.pinRight(to: view)
        picker.pinBottom(to: view.safeAreaLayoutGuide.bottomAnchor)
        picker.pinTop(to: view.safeAreaLayoutGuide.topAnchor)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyMediaLibraryChromeToNavigationBar()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyMediaLibraryChromeToNavigationBar()
    }

    private func applyMediaLibraryChromeToNavigationBar() {
        let c = MediaLibraryHeaderBannerColor.catalogChromeAccent(for: traitCollection)
        navigationItem.rightBarButtonItem?.tintColor = c
        navigationController?.navigationBar.tintColor = c
    }

    @objc private func doneTapped() {
        onPick(picker.date)
        dismiss(animated: true)
    }
}

private extension NewAnnouncementViewController {
    func makeTextFieldCell(title: String, value: String, placeholder: String, onChange: @escaping (String) -> Void) -> UITableViewCell {
        let cell = CommunityTextFieldCell(title: title, value: value, placeholder: placeholder, keyboard: .default, onChange: onChange)
        cell.backgroundConfiguration = UIBackgroundConfiguration.listGroupedCell()
        return cell
    }

    func makeTextViewCell(text: String, placeholder: String, onChange: @escaping (String) -> Void) -> UITableViewCell {
        let cell = CommunityTextViewCell(text: text, placeholder: placeholder, maxLength: 2000, onChange: onChange)
        cell.hostingTableView = tableView
        cell.backgroundConfiguration = UIBackgroundConfiguration.listGroupedCell()
        return cell
    }
}

private final class CommunityTextFieldCell: UITableViewCell, UITextFieldDelegate {
    private let onChange: (String) -> Void
    private let titleView = UILabel()
    private let field = UITextField()

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

private final class CommunityTextViewCell: UITableViewCell, UITextViewDelegate {
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

@available(iOS 14.0, *)
extension NewAnnouncementViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let pr = results.first else { return }
        if pr.itemProvider.canLoadObject(ofClass: UIImage.self) {
            pr.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] obj, _ in
                DispatchQueue.main.async {
                    guard let self, let img = obj as? UIImage, let data = img.jpegData(compressionQuality: 0.88) else { return }
                    do {
                        self.imageFileName = try self.store.saveAnnouncementImageJPEG(data)
                        self.tableView.reloadData()
                    } catch {}
                }
            }
        }
    }
}

private final class MapPointPickerViewController: UIViewController, MKMapViewDelegate {
    private let onPick: (CommunityLocation) -> Void
    private let map = MKMapView()
    private let pin = UIImageView(image: UIImage(systemName: "mappin.circle.fill"))

    init(onPick: @escaping (CommunityLocation) -> Void) {
        self.onPick = onPick
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Точка на карте"
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Готово", style: .done, target: self, action: #selector(doneTapped))

        map.delegate = self
        view.addSubview(map)
        map.pin(to: view)

        pin.contentMode = .scaleAspectFit
        view.addSubview(pin)
        pin.setWidth(44)
        pin.setHeight(44)
        pin.pinCenter(to: view)
        applyMediaLibraryChrome()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyMediaLibraryChrome()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyMediaLibraryChrome()
    }

    private func applyMediaLibraryChrome() {
        let c = MediaLibraryHeaderBannerColor.catalogChromeAccent(for: traitCollection)
        pin.tintColor = c
        navigationItem.rightBarButtonItem?.tintColor = c
        navigationController?.navigationBar.tintColor = c
    }

    @objc private func doneTapped() {
        let c = map.centerCoordinate
        onPick(CommunityLocation(latitude: c.latitude, longitude: c.longitude, title: "Точка на карте"))
        dismiss(animated: true)
    }
}
