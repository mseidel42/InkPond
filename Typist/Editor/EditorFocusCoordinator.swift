import Foundation

@MainActor
final class EditorFocusCoordinator {
    private weak var textView: TypstTextView?

    func register(_ textView: TypstTextView) {
        self.textView = textView
    }

    func setResignSuppressed(_ isSuppressed: Bool) {
        textView?.suppressResignFirstResponder = isSuppressed
    }

    func dismissKeyboard() {
        textView?.resignFirstResponder()
    }
}
