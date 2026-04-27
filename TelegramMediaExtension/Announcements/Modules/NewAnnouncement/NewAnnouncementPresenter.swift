import Foundation

protocol NewAnnouncementDisplayLogic: AnyObject {
    func displayChrome(_ viewModel: NewAnnouncementModel.Chrome.ViewModel)
    func displayValidationAlert(_ viewModel: NewAnnouncementModel.Validation.ViewModel)
    func refreshFormTable()
}

protocol NewAnnouncementPresentationLogic: AnyObject {
    func presentChrome(for mode: NewAnnouncementModel.Mode)
    func presentValidationMissingTitle()
    func notifyFormDidChange()
}

final class NewAnnouncementPresenter: NewAnnouncementPresentationLogic {

    weak var view: NewAnnouncementDisplayLogic?

    func presentChrome(for mode: NewAnnouncementModel.Mode) {
        let vm: NewAnnouncementModel.Chrome.ViewModel
        switch mode {
        case .editSaved:
            vm = NewAnnouncementModel.Chrome.ViewModel(navTitle: "Изменить анонс", doneAccessibilityLabel: "Сохранить")
        case .community, .personal:
            vm = NewAnnouncementModel.Chrome.ViewModel(navTitle: "Новый анонс", doneAccessibilityLabel: "Опубликовать")
        }
        view?.displayChrome(vm)
    }

    func presentValidationMissingTitle() {
        view?.displayValidationAlert(
            NewAnnouncementModel.Validation.ViewModel(title: "Введите заголовок", message: nil)
        )
    }

    func notifyFormDidChange() {
        view?.refreshFormTable()
    }
}
