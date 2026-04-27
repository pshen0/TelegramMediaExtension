import UIKit

enum AnnouncementsBuilder {
    static func build() -> UIViewController {
        AnnouncementsChromeListBuilder.myAnnouncements()
    }
}

