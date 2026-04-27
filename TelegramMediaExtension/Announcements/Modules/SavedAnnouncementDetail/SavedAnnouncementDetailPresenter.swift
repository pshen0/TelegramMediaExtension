import Foundation

protocol SavedAnnouncementDetailDisplayLogic: AnyObject {
    func displayDetail(_ viewModel: SavedAnnouncementDetailModel.LoadAnnouncement.ViewModel)
}

protocol SavedAnnouncementDetailPresentationLogic: AnyObject {
    func presentAnnouncement(_ response: SavedAnnouncementDetailModel.LoadAnnouncement.Response)
}

final class SavedAnnouncementDetailPresenter: SavedAnnouncementDetailPresentationLogic {

    weak var view: SavedAnnouncementDetailDisplayLogic?

    func presentAnnouncement(_ response: SavedAnnouncementDetailModel.LoadAnnouncement.Response) {
        let a = response.announcement
        let vm = SavedAnnouncementDetailModel.LoadAnnouncement.ViewModel(
            heroTitle: a.title,
            showHeroChrome: response.heroStripVisible,
            rows: buildRows(
                announcement: a,
                heroStripVisible: response.heroStripVisible,
                communitySourceName: response.communitySourceName
            )
        )
        view?.displayDetail(vm)
    }

    private func buildRows(
        announcement a: SavedAnnouncement,
        heroStripVisible: Bool,
        communitySourceName: String?
    ) -> [SavedAnnouncementDetailModel.LoadAnnouncement.ContentRow] {
        var rows: [SavedAnnouncementDetailModel.LoadAnnouncement.ContentRow] = []

        if !heroStripVisible {
            rows.append(.inlineTitle(a.title))
        }

        rows.append(.field(title: "Дата и время события", body: Self.formatDateTime(a.date), secondary: false))

        if let d = a.details?.trimmingCharacters(in: .whitespacesAndNewlines), !d.isEmpty {
            rows.append(.field(title: "Описание", body: d, secondary: false))
        }

        if let raw = a.linkURL?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
            rows.append(.linkButton(trimmed: raw))
        }

        if let loc = a.location {
            let locText: String
            if let t = loc.title, !t.isEmpty {
                locText = "\(t)\n\(String(format: "%.5f, %.5f", loc.latitude, loc.longitude))"
            } else {
                locText = String(format: "%.5f, %.5f", loc.latitude, loc.longitude)
            }
            rows.append(.field(title: "Место", body: locText, secondary: false))
        }

        if a.sourceCommunityId != nil, let name = communitySourceName {
            rows.append(.field(title: "Источник", body: "Сообщество: \(name)", secondary: false))
        } else {
            rows.append(.field(title: "Источник", body: "Личный анонс", secondary: false))
        }

        return rows
    }

    private static func formatDateTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }
}
