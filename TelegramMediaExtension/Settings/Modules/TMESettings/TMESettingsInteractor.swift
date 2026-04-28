import Foundation

protocol TMESettingsBusinessLogic: AnyObject {
    func viewDidLoad(_ request: TMESettingsModel.ViewDidLoad.Request)
    func didSelectAction(_ action: TMESettingsModel.Rows.Action)
}

protocol TMESettingsRoutingLogic: AnyObject {
    func routeToMediaLibrary()
    func routeToAnnouncements()
    func routeToBackendURLPrompt()
}

final class TMESettingsInteractor: TMESettingsBusinessLogic {
    private let presenter: TMESettingsPresentationLogic
    weak var router: TMESettingsRoutingLogic?

    init(presenter: TMESettingsPresentationLogic) {
        self.presenter = presenter
    }

    func viewDidLoad(_ request: TMESettingsModel.ViewDidLoad.Request) {
        presenter.presentRows(.init(groups: makeGroups()))
    }

    func didSelectAction(_ action: TMESettingsModel.Rows.Action) {
        switch action {
        case .openMediaLibrary:
            router?.routeToMediaLibrary()
        case .openAnnouncements:
            router?.routeToAnnouncements()
        case .openBackendURL:
            router?.routeToBackendURLPrompt()
        }
    }

    private func makeGroups() -> [TMESettingsModel.Rows.Group] {
        let block1 = TMESettingsModel.Rows.Group(rows: [
            .init(iconName: "face.smiling", title: "Сменить эмодзи-статус", detail: nil, showsChevron: false, iconScale: 0.85, action: nil),
            .init(iconName: "paintpalette", title: "Изменить цвет профиля", detail: nil, showsChevron: false, iconScale: nil, action: nil),
            .init(iconName: "camera", title: "Изменить фотографию", detail: nil, showsChevron: false, iconScale: nil, action: nil)
        ])

        let myProfile = TMESettingsModel.Rows.Group(rows: [
            .init(iconName: "profile", title: "Мой профиль", detail: nil, showsChevron: true, iconScale: nil, action: nil)
        ])

        let library = TMESettingsModel.Rows.Group(rows: [
            .init(iconName: "media", title: "Медиатека", detail: nil, showsChevron: true, iconScale: nil, action: .openMediaLibrary),
            .init(iconName: "anounce", title: "Мои анонсы", detail: nil, showsChevron: true, iconScale: nil, action: .openAnnouncements)
        ])

        let backend = TMESettingsModel.Rows.Group(rows: [
            .init(iconName: "network", title: "Backend URL", detail: BackendAuthStore.shared.baseURL.absoluteString, showsChevron: true, iconScale: nil, action: .openBackendURL)
        ])

        return [block1, myProfile, library, backend]
    }
}

