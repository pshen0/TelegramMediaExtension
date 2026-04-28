import UIKit

final class AddToMediaLibraryViewController: UIViewController {
    private let interactor: AddToMediaLibraryBusinessLogic

    private let segment = UISegmentedControl(items: ["Поиск в базах", "Создать вручную"])
    private let container = UIView()

    private let catalogSearch = MediaCatalogSearchBuilder.build(style: .insetGrouped)
    private let manualPlaceholder = MediaLibraryManualAddBuilder.build()

    init(interactor: AddToMediaLibraryBusinessLogic) {
        self.interactor = interactor
        super.init(nibName: nil, bundle: nil)
    }

    convenience init() {
        let presenter = AddToMediaLibraryPresenter()
        let interactor = AddToMediaLibraryInteractor(presenter: presenter)
        self.init(interactor: interactor)
        presenter.view = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = "Добавить в медиатеку"

        segment.selectedSegmentIndex = 0
        segment.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)

        catalogSearch.addFlowCoordinator = self
        addChild(catalogSearch)
        addChild(manualPlaceholder)
        manualPlaceholder.coordinator = self

        view.addSubview(segment)
        view.addSubview(container)
        container.addSubview(catalogSearch.view)
        container.addSubview(manualPlaceholder.view)
        catalogSearch.didMove(toParent: self)
        manualPlaceholder.didMove(toParent: self)

        layout()

        interactor.viewDidLoad(AddToMediaLibraryModel.ViewDidLoad.Request())
    }

    private func layout() {
        segment.pinTop(to: view.safeAreaLayoutGuide.topAnchor, 8)
        segment.pinLeft(to: view.leadingAnchor, 16)
        segment.pinRight(to: view.trailingAnchor, 16)
        segment.setHeight(32)

        container.pinTop(to: segment.bottomAnchor, 8)
        container.pinLeft(to: view)
        container.pinRight(to: view)
        container.pinBottom(to: view)

        catalogSearch.view.pin(to: container)
        manualPlaceholder.view.pin(to: container)
    }

    func popToLibraryList() {
        guard let nav = navigationController else { return }
        if let list = nav.viewControllers.first(where: { $0 is MediaLibraryListViewController }) {
            nav.popToViewController(list, animated: true)
        } else {
            nav.popViewController(animated: true)
        }
    }

    @objc private func segmentChanged() {
        interactor.segmentChanged(.init(selectedIndex: segment.selectedSegmentIndex))
    }
}

// MARK: - AddToMediaLibraryDisplayLogic

extension AddToMediaLibraryViewController: AddToMediaLibraryDisplayLogic {
    func displaySegmentState(_ viewModel: AddToMediaLibraryModel.SegmentState.ViewModel) {
        if segment.selectedSegmentIndex != viewModel.selectedIndex {
            segment.selectedSegmentIndex = viewModel.selectedIndex
        }
        catalogSearch.view.isHidden = !viewModel.showSearch
        manualPlaceholder.view.isHidden = viewModel.showSearch
    }
}

