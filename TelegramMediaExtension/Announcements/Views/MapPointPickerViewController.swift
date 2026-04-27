import MapKit
import PhotosUI
import UIKit

// MARK: - Map point picker

final class MapPointPickerViewController: UIViewController, MKMapViewDelegate {

    private let onPick: (CommunityLocation) -> Void
    private let map = MKMapView()
    private let pin = UIImageView(image: UIImage(systemName: "mappin.circle.fill"))

    init(onPick: @escaping (CommunityLocation) -> Void) {
        self.onPick = onPick
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Точка на карте"
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Готово", style: .done, target: self, action: #selector(doneTapped))

        map.delegate = self
        view.addSubview(map)
        map.pin(to: view)

        pin.contentMode = .scaleAspectFit
        view.addSubview(pin)
        pin.setWidth(44)
        pin.setHeight(44)
        pin.pinCenter(to: view)
    }

    @objc private func doneTapped() {
        let c = map.centerCoordinate
        onPick(CommunityLocation(latitude: c.latitude, longitude: c.longitude, title: "Точка на карте"))
        dismiss(animated: true)
    }
}
