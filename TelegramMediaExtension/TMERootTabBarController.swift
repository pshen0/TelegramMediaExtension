import UIKit

final class TMERootTabBarController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = TMETheme.Colors.background
        tabBar.isTranslucent = true
        
        let media = TMENavigationController(rootViewController: MediaLibraryBuilder.build())
        media.tabBarItem = UITabBarItem(title: "Медиатека", image: UIImage(systemName: "rectangle.stack"), tag: 0)
        
        let communities = TMENavigationController(rootViewController: CommunitiesViewController())
        communities.tabBarItem = UITabBarItem(title: "Сообщества", image: UIImage(systemName: "bubble.left.and.bubble.right"), tag: 1)
        
        let announcements = TMENavigationController(rootViewController: AnnouncementsViewController())
        announcements.tabBarItem = UITabBarItem(title: "Анонсы", image: UIImage(systemName: "megaphone"), tag: 2)
        
        let settings = TMENavigationController(rootViewController: TMESettingsViewController())
        settings.tabBarItem = UITabBarItem(title: "Настройки", image: UIImage(systemName: "gearshape"), tag: 3)
        
        self.viewControllers = [media, communities, announcements, settings]
    }
}

final class TMENavigationController: UINavigationController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationBar.prefersLargeTitles = true
        navigationBar.tintColor = TMETheme.Colors.accent
    }
}

