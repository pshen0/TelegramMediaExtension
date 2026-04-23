import UIKit

/// Тап по «пустому» месту экрана закрывает клавиатуру, не перехватывая кнопки и поля ввода.
@MainActor
final class MediaLibraryKeyboardDismissOnTapOutside: NSObject, UIGestureRecognizerDelegate {
    private weak var hostView: UIView?

    private lazy var tap: UITapGestureRecognizer = {
        let g = UITapGestureRecognizer(target: self, action: #selector(onTap))
        g.cancelsTouchesInView = false
        g.delegate = self
        return g
    }()

    func attach(to hostView: UIView) {
        self.hostView = hostView
        guard tap.view == nil else { return }
        hostView.addGestureRecognizer(tap)
    }

    @objc private func onTap() {
        hostView?.endEditing(true)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard gestureRecognizer === tap else { return true }
        var v: UIView? = touch.view
        while let cur = v {
            if cur is UITextField || cur is UITextView { return false }
            if cur is UISearchBar { return false }
            if cur is UIControl { return false }
            v = cur.superview
        }
        return true
    }
}
