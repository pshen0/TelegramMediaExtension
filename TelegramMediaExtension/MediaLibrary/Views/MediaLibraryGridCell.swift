import UIKit

final class MediaLibraryGridCell: UICollectionViewCell {
    private let poster = UIImageView()
    private let title = UILabel()
    private var usesPosterPlaceholder = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.layer.cornerRadius = 10
        contentView.clipsToBounds = true
        contentView.backgroundColor = .secondarySystemGroupedBackground

        poster.contentMode = .scaleAspectFill
        poster.clipsToBounds = true
        poster.layer.cornerRadius = 12
        if #available(iOS 13.0, *) {
            poster.layer.cornerCurve = .continuous
        }
        poster.backgroundColor = UIColor.secondarySystemFill

        title.font = TMETheme.Fonts.body(13)
        title.textColor = .label
        title.numberOfLines = 2
        title.lineBreakMode = .byTruncatingTail
        title.textAlignment = .center

        contentView.addSubview(poster)
        contentView.addSubview(title)
        poster.pinTop(to: contentView.topAnchor, 6)
        poster.pinLeft(to: contentView.leadingAnchor, 6)
        poster.pinRight(to: contentView.trailingAnchor, 6)
        poster.pinHeight(to: poster.widthAnchor)

        title.pinTop(to: poster.bottomAnchor, 6)
        title.pinLeft(to: contentView.leadingAnchor, 4)
        title.pinRight(to: contentView.trailingAnchor, 4)
        title.pinBottom(to: contentView.bottomAnchor, 6, .lsOE)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(item: MediaItem) {
        title.text = item.title
        if let url = MediaLibraryStore.coverImageURL(fileName: item.coverFileName),
           let data = try? Data(contentsOf: url),
           let img = UIImage(data: data) {
            usesPosterPlaceholder = false
            poster.image = img
            poster.contentMode = .scaleAspectFill
            poster.backgroundColor = .clear
            poster.tintColor = nil
        } else {
            usesPosterPlaceholder = true
            poster.contentMode = .center
            let cfg = UIImage.SymbolConfiguration(pointSize: 32, weight: .medium)
            poster.image = UIImage(systemName: symbol(for: item.kind), withConfiguration: cfg)
            applyPosterPlaceholderColors()
        }
    }

    func refreshPlaceholderIfNeeded() {
        guard usesPosterPlaceholder else { return }
        applyPosterPlaceholderColors()
    }

    private func applyPosterPlaceholderColors() {
        poster.tintColor = MediaLibraryHeaderBannerColor.posterPlaceholderTint(for: traitCollection)
        poster.backgroundColor = MediaLibraryHeaderBannerColor.posterPlaceholderFill(for: traitCollection)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if usesPosterPlaceholder {
            applyPosterPlaceholderColors()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        usesPosterPlaceholder = false
        poster.image = nil
        poster.contentMode = .scaleAspectFill
        poster.tintColor = nil
        poster.backgroundColor = UIColor.secondarySystemFill
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
