import Foundation

protocol TMESettingsDisplayLogic: AnyObject {
    func displayRows(_ viewModel: TMESettingsModel.Rows.ViewModel)
}

protocol TMESettingsPresentationLogic: AnyObject {
    func presentRows(_ response: TMESettingsModel.Rows.Response)
}

final class TMESettingsPresenter: TMESettingsPresentationLogic {
    weak var view: TMESettingsDisplayLogic?

    func presentRows(_ response: TMESettingsModel.Rows.Response) {
        view?.displayRows(.init(groups: response.groups))
    }
}

