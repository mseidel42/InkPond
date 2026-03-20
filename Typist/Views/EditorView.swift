//
//  EditorView.swift
//  Typist
//

import Foundation
import SwiftUI

struct EditorViewState: Equatable {
    var selectedLocation: Int = 0
    var selectedLength: Int = 0
    var contentOffset: CGPoint = .zero
}

struct EditorInsertionRequest: Equatable, Identifiable {
    let id = UUID()
    let text: String
    let targetRange: NSRange
    let targetFileName: String
}

struct EditorView: UIViewRepresentable {
    @Binding var text: String
    @Binding var insertionRequest: EditorInsertionRequest?
    @Binding var findRequested: Bool
    @Binding var viewState: EditorViewState
    @Binding var cursorJumpOffset: Int?
    var focusCoordinator: EditorFocusCoordinator? = nil
    var sourceMap: SourceMap?
    var syncCoordinator: SyncCoordinator?
    var theme: EditorTheme = .system
    var errorLines: Set<Int> = []
    var onPhotoTapped: () -> Void = {}
    var onSnippetTapped: () -> Void = {}
    var onImagePasted: (Data, NSRange) -> Void = { _, _ in }
    var onRichPaste: ([TypstTextView.PasteFragment], NSRange) -> Void = { _, _ in }
    var fontFamilies: [String] = []
    var bibEntries: [(key: String, type: String)] = []
    var externalLabels: [(name: String, kind: String)] = []
    var imageFiles: [String] = []
    var packageSpecs: [String] = []

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> TypstTextView {
        let textView = TypstTextView()
        textView.delegate = context.coordinator
        context.coordinator.textView = textView
        focusCoordinator?.register(textView)
        textView.applyTheme(theme)
        textView.accessibilityLabel = L10n.a11yEditorLabel
        textView.accessibilityHint = L10n.a11yEditorHint
        textView.accessibilityIdentifier = "editor.text-view"
        context.coordinator.previousTextLength = text.utf16.count
        context.coordinator.restoreViewStateIfNeeded(in: textView)
        return textView
    }

    func updateUIView(_ textView: TypstTextView, context: Context) {
        context.coordinator.parent = self
        focusCoordinator?.register(textView)
        textView.applyTheme(theme)
        textView.setErrorLines(errorLines)
        textView.accessibilityLabel = L10n.a11yEditorLabel
        textView.accessibilityHint = L10n.a11yEditorHint
        textView.onPhotoButtonTapped = onPhotoTapped
        textView.onSnippetButtonTapped = onSnippetTapped
        textView.onImagePasted = onImagePasted
        textView.onRichPaste = onRichPaste
        textView.updateFontFamilies(fontFamilies)
        textView.updateBibEntries(bibEntries)
        textView.updateExternalLabels(externalLabels)
        textView.updateImageFiles(imageFiles)
        textView.updatePackageSpecs(packageSpecs)

        // Consume pending find request — defer mutation to avoid writing state during view update.
        if findRequested {
            Task { @MainActor in
                textView.presentFind(showingReplace: true)
                self.findRequested = false
            }
        }

        // Apply insertions before cursor jumps so post-insert jumps run against the new buffer.
        if let request = insertionRequest {
            let coordinator = context.coordinator
            Task { @MainActor in
                guard self.insertionRequest?.id == request.id else { return }
                self.insertionRequest = nil
                coordinator.insertText(request)
            }
            return
        }

        // Consume pending cursor jump request
        if let jumpOffset = cursorJumpOffset {
            let coordinator = context.coordinator
            Task { @MainActor in
                guard self.cursorJumpOffset == jumpOffset else { return }
                self.cursorJumpOffset = nil
                let maxOffset = textView.text.utf16.count
                let safeOffset = min(max(0, jumpOffset), maxOffset)
                textView.dismissCompletion()
                textView.suppressCompletionForNextSelectionChange()
                textView.selectedRange = NSRange(location: safeOffset, length: 0)
                coordinator.captureViewState(from: textView)
                let line = coordinator.lineNumber(forUTF16Offset: safeOffset, in: textView.text)
                textView.flashJumpHighlight(atLine: line)
                if self.syncCoordinator?.activeDirection == .previewToEditor {
                    self.syncCoordinator?.endSync()
                }
                // Scroll to reveal cursor after layout
                DispatchQueue.main.async {
                    textView.scrollSelectionToUpperThird(animated: true)
                }
            }
        }
        // Never push text back into the view while the user is actively editing.
        // Doing so can dismiss the software keyboard on iPadOS.
        guard !textView.isFirstResponder else { return }
        guard textView.text != text else { return }
        textView.text = text
        textView.scheduleHighlighting(.immediate, textChanged: true)
        context.coordinator.restoreViewStateIfNeeded(in: textView)
    }

