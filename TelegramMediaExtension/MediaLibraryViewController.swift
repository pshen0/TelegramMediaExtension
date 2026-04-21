import UIKit

final class MediaLibraryViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Медиатека"
        view.backgroundColor = TMETheme.Colors.groupedBackground
        
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = TMETheme.Fonts.body(15)
        label.textColor = TMETheme.Colors.secondaryText
        label.text = "Скелет экрана медиатеки.\nДальше: список объектов, статусы, прогресс, заметки, хэштеги, поиск и добавление."
        
        view.addSubview(label)
        label.pinLeft(to: view.layoutMarginsGuide.leadingAnchor)
        label.pinRight(to: view.layoutMarginsGuide.trailingAnchor)
        label.pinCenterY(to: view.centerYAnchor)
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Добавить", style: .plain, target: self, action: #selector(addTapped))
    }
    
    @objc private func addTapped() {
        let alert = UIAlertController(title: "Добавить в медиатеку", message: "Дальше тут будут: поиск по API и «Создать вручную».", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        present(alert, animated: true)
    }
}

