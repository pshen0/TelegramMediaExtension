import MapKit
import PhotosUI
import UIKit

final class NewAnnouncementViewController: UITableViewController {
    private let store = CommunityStore.shared
    private enum Mode {
        case community(UUID)
        case personal
        case editSaved(UUID)
    }

    private let mode: Mode

    private var titleText: String = ""
    private var date: Date = Date().addingTimeInterval(60 * 60 * 24)
    private var detailsText: String = ""
    private var linkText: String = ""
    private var pickedLocation: CommunityLocation?
    private var imageFileName: String?
    private let keyboardDismissOnTapOutside = MediaLibraryKeyboardDismissOnTapOutside()
    private var doneButtonView: LiquidGlassBarButtonView?

    init(communityId: UUID) {
        mode = .community(communityId)
        super.init(style: .insetGrouped)
    }

    init(personal: Void = ()) {
        mode = .personal
        super.init(style: .insetGrouped)
    }

    init(editingSavedAnnouncementId: UUID) {
        mode = .editSaved(editingSavedAnnouncementId)
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        switch mode {
        case .editSaved:
            navigationItem.titleView = makeNavTitleView("Изменить анонс")
        default:
            navigationItem.titleView = makeNavTitleView("Новый анонс")
        }
        tableView.backgroundColor = TMETheme.Colors.groupedBackground
        tableView.keyboardDismissMode = .interactive
        keyboardDismissOnTapOutside.attach(to: view)

        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Отмена", style: .plain, target: self, action: #selector(cancelTapped))
        let a11y: String
        switch mode {
        case .editSaved:
            a11y = "Сохранить"
        default:
            a11y = "Опубликовать"
        }
        let doneView = LiquidGlassBarButtonView(
            symbolName: "checkmark",
            accessibilityLabel: a11y,
            symbolPointSize: 17,
            showsBackground: false,
            action: { [weak self] in self?.publishTapped() }
        )
        doneView.updateBlurStyle(for: traitCollection)
        doneButtonView = doneView
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: doneView)

        store.loadIfNeeded()
        if case .editSaved(let id) = mode, let a = store.savedAnnouncements.first(where: { $0.id == id }) {
            titleText = a.title
            date = a.date
            detailsText = a.details ?? ""
            linkText = a.linkURL ?? ""
            pickedLocation = a.location
            imageFileName = a.imageFileName
        }

        tableView.reloadData()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        doneButtonView?.updateBlurStyle(for: traitCollection)
    }

    deinit {
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    @objc private func cancelTapped() {
        if case .editSaved = mode {
            navigationController?.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    @objc private func publishTapped() {
        let t = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty {
            let alert = UIAlertController(title: "Введите заголовок", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ок", style: .default))
            present(alert, animated: true)
            return
        }
        let link = linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : linkText
        switch mode {
        case .community(let communityId):
            store.addAnnouncement(
                communityId: communityId,
                title: t,
                date: date,
                details: detailsText,
                imageFileName: imageFileName,
                linkURL: link,
                location: pickedLocation
            )
        case .personal:
            store.addPersonalAnnouncement(
                title: t,
                date: date,
                details: detailsText,
                imageFileName: imageFileName,
                linkURL: link,
                location: pickedLocation
            )
        case .editSaved(let id):
            store.updateSavedAnnouncement(
                id: id,
                title: t,
                date: date,
                details: detailsText,
                imageFileName: imageFileName,
                linkURL: link,
                location: pickedLocation
            )
            navigationController?.popViewController(animated: true)
            return
        }
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
            cell.textLabel?.text = "Изображение"
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
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
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
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    private func applyMediaLibraryChrome() {}

    @objc private func doneTapped() {
        let c = map.centerCoordinate
        onPick(CommunityLocation(latitude: c.latitude, longitude: c.longitude, title: "Точка на карте"))
        dismiss(animated: true)
    }
}