    static func dismantleUIView(_ textView: TypstTextView, coordinator: Coordinator) {
        coordinator.captureViewState(from: textView)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: EditorView
        weak var textView: TypstTextView?
        private var lastAppliedViewState: EditorViewState?
        /// Set during `textViewDidChange` so the subsequent `textViewDidChangeSelection` knows
        /// the cursor moved because of typing, not a deliberate navigation.
        private var isProcessingTextChange = false
        /// Track previous text length to detect deletion.
        var previousTextLength: Int = 0

        init(_ parent: EditorView) {
            self.parent = parent
        }

        func insertText(_ request: EditorInsertionRequest) {
            guard let textView else { return }
            let nsString = textView.text as NSString
            let safeLocation = min(max(0, request.targetRange.location), nsString.length)
            let safeLength = min(max(0, request.targetRange.length), nsString.length - safeLocation)
            let selectedRange = NSRange(location: safeLocation, length: safeLength)
            let originalContent = nsString.substring(with: selectedRange)
            let insertedRange = NSRange(
                location: selectedRange.location,
                length: (request.text as NSString).length
            )

            textView.undoManager?.registerUndo(withTarget: textView) { tv in
                tv.textStorage.replaceCharacters(in: insertedRange, with: originalContent)
                tv.selectedRange = selectedRange
                tv.delegate?.textViewDidChange?(tv)
            }
            textView.undoManager?.setActionName(L10n.tr("action.insert_image"))

            textView.textStorage.replaceCharacters(in: selectedRange, with: request.text)
            textView.selectedRange = NSRange(location: selectedRange.location + insertedRange.length, length: 0)
            parent.text = textView.text
            captureViewState(from: textView)
            textView.scheduleHighlighting(.immediate, textChanged: true)
            DispatchQueue.main.async {
                textView.scrollSelectionToUpperThird(animated: true)
            }
        }

        func textViewDidChange(_ textView: UITextView) {
            guard let typstTextView = textView as? TypstTextView else { return }
            isProcessingTextChange = true
            defer { isProcessingTextChange = false }
            let newLength = textView.text.utf16.count
            let wasDeleting = newLength < previousTextLength
            previousTextLength = newLength
            parent.text = textView.text
            captureViewState(from: typstTextView)
            typstTextView.scheduleHighlighting(.debounced, textChanged: true)
            typstTextView.updateCompletion()
            // After deletion, center the cursor so the user can see content above.
            // Deferred to next run loop so UITextView finishes its own layout first.
            if wasDeleting {
                DispatchQueue.main.async {
                    typstTextView.scrollSelectionToCenterIfNeeded(animated: true)
                }
            }
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard let typstTextView = textView as? TypstTextView else { return }
            captureViewState(from: typstTextView)
            // After a tap-to-dismiss, skip re-triggering completion for this selection change
            if typstTextView.consumeSelectionSuppression() { return }
            typstTextView.updateCompletion()
            // On deliberate cursor movement (tap, arrow keys), center the cursor.
            if !isProcessingTextChange {
                DispatchQueue.main.async {
                    typstTextView.scrollSelectionToCenterIfNeeded(animated: true)
                }
            }
            // Only sync cursor to preview on deliberate navigation (tap, arrow keys),
            // not on every keystroke — typing causes noisy preview jumps.
            if !isProcessingTextChange,
               parent.syncCoordinator?.isEditorToPreviewSyncEnabled == true {
                syncCursorToPreview(textView)
            }
        }

        private func syncCursorToPreview(_ textView: UITextView) {
            guard let syncCoordinator = parent.syncCoordinator,
                  let sourceMap = parent.sourceMap,
                  !sourceMap.isEmpty else { return }
            guard syncCoordinator.beginSync(.editorToPreview) else { return }

            let cursorLocation = textView.selectedRange.location
            let text = textView.text as NSString
            // Count newlines up to cursor to get 1-based line number.
            let prefix = cursorLocation <= text.length
                ? text.substring(to: cursorLocation)
                : textView.text ?? ""
            let line = prefix.components(separatedBy: "\n").count

            if let target = sourceMap.pdfPosition(forLine: line) {
                syncCoordinator.previewScrollTarget = PreviewScrollTarget(
                    page: target.page,
                    yPoints: target.yPoints,
                    xPoints: target.xPoints
                )
            }
            syncCoordinator.endSync()
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            // Only dismiss on user-initiated scrolls (drag/momentum), not on auto-scroll from typing
            guard scrollView.isDragging || scrollView.isDecelerating else { return }
            guard let typstTextView = scrollView as? TypstTextView else { return }
            captureViewState(from: typstTextView)
            typstTextView.dismissCompletion()
        }

        func captureViewState(from textView: TypstTextView) {
            let newState = EditorViewState(
                selectedLocation: textView.selectedRange.location,
                selectedLength: textView.selectedRange.length,
                contentOffset: textView.contentOffset
            )
            guard parent.viewState != newState else { return }
            parent.viewState = newState
        }

        func restoreViewStateIfNeeded(in textView: TypstTextView) {
            guard lastAppliedViewState != parent.viewState else { return }

            let utf16Count = textView.text.utf16.count
            let location = min(parent.viewState.selectedLocation, utf16Count)
            let length = min(parent.viewState.selectedLength, max(utf16Count - location, 0))
            let restoredRange = NSRange(location: location, length: length)

            if textView.selectedRange != restoredRange {
                textView.selectedRange = restoredRange
            }

            let targetOffset = parent.viewState.contentOffset
            if textView.contentOffset != targetOffset {
                // Defer content offset restoration until after layout computes content size.
                // Setting contentOffset before layout has no effect because the text view
                // hasn't measured its content yet after a text change.
                textView.setContentOffset(targetOffset, animated: false)
                DispatchQueue.main.async {
                    textView.setContentOffset(targetOffset, animated: false)
                }
            }

            lastAppliedViewState = parent.viewState
        }

        func lineNumber(forUTF16Offset offset: Int, in text: String) -> Int {
            let nsText = text as NSString
            let clampedOffset = min(max(offset, 0), nsText.length)
            let prefix = nsText.substring(to: clampedOffset)
            return prefix.components(separatedBy: "\n").count
        }
    }
}
