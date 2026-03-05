//
//  LineNumberGutterView.swift
//  Typist
//

import UIKit

final class LineNumberGutterView: UIView {

    private static let gutterFont = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
    private static let minGutterWidth: CGFloat = 36

    private weak var textView: UITextView?
    private var gutterBgColor: UIColor = .secondarySystemBackground
    private var gutterFgColor: UIColor = .secondaryLabel

    init(textView: UITextView) {
        self.textView = textView
        super.init(frame: .zero)
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }

    func applyTheme(_ theme: EditorTheme) {
        gutterBgColor = theme.gutterBackground
        gutterFgColor = theme.gutterForeground
        setNeedsDisplay()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var gutterWidth: CGFloat {
        guard let textView else { return Self.minGutterWidth }
        let lineCount = max((textView.text as NSString).components(separatedBy: "\n").count, 1)
        let digits = String(lineCount).count
        let sampleString = String(repeating: "8", count: max(digits, 2)) as NSString
        let size = sampleString.size(withAttributes: [.font: Self.gutterFont])
        return max(ceil(size.width) + 16, Self.minGutterWidth)
    }

    override func draw(_ rect: CGRect) {
        guard let textView else { return }

        // Resolve dynamic UIColors against the current trait collection before converting to CGColor.
        let resolvedBg = gutterBgColor.resolvedColor(with: traitCollection)
        let resolvedFg = gutterFgColor.resolvedColor(with: traitCollection)

        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(resolvedBg.cgColor)
        context?.fill(CGRect(x: 0, y: 0, width: gutterWidth, height: bounds.height))

        let attributes: [NSAttributedString.Key: Any] = [
            .font: Self.gutterFont,
            .foregroundColor: resolvedFg,
        ]

        let layoutManager = textView.layoutManager
        let textContainer = textView.textContainer
        let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: textView.bounds, in: textContainer)
        let visibleCharRange = layoutManager.characterRange(forGlyphRange: visibleGlyphRange, actualGlyphRange: nil)

        let nsString = textView.text as NSString
        var lineNumber = 1
        // Count newlines before visible range to get starting line number
        let preText = nsString.substring(to: visibleCharRange.location)
        lineNumber += preText.components(separatedBy: "\n").count - 1

        func caretRectForOffset(_ offset: Int) -> CGRect? {
            let clampedOffset = min(max(offset, 0), nsString.length)
            guard let position = textView.position(from: textView.beginningOfDocument, offset: clampedOffset) else {
                return nil
            }
            return textView.caretRect(for: position)
        }

        var index = visibleCharRange.location
        while index <= NSMaxRange(visibleCharRange) {
            let charRange: NSRange
            if index < nsString.length {
                charRange = nsString.lineRange(for: NSRange(location: index, length: 0))
            } else if index == nsString.length {
                // Handle last empty line after trailing newline
                charRange = NSRange(location: index, length: 0)
            } else {
                break
            }

            let nextIndex = NSMaxRange(charRange)
            guard let startCaretRect = caretRectForOffset(index) else {
                break
            }
            let numberString = "\(lineNumber)" as NSString
            let stringSize = numberString.size(withAttributes: attributes)
            let drawPoint = CGPoint(
                x: gutterWidth - stringSize.width - 8,
                y: startCaretRect.minY + (max(startCaretRect.height, Self.gutterFont.lineHeight) - stringSize.height) / 2
            )
            numberString.draw(at: drawPoint, withAttributes: attributes)

            lineNumber += 1

            if nextIndex <= index {
                break
            }
            index = nextIndex
        }
    }
}
