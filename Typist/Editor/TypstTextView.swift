//
//  TypstTextView.swift
//  Typist
//

import UIKit

final class TypstTextView: UITextView {
    private let highlighter = SyntaxHighlighter()
    private(set) var gutterView: LineNumberGutterView!
    private var storedTheme: EditorTheme = .system
    private var appearanceRegistration: (any UITraitChangeRegistration)?

    /// When true, `resignFirstResponder()` is refused.
    /// Set by PDFKitView during document reload to prevent PDFKit from
    /// dismissing the software keyboard on iPadOS.
    nonisolated(unsafe) static var suppressResignFirstResponder = false

    var onPhotoButtonTapped: (() -> Void)? {
        didSet { (inputAccessoryView as? KeyboardAccessoryView)?.onPhotoButtonTapped = onPhotoButtonTapped }
    }

    // MARK: - Init (Force TextKit 1)

    init() {
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(size: CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)

        super.init(frame: .zero, textContainer: textContainer)

        configureAppearance()
        setupGutter()
        setupAccessoryView()
        setupFindInteraction()
        setupAppearanceObservation()
        setupKeyboardAvoidance()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureAppearance()
        setupGutter()
        setupAccessoryView()
        setupFindInteraction()
        setupAppearanceObservation()
        setupKeyboardAvoidance()
    }

    // MARK: - Configuration

    private func configureAppearance() {
        font = UIFont.monospacedSystemFont(ofSize: 15, weight: .regular)
        autocorrectionType = .no
        autocapitalizationType = .none
        smartDashesType = .no
        smartQuotesType = .no
        spellCheckingType = .no
        backgroundColor = .clear
        textColor = .label
    }

    private func setupGutter() {
        gutterView = LineNumberGutterView(textView: self)
        addSubview(gutterView)
        updateGutterLayout()
    }

    private func updateGutterLayout() {
        let width = gutterView.gutterWidth
        textContainerInset = UIEdgeInsets(top: 12, left: width + 4, bottom: 12, right: 12)
        gutterView.frame = CGRect(x: 0, y: 0, width: width, height: max(contentSize.height, bounds.height))
        gutterView.setNeedsDisplay()
    }

    private func setupAccessoryView() {
        inputAccessoryView = KeyboardAccessoryView(textView: self)
    }

    private func setupFindInteraction() {
        isFindInteractionEnabled = true
    }

    private func setupAppearanceObservation() {
        appearanceRegistration = registerForTraitChanges(
            [UITraitUserInterfaceStyle.self]
        ) { (view: TypstTextView, _: UITraitCollection) in
            view.typingAttributes[.foregroundColor] = view.storedTheme.text
            view.applyHighlighting()
        }
    }

    // MARK: - Cmd+F Key Command

    override var keyCommands: [UIKeyCommand]? {
        let findCommand = UIKeyCommand(input: "f", modifierFlags: .command, action: #selector(showFind))
        findCommand.discoverabilityTitle = "Find & Replace"
        return (super.keyCommands ?? []) + [findCommand]
    }

    @objc private func showFind() {
        findInteraction?.presentFindNavigator(showingReplace: false)
    }

    // MARK: - First Responder Guard

    @discardableResult
    override func resignFirstResponder() -> Bool {
        if Self.suppressResignFirstResponder { return false }
        return super.resignFirstResponder()
    }

    // MARK: - Auto-pair Integration

    override func insertText(_ text: String) {
        if AutoPairEngine.handleInsert(text, in: self) {
            // applyHighlighting() is handled by Coordinator.textViewDidChange below
            delegate?.textViewDidChange?(self)
            return
        }
        super.insertText(text)
    }

    override func deleteBackward() {
        if AutoPairEngine.handleDelete(in: self) {
            // applyHighlighting() is handled by Coordinator.textViewDidChange below
            delegate?.textViewDidChange?(self)
            return
        }
        super.deleteBackward()
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = gutterView.gutterWidth
        gutterView.frame = CGRect(x: 0, y: 0, width: width, height: max(contentSize.height, bounds.height))
        gutterView.setNeedsDisplay()
    }

    // MARK: - Theme

    func applyTheme(_ theme: EditorTheme) {
        guard theme.id != storedTheme.id else { return }
        storedTheme = theme
        backgroundColor = theme.background
        textColor = theme.text
        typingAttributes = [
            .font: UIFont.monospacedSystemFont(ofSize: 15, weight: .regular),
            .foregroundColor: theme.text,
        ]
        highlighter.updateTheme(theme)
        gutterView.applyTheme(theme)
        applyHighlighting()
    }

    // MARK: - Highlighting

    func applyHighlighting() {
        highlighter.highlight(textStorage)
        gutterView.setNeedsDisplay()
    }

    // MARK: - Keyboard Avoidance

    private func setupKeyboardAvoidance() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardFrameWillChange(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
    }

    @objc private func keyboardFrameWillChange(_ notification: Notification) {
        guard window != nil,
              let userInfo = notification.userInfo,
              let endFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }

        // How much does the keyboard overlap the bottom of this view (in window coordinates)?
        let viewBottomY = convert(CGPoint(x: 0, y: bounds.maxY), to: nil).y
        let overlap = max(0, viewBottomY - endFrame.minY)

        let duration = (userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
        let curveRaw = (userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt) ?? 7

        UIView.animate(
            withDuration: duration, delay: 0,
            options: [.beginFromCurrentState, UIView.AnimationOptions(rawValue: curveRaw << 16)]
        ) {
            self.contentInset.bottom = overlap
            self.verticalScrollIndicatorInsets.bottom = overlap
        } completion: { _ in
            if overlap > 0 { self.scrollCursorToVisible() }
        }
    }

    private func scrollCursorToVisible() {
        guard let range = selectedTextRange else { return }
        let rect = caretRect(for: range.end).insetBy(dx: 0, dy: -8)
        scrollRectToVisible(rect, animated: true)
    }

    // MARK: - Find (programmatic trigger)

    func presentFind(showingReplace: Bool = false) {
        findInteraction?.presentFindNavigator(showingReplace: showingReplace)
    }
}
