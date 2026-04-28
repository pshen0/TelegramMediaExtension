import PhotosUI
import UIKit

final class MediaItemEditorViewController: UITableViewController {
    enum Mode {
        case create
        case createPrefilled(MediaItem)
        case edit(existing: MediaItem)

        var navigationTitle: String {
            switch self {
            case .create: return "Новый объект"
            case .createPrefilled: return "Новый объект"
            case .edit: return ""
            }
        }
    }

    private let interactor: MediaItemEditorBusinessLogic
    private let mode: Mode
    private let onSave: (MediaItem) -> Void

    private var item: MediaItem
    private let keyboardDismissOnTapOutside = MediaLibraryKeyboardDismissOnTapOutside()
    private var doneButtonView: LiquidGlassBarButtonView?

    private enum Section: Int, CaseIterable {
        case main
        case metadata
        case progress
        case spoilers
        case notes
        case hashtags
        case delete
    }

    init(interactor: MediaItemEditorBusinessLogic, mode: Mode, onSave: @escaping (MediaItem) -> Void) {
        self.interactor = interactor
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

    convenience init(mode: Mode, onSave: @escaping (MediaItem) -> Void) {
        let presenter = MediaItemEditorPresenter()
        let interactor = MediaItemEditorInteractor(presenter: presenter)
        self.init(interactor: interactor, mode: mode, onSave: onSave)
        presenter.view = self
        interactor.router = self
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()

        interactor.build(.init(mode: mode))
        interactor.viewDidLoad(.init())

        tableView.backgroundColor = TMETheme.Colors.groupedBackground
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 52
        tableView.keyboardDismissMode = .interactive
        keyboardDismissOnTapOutside.attach(to: view)

        let doneView = LiquidGlassBarButtonView(
            symbolName: "checkmark",
            accessibilityLabel: "Сохранить",
            symbolPointSize: 17,
            showsBackground: false,
            action: { [weak self] in self?.saveTapped() }
        )
        doneView.updateBlurStyle(for: traitCollection)
        doneButtonView = doneView
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: doneView)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        doneButtonView?.updateBlurStyle(for: traitCollection)
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
        interactor.saveTapped(.init())
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
        case .spoilers:
            guard let id = item.catalogSourceID, id.hasPrefix("tmdb-") else { return 0 }
            return 1
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
        case .spoilers: return "Спойлеры"
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
        case .spoilers:
            return "Если включено — посты и комментарии в тематических сообществах по этому произведению будут скрываться до вашего прогресса."
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
                    self?.interactor.updateField(.init(field: .title(text)))
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
                    self?.interactor.updateField(.init(field: .year(v)))
                }
            case 1:
                return makeTextFieldCell(title: "Жанр", value: item.genre ?? "", placeholder: "Драма, Sci-Fi…", keyboard: .default) { [weak self] t in
                    let s = t.trimmingCharacters(in: .whitespacesAndNewlines)
                    self?.interactor.updateField(.init(field: .genre(s.isEmpty ? nil : s)))
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
                        self?.interactor.updateField(.init(field: .rating(nil)))
                    } else if let v = Double(t) {
                        self?.interactor.updateField(.init(field: .rating(min(5, max(0, v)))))
                    }
                }
            case 3:
                return makeTextViewCell(
                    text: item.synopsis ?? "",
                    placeholder: "Краткое описание…",
                    maxLength: 4000
                ) { [weak self] text in
                    self?.interactor.updateField(.init(field: .synopsis(text.isEmpty ? nil : text)))
                }
            default:
                return makeDisclosureCell(title: "Обложка", value: item.coverFileName != nil ? "Загружена" : "Выбрать…")
            }
        case .progress:
            if item.kind == .series {
                switch indexPath.row {
                case 0:
                    return makeIntCell(title: "Сезон", value: item.progress.season) { [weak self] v in
                        self?.interactor.updateField(.init(field: .progressSeason(v)))
                    }
                case 1:
                    return makeIntCell(title: "Эпизод (тек.)", value: item.progress.current) { [weak self] v in
                        self?.interactor.updateField(.init(field: .progressCurrent(v)))
                    }
                default:
                    return makeIntCell(title: "Эпизодов (всего)", value: item.progress.total) { [weak self] v in
                        self?.interactor.updateField(.init(field: .progressTotal(v)))
                    }
                }
            } else if indexPath.row == 0 {
                return makeIntCell(title: "Текущий", value: item.progress.current) { [weak self] v in
                    self?.interactor.updateField(.init(field: .progressCurrent(v)))
                }
            } else {
                return makeIntCell(title: "Всего", value: item.progress.total) { [weak self] v in
                    self?.interactor.updateField(.init(field: .progressTotal(v)))
                }
            }
        case .spoilers:
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.selectionStyle = .none
            cell.textLabel?.text = "Защита от спойлеров"
            let sw = UISwitch()
            sw.isOn = item.spoilersProtectionEnabled
            sw.addAction(UIAction { [weak self] _ in
                self?.interactor.updateField(.init(field: .spoilersProtectionEnabled(sw.isOn)))
            }, for: .valueChanged)
            cell.accessoryView = sw
            return cell
        case .notes:
            return makeTextViewCell(text: item.notes, placeholder: "Добавьте заметку или рецензию...") { [weak self] text in
                self?.interactor.updateField(.init(field: .notes(text)))
            }
        case .hashtags:
            return makeTextFieldCell(
                title: "Хэштеги",
                value: item.hashtags.map { "#\($0)" }.joined(separator: ", "),
                placeholder: "#tag1, #tag2",
                keyboard: .default
            ) { [weak self] text in
                self?.interactor.updateField(.init(field: .hashtags(MediaHashtag.parseList(text))))
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
            self?.interactor.deleteConfirmed(.init())
        })
        present(alert, animated: true)
    }

    private func showKindPicker() {
        let sheet = UIAlertController(title: "Тип", message: nil, preferredStyle: .actionSheet)
        for kind in MediaItemKind.allCases {
            sheet.addAction(UIAlertAction(title: kind.title, style: .default) { [weak self] _ in
                self?.interactor.updateKind(.init(kind: kind))
            })
        }
        sheet.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        present(sheet, animated: true)
    }

    private func showStatusPicker() {
        let sheet = UIAlertController(title: "Статус", message: nil, preferredStyle: .actionSheet)
        for status in MediaWatchStatus.allCases {
            sheet.addAction(UIAlertAction(title: status.title, style: .default) { [weak self] _ in
                self?.interactor.updateStatus(.init(status: status))
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

// MARK: - MediaItemEditorDisplayLogic

extension MediaItemEditorViewController: MediaItemEditorDisplayLogic {
    func displayContent(_ viewModel: MediaItemEditorModel.Content.ViewModel) {
        item = viewModel.item
        title = viewModel.navigationTitle
        tableView.reloadData()
    }

    func displayError(_ viewModel: MediaItemEditorModel.ErrorAlert.ViewModel) {
        let alert = UIAlertController(title: viewModel.title, message: viewModel.message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ок", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - MediaItemEditorRoutingLogic

extension MediaItemEditorViewController: MediaItemEditorRoutingLogic {
    func routeOnSave(item: MediaItem) {
        onSave(item)
    }

    func routeBackAfterDelete() {
        navigationController?.popViewController(animated: true)
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
                        self.interactor.updateField(.init(field: .coverFileName(name)))
                    } catch {}
                }
            }
        }
    }
}
