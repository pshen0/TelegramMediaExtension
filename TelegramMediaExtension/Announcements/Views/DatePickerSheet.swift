import UIKit

// MARK: - DatePickerSheet

final class DatePickerSheet: UIViewController {

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

    @objc private func doneTapped() {
        onPick(picker.date)
        dismiss(animated: true)
    }
}
