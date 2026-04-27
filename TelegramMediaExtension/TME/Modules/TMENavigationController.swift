import UIKit

final class TMENavigationController: UINavigationController {

    /// Вызывается после любого изменения стека (push/pop/replace), чтобы обновить таб-бар у `TMETelegramTabBarController`.
    var onNavigationStackDidChange: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationBar.prefersLargeTitles = true
        navigationBar.tintColor = TMETheme.Colors.accent
    }

    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        super.pushViewController(viewController, animated: animated)
        notifyStackChange()
    }

    override func popViewController(animated: Bool) -> UIViewController? {
        let popped = super.popViewController(animated: animated)
        notifyStackChange()
        return popped
    }

    override func popToRootViewController(animated: Bool) -> [UIViewController]? {
        let r = super.popToRootViewController(animated: animated)
        notifyStackChange()
        return r
    }

    override func popToViewController(_ viewController: UIViewController, animated: Bool) -> [UIViewController]? {
        let r = super.popToViewController(viewController, animated: animated)
        notifyStackChange()
        return r
    }

    override func setViewControllers(_ viewControllers: [UIViewController], animated: Bool) {
        super.setViewControllers(viewControllers, animated: animated)
        notifyStackChange()
    }

    private func notifyStackChange() {
        if Thread.isMainThread {
            onNavigationStackDidChange?()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.onNavigationStackDidChange?()
            }
        }
    }
}

