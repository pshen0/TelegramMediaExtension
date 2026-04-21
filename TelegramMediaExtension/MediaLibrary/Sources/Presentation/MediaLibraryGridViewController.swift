import UIKit

/// Сетка постеров для текущего набора элементов (фильтры учитываются через `itemsProvider`).
final class MediaLibraryGridViewController: UICollectionViewController {
    private static let reuseId = "gridCell"

    var itemsProvider: (() -> [MediaItem])?

    init() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 12
        layout.minimumLineSpacing = 16
        layout.sectionInset = UIEdgeInsets(top: 12, left: 16, bottom: 24, right: 16)
        super.init(collectionViewLayout: layout)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Сетка"
        collectionView.backgroundColor = .systemGroupedBackground
        collectionView.alwaysBounceVertical = true
        collectionView.register(MediaLibraryGridCell.self, forCellWithReuseIdentifier: Self.reuseId)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        collectionView.reloadData()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let flow = collectionViewLayout as? UICollectionViewFlowLayout else { return }
        let w = collectionView.bounds.width - flow.sectionInset.left - flow.sectionInset.right
        let cols: CGFloat = 2
        let spacing = flow.minimumInteritemSpacing
        let cellW = floor((w - spacing) / cols)
        flow.itemSize = CGSize(width: cellW, height: cellW * 1.45 + 36)
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        itemsProvider?().count ?? 0
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: Self.reuseId, for: indexPath) as! MediaLibraryGridCell
        if let item = itemsProvider?()[indexPath.item] {
            cell.configure(item: item)
        }
        return cell
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = itemsProvider?()[indexPath.item] else { return }
        navigationController?.pushViewController(MediaItemDetailViewController(item: item), animated: true)
    }
}

private final class MediaLibraryGridCell: UICollectionViewCell {
    private let poster = UIImageView()
    private let title = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.layer.cornerRadius = 10
        contentView.clipsToBounds = true
        contentView.backgroundColor = .secondarySystemGroupedBackground

        poster.contentMode = .scaleAspectFill
        poster.clipsToBounds = true
        poster.backgroundColor = .secondarySystemFill

        title.font = TMETheme.Fonts.body(13)
        title.textColor = .label
        title.numberOfLines = 2
        title.lineBreakMode = .byTruncatingTail
        title.textAlignment = .center

        poster.translatesAutoresizingMaskIntoConstraints = false
        title.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(poster)
        contentView.addSubview(title)
        NSLayoutConstraint.activate([
            poster.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            poster.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 6),
            poster.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -6),
            poster.heightAnchor.constraint(equalTo: poster.widthAnchor, multiplier: 1.35),
            title.topAnchor.constraint(equalTo: poster.bottomAnchor, constant: 6),
            title.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            title.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            title.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -6)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(item: MediaItem) {
        title.text = item.title
        if let url = MediaLibraryStore.coverImageURL(fileName: item.coverFileName),
           let data = try? Data(contentsOf: url),
           let img = UIImage(data: data) {
            poster.image = img
            poster.contentMode = .scaleAspectFill
        } else {
            poster.contentMode = .center
            let cfg = UIImage.SymbolConfiguration(pointSize: 32, weight: .medium)
            poster.image = UIImage(systemName: symbol(for: item.kind), withConfiguration: cfg)
            poster.tintColor = .tertiaryLabel
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        poster.image = nil
        poster.contentMode = .scaleAspectFill
    }

    private func symbol(for kind: MediaItemKind) -> String {
        switch kind {
        case .film: return "film"
        case .series: return "tv"
        case .book: return "book.closed"
        case .musicAlbum: return "music.note.list"
        }
    }
}
