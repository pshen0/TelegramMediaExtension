import MapKit
import PhotosUI
import UIKit

final class NewAnnouncementViewController: UITableViewController {

    private let interactor: NewAnnouncementInteractor

    private let keyboardDismissOnTapOutside = MediaLibraryKeyboardDismissOnTapOutside()
    private var doneButtonView: LiquidGlassBarButtonView?

    init(interactor: NewAnnouncementInteractor) {
        self.interactor = interactor
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never

        tableView.backgroundColor = TMETheme.Colors.groupedBackground
        tableView.keyboardDismissMode = .interactive
        keyboardDismissOnTapOutside.attach(to: view)

        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Отмена", style: .plain, target: self, action: #selector(cancelTapped))
        let doneView = LiquidGlassBarButtonView(
            symbolName: "checkmark",
            accessibilityLabel: " ",
            symbolPointSize: 17,
            showsBackground: false,
            action: { [weak self] in self?.publishTapped() }
        )
        doneView.updateBlurStyle(for: traitCollection)
        doneButtonView = doneView
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: doneView)

        interactor.viewDidLoad(NewAnnouncementModel.ViewDidLoad.Request())
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        doneButtonView?.updateBlurStyle(for: traitCollection)
    }

    @objc private func cancelTapped() {
        if interactor.isEditingSavedAnnouncement {
            navigationController?.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    private func publishTapped() {
        interactor.submit(NewAnnouncementModel.Submit.Request())
    }

    // MARK: - UITableView

    override func numberOfSections(in tableView: UITableView) -> Int { 3 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 3
        case 1: return 2
        default: return 1
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
            return makeTextFieldCell(title: "Заголовок", value: interactor.titleText, placeholder: "Премьера, релиз…") { [weak self] t in
                self?.interactor.updateTitle(NewAnnouncementModel.UpdateTitle.Request(title: t))
            }
        }
        if indexPath.section == 0 && indexPath.row == 1 {
            let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
            cell.textLabel?.text = "Дата"
            cell.detailTextLabel?.text = Self.formatDate(interactor.date)
            cell.accessoryType = .disclosureIndicator
            cell.backgroundConfiguration = UIBackgroundConfiguration.listGroupedCell()
            return cell
        }
        if indexPath.section == 0 && indexPath.row == 2 {
            let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
            cell.textLabel?.text = "Изображение"
            cell.detailTextLabel?.text = interactor.imageFileName == nil ? "Добавить" : "Выбрана"
            cell.accessoryType = .disclosureIndicator
            cell.backgroundConfiguration = UIBackgroundConfiguration.listGroupedCell()
            return cell
        }
        if indexPath.section == 1 && indexPath.row == 0 {
            return makeTextFieldCell(title: "Ссылка", value: interactor.linkText, placeholder: "https://…") { [weak self] t in
                self?.interactor.updateLink(NewAnnouncementModel.UpdateLink.Request(link: t))
            }
        }
        if indexPath.section == 1 && indexPath.row == 1 {
            let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
            cell.textLabel?.text = "Место"
            let loc = interactor.pickedLocation
            cell.detailTextLabel?.text = loc == nil ? "Добавить" : (loc?.title ?? "Выбрано")
            cell.accessoryType = .disclosureIndicator
            cell.backgroundConfiguration = UIBackgroundConfiguration.listGroupedCell()
            return cell
        }
        return makeTextViewCell(text: interactor.detailsText, placeholder: "Кратко: что и где будет…") { [weak self] t in
            self?.interactor.updateDetails(NewAnnouncementModel.UpdateDetails.Request(details: t))
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 && indexPath.row == 1 {
            let picker = DatePickerSheet(date: interactor.date) { [weak self] d in
                self?.interactor.setDate(NewAnnouncementModel.SetDate.Request(date: d))
            }
            let nav = UINavigationController(rootViewController: picker)
            nav.modalPresentationStyle = .pageSheet
            present(nav, animated: true)
        } else if indexPath.section == 0 && indexPath.row == 2 {
            presentImagePicker()
        } else if indexPath.section == 1 && indexPath.row == 1 {
            let picker = MapPointPickerViewController { [weak self] loc in
                self?.interactor.setLocation(NewAnnouncementModel.SetLocation.Request(location: loc))
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

// MARK: - NewAnnouncementDisplayLogic

extension NewAnnouncementViewController: NewAnnouncementDisplayLogic {

    func displayChrome(_ viewModel: NewAnnouncementModel.Chrome.ViewModel) {
        navigationItem.titleView = makeNavTitleView(viewModel.navTitle)
        doneButtonView?.accessibilityLabel = viewModel.doneAccessibilityLabel
        navigationItem.rightBarButtonItem?.accessibilityLabel = viewModel.doneAccessibilityLabel
    }

    func displayValidationAlert(_ viewModel: NewAnnouncementModel.Validation.ViewModel) {
        let alert = UIAlertController(title: viewModel.title, message: viewModel.message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ок", style: .default))
        present(alert, animated: true)
    }

    func refreshFormTable() {
        tableView.reloadData()
    }
}

// MARK: - NewAnnouncementRoutingLogic

extension NewAnnouncementViewController: NewAnnouncementRoutingLogic {

    func closeAfterCreate() {
        dismiss(animated: true)
    }

    func closeAfterEdit() {
        navigationController?.popViewController(animated: true)
    }
}

// MARK: - Cells

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

// MARK: - PHPicker

@available(iOS 14.0, *)
extension NewAnnouncementViewController: PHPickerViewControllerDelegate {

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let pr = results.first else { return }
        if pr.itemProvider.canLoadObject(ofClass: UIImage.self) {
            pr.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] obj, _ in
                DispatchQueue.main.async {
                    guard let self, let img = obj as? UIImage, let data = img.jpegData(compressionQuality: 0.88) else { return }
                    self.interactor.savePickedImage(NewAnnouncementModel.SavePickedImage.Request(jpegData: data))
                }
            }
        }
    }
}
