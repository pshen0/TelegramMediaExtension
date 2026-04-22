import UIKit

final class TMESettingsViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Настройки"
        view.backgroundColor = TMETheme.Colors.groupedBackground
        
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = TMETheme.Fonts.body(15)
        label.textColor = TMETheme.Colors.secondaryText
        label.text = "Скелет настроек.\nДальше: анти-спойлер (глобально/по сообществу/по объекту), поведение скрытых сообщений."
        
        view.addSubview(label)
        label.pinLeft(to: view.layoutMarginsGuide.leadingAnchor)
        label.pinRight(to: view.layoutMarginsGuide.trailingAnchor)
        label.pinCenterY(to: view.centerYAnchor)
    }
}

