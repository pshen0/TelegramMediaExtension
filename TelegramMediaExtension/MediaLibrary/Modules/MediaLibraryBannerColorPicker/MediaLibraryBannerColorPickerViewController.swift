import UIKit

final class MediaLibraryBannerColorPickerViewController: UIViewController {
    var onFinish: (() -> Void)?
    private let interactor: MediaLibraryBannerColorPickerBusinessLogic

    private let rowsStack = UIStackView()
    private let topSpacer = UIView()
    private let bottomSpacer = UIView()

    static let palette: [UIColor] = [
        UIColor(red: 0.25, green: 0.55, blue: 0.98, alpha: 1),
        UIColor(red: 0.10, green: 0.72, blue: 0.92, alpha: 1),
        UIColor(red: 0.15, green: 0.82, blue: 0.62, alpha: 1),
        UIColor(red: 0.35, green: 0.88, blue: 0.38, alpha: 1),
        UIColor(red: 0.98, green: 0.82, blue: 0.18, alpha: 1),
        UIColor(red: 1.0, green: 0.58, blue: 0.22, alpha: 1),
        UIColor(red: 0.98, green: 0.38, blue: 0.42, alpha: 1),
        UIColor(red: 0.92, green: 0.28, blue: 0.58, alpha: 1),
        UIColor(red: 0.62, green: 0.38, blue: 0.98, alpha: 1),
        UIColor(red: 0.48, green: 0.42, blue: 0.95, alpha: 1),
        UIColor(red: 0.38, green: 0.52, blue: 0.98, alpha: 1),
        UIColor(red: 0.22, green: 0.62, blue: 0.78, alpha: 1),
        UIColor(red: 0.95, green: 0.48, blue: 0.72, alpha: 1),
        UIColor(red: 0.55, green: 0.72, blue: 0.35, alpha: 1),
        UIColor(red: 0.42, green: 0.48, blue: 0.58, alpha: 1),
        UIColor(red: 0.52, green: 0.38, blue: 0.68, alpha: 1)
    ]

    private static let rowSpacing: CGFloat = 12
    private static let chipSpacing: CGFloat = 8
    private static let horizontalMargin: CGFloat = 12

    init(interactor: MediaLibraryBannerColorPickerBusinessLogic) {
        self.interactor = interactor
        super.init(nibName: nil, bundle: nil)
    }

    convenience init() {
        let presenter = MediaLibraryBannerColorPickerPresenter()
        let interactor = MediaLibraryBannerColorPickerInteractor(presenter: presenter)
        self.init(interactor: interactor)
        presenter.view = self
        interactor.router = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = "Выберите свое оформление"

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeTapped)
        )

        view.layoutMargins = UIEdgeInsets(
            top: 0,
            left: Self.horizontalMargin,
            bottom: 0,
            right: Self.horizontalMargin
        )

        topSpacer.isUserInteractionEnabled = false
        bottomSpacer.isUserInteractionEnabled = false

        rowsStack.axis = .vertical
        rowsStack.spacing = Self.rowSpacing

        rowsStack.addArrangedSubview(makeColorRow(indices: 0..<8))
        rowsStack.addArrangedSubview(makeColorRow(indices: 8..<16))

        view.addSubview(topSpacer)
        view.addSubview(rowsStack)
        view.addSubview(bottomSpacer)

        topSpacer.pinTop(to: view.safeAreaLayoutGuide.topAnchor)
        topSpacer.pinLeft(to: view)
        topSpacer.pinRight(to: view)
        topSpacer.pinBottom(to: rowsStack.topAnchor)

        rowsStack.pinLeft(to: view.layoutMarginsGuide.leadingAnchor)
        rowsStack.pinRight(to: view.layoutMarginsGuide.trailingAnchor)

        bottomSpacer.pinLeft(to: view)
        bottomSpacer.pinRight(to: view)
        bottomSpacer.pinTop(to: rowsStack.bottomAnchor)
        bottomSpacer.pinBottom(to: view.bottomAnchor)

        topSpacer.pinHeight(to: bottomSpacer.heightAnchor)

        interactor.viewDidLoad(.init())
    }

    private func makeColorRow(indices: Range<Int>) -> UIStackView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = Self.chipSpacing
        row.distribution = .fillEqually
        row.alignment = .fill

        for i in indices {
            let color = Self.palette[i]
            let btn = UIButton(type: .custom)
            btn.tag = i
            btn.backgroundColor = color
            btn.layer.borderWidth = 1
            btn.layer.borderColor = UIColor.black.withAlphaComponent(0.12).cgColor
            btn.clipsToBounds = true
            btn.accessibilityLabel = "Цвет \(i + 1)"
            btn.addTarget(self, action: #selector(colorTapped(_:)), for: .touchUpInside)
            row.addArrangedSubview(btn)
            btn.pinHeight(to: btn.widthAnchor)
        }
        return row
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        for row in rowsStack.arrangedSubviews {
            guard let stack = row as? UIStackView else { continue }
            for case let btn as UIButton in stack.arrangedSubviews {
                let side = btn.bounds.width
                btn.layer.cornerRadius = side > 0 ? side / 2 : 0
            }
        }
    }

    @objc private func colorTapped(_ sender: UIButton) {
        interactor.selectColor(.init(index: sender.tag))
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    private func finishAndDismiss() {
        onFinish?()
        dismiss(animated: true)
    }
}

// MARK: - MediaLibraryBannerColorPickerDisplayLogic

extension MediaLibraryBannerColorPickerViewController: MediaLibraryBannerColorPickerDisplayLogic {
    func displayPalette(_ viewModel: MediaLibraryBannerColorPickerModel.Palette.ViewModel) {
        _ = viewModel
    }
}

// MARK: - MediaLibraryBannerColorPickerRoutingLogic

extension MediaLibraryBannerColorPickerViewController: MediaLibraryBannerColorPickerRoutingLogic {
    func routeFinishAndDismiss() {
        finishAndDismiss()
    }
}
