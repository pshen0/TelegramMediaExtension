import UIKit

final class AnnouncementsViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Анонсы"
        view.backgroundColor = TMETheme.Colors.groupedBackground
        
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = TMETheme.Fonts.body(15)
        label.textColor = TMETheme.Colors.secondaryText
        label.text = "Скелет «Мои анонсы».\nДальше: лента по дате, добавление из сообществ и ручное создание."
        
        view.addSubview(label)
        label.pinLeft(to: view.layoutMarginsGuide.leadingAnchor)
        label.pinRight(to: view.layoutMarginsGuide.trailingAnchor)
        label.pinCenterY(to: view.centerYAnchor)
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Новый", style: .plain, target: self, action: #selector(newTapped))
    }
    
    @objc private func newTapped() {
        let alert = UIAlertController(title: "Новый анонс", message: "Дальше: создание локального анонса (название, дата/время, описание, платформа).", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        present(alert, animated: true)
    }
}

