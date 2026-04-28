import UIKit

enum MediaCatalogSearchBuilder {
    static func build(style: UITableView.Style) -> MediaCatalogSearchViewController {
        let presenter = MediaCatalogSearchPresenter()
        let interactor = MediaCatalogSearchInteractor(presenter: presenter)
        let view = MediaCatalogSearchViewController(style: style, interactor: interactor)
        presenter.view = view
        return view
    }
}

