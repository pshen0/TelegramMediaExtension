import UIKit

enum TMESettingsModuleBuilder {
    static func build() -> UIViewController {
        let presenter = TMESettingsPresenter()
        let interactor = TMESettingsInteractor(presenter: presenter)
        let view = TMESettingsViewController(interactor: interactor)
        presenter.view = view
        interactor.router = view
        return view
    }
}

