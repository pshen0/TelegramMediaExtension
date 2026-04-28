import UIKit

final class MediaLibraryGridViewController: UICollectionViewController {
    private static let reuseId = "gridCell"

    private let interactor: MediaLibraryGridBusinessLogic
    private var items: [MediaItem] = []

    private var bannerObserver: NSObjectProtocol?

    init(interactor: MediaLibraryGridBusinessLogic) {
        self.interactor = interactor
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 12
        layout.minimumLineSpacing = 16
        layout.sectionInset = UIEdgeInsets(top: 12, left: 16, bottom: 24, right: 16)
        super.init(collectionViewLayout: layout)
    }

    convenience init() {
        let presenter = MediaLibraryGridPresenter()
        let interactor = MediaLibraryGridInteractor(presenter: presenter)
        self.init(interactor: interactor)
        presenter.view = self
        interactor.router = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let bannerObserver {
            NotificationCenter.default.removeObserver(bannerObserver)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Сетка"
        collectionView.backgroundColor = .systemGroupedBackground
        collectionView.alwaysBounceVertical = true
        collectionView.register(MediaLibraryGridCell.self, forCellWithReuseIdentifier: Self.reuseId)

        bannerObserver = NotificationCenter.default.addObserver(
            forName: .mediaLibraryBannerColorDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshVisiblePosterPlaceholders()
        }

        interactor.viewDidLoad(.init())
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        interactor.viewWillAppear(.init())
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let flow = collectionViewLayout as? UICollectionViewFlowLayout else { return }
        let sideInset = flow.sectionInset.left + flow.sectionInset.right
        let w = collectionView.bounds.width - sideInset
        let cols: CGFloat = 2
        let spacing = flow.minimumInteritemSpacing
        let cellW = floor((w - spacing) / cols)
        let posterInset: CGFloat = 6
        let posterSide = cellW - posterInset * 2
        let titleBlock: CGFloat = 44
        let cellH = posterInset + posterSide + 6 + titleBlock + posterInset
        flow.itemSize = CGSize(width: cellW, height: cellH)
    }

    private func refreshVisiblePosterPlaceholders() {
        for cell in collectionView.visibleCells {
            (cell as? MediaLibraryGridCell)?.refreshPlaceholderIfNeeded()
        }
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: Self.reuseId, for: indexPath) as! MediaLibraryGridCell
        cell.configure(item: items[indexPath.item])
        return cell
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        interactor.selectItem(.init(index: indexPath.item))
    }
}

// MARK: - MediaLibraryGridDisplayLogic

extension MediaLibraryGridViewController: MediaLibraryGridDisplayLogic {
    func displayList(_ viewModel: MediaLibraryGridModel.List.ViewModel) {
        items = viewModel.items
        collectionView.reloadData()
    }
}

// MARK: - MediaLibraryGridRoutingLogic

extension MediaLibraryGridViewController: MediaLibraryGridRoutingLogic {
    func routeToItemDetail(item: MediaItem) {
        navigationController?.pushViewController(MediaItemDetailBuilder.build(item: item), animated: true)
    }
}
