import UIKit

final class CommunitiesViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Сообщества"
        view.backgroundColor = TMETheme.Colors.groupedBackground
        
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = TMETheme.Fonts.body(15)
        label.textColor = TMETheme.Colors.secondaryText
        label.text = "Скелет сообществ.\nДальше: посты/анонсы, привязка к произведению, треды комментариев, анти-спойлер."
        
        view.addSubview(label)
        label.pinLeft(to: view.layoutMarginsGuide.leadingAnchor)
        label.pinRight(to: view.layoutMarginsGuide.trailingAnchor)
        label.pinCenterY(to: view.centerYAnchor)
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Создать", style: .plain, target: self, action: #selector(createTapped))
    }
    
    @objc private func createTapped() {
        let alert = UIAlertController(title: "Создать сообщество", message: "Дальше: выбор произведения из публичной базы, создание и настройки.", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        present(alert, animated: true)
    }
}

