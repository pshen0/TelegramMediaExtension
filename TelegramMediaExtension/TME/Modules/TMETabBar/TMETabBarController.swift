import UIKit

final class TMETabBarController: UITabBarController, UITabBarControllerDelegate {
    private var contactsNavigationController: UINavigationController!

    override func viewDidLoad() {
        super.viewDidLoad()

        delegate = self
        view.backgroundColor = .systemBackground

        let contacts = TMENavigationController(rootViewController: TMEContactsPlaceholderViewController())
        contacts.tabBarItem = UITabBarItem(
            title: "Контакты",
            image: UIImage(systemName: "person.crop.circle"),
            tag: 0
        )
        contactsNavigationController = contacts

        let chats = TMENavigationController(rootViewController: CommunitiesBuilder.build())
        chats.tabBarItem = UITabBarItem(
            title: "Чаты",
            image: UIImage(systemName: "bubble.left.and.bubble.right.fill"),
            tag: 1
        )

        let settings = TMENavigationController(rootViewController: TMESettingsBuilder.build())
        settings.tabBarItem = UITabBarItem(
            title: "Настройки",
            image: Self.circularTabAvatarImage(named: "cat1", traitCollection: traitCollection),
            tag: 2
        )

        chats.onNavigationStackDidChange = { [weak self] in
            self?.updateTabBarVisibilityForCurrentStack(animated: false)
        }
        settings.onNavigationStackDidChange = { [weak self] in
            self?.updateTabBarVisibilityForCurrentStack(animated: false)
        }

        viewControllers = [contacts, chats, settings]
        selectedIndex = 1

        updateTabBarVisibilityForCurrentStack(animated: false)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateTabBarVisibilityForCurrentStack(animated: false)
    }

    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        viewController !== contactsNavigationController
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        updateTabBarVisibilityForCurrentStack(animated: false)
    }

    private func updateTabBarVisibilityForCurrentStack(animated: Bool) {
        guard let nav = selectedViewController as? UINavigationController else {
            setTabBarHidden(true, animated: animated)
            return
        }
        let top = nav.topViewController
        let showTabBar = top is CommunityListViewController || top is TMESettingsViewController
        setTabBarHidden(!showTabBar, animated: animated)
    }

    private static func circularTabAvatarImage(named assetName: String, traitCollection: UITraitCollection, diameter: CGFloat = 26) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = traitCollection.displayScale
        format.opaque = false
        let size = CGSize(width: diameter, height: diameter)

        guard let source = UIImage(named: assetName) else {
            let fallback = UIImage(systemName: "person.crop.circle.fill") ?? UIImage()
            let renderer = UIGraphicsImageRenderer(size: size, format: format)
            return renderer.image { _ in
                fallback.draw(in: CGRect(origin: .zero, size: size))
            }.withRenderingMode(.alwaysOriginal)
        }

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            ctx.cgContext.addEllipse(in: rect)
            ctx.cgContext.clip()
            source.draw(in: rect)
        }.withRenderingMode(.alwaysOriginal)
    }
}

private final class TMEContactsPlaceholderViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Контакты"
    }
}
