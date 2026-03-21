//
//  SyntaxHighlighter.swift
//  InkPond
//

import UIKit

final class SyntaxHighlighter {
    private let baseFont: UIFont
    private var theme: EditorTheme

    private struct Rule {
        let regex: NSRegularExpression
        let color: (EditorTheme) -> UIColor
        let bold: Bool
        let italic: Bool
        /// When true, brackets inside matched ranges are excluded from mismatch detection.
        let excludeFromBracketCheck: Bool
    }

    private var rules: [Rule] = []
    private lazy var boldFont = UIFont.monospacedSystemFont(ofSize: baseFont.pointSize, weight: .semibold)
    private lazy var italicFont: UIFont = {
        let descriptor = baseFont.fontDescriptor.withSymbolicTraits(.traitItalic)
        return descriptor.map { UIFont(descriptor: $0, size: baseFont.pointSize) } ?? baseFont
    }()

    /// Lines (1-based) with compilation errors — set externally.
    var errorLines: Set<Int> = []
    /// Line (1-based) to temporarily emphasize after a sync jump.
    var jumpHighlightLine: Int?
    /// Current emphasis strength for the jump highlight, normalized to 0...1.
    var jumpHighlightOpacity: CGFloat = 0

    init(font: UIFont = UIFont.monospacedSystemFont(ofSize: 15, weight: .regular),
         theme: EditorTheme = .system) {
        self.baseFont = font
        self.theme = theme
        buildRules()
    }

    func updateTheme(_ theme: EditorTheme) {
        self.theme = theme
    }

    // MARK: - Rule Construction

    private func buildRules() {
        // (pattern, options, colorKeyPath, bold, italic, excludeFromBracketCheck)
        // Rules applied in order; later rules override earlier ones.
        let specs: [(String, NSRegularExpression.Options, (EditorTheme) -> UIColor, Bool, Bool, Bool)] = [
            // 1. Bold *...* / Italic _..._
            (#"\*[^*\n]+\*|_[^_\n]+_"#,                         [],                   { $0.markup },   false, false, false),
            // 2. Numbers with optional units (% separated to avoid \b mismatch)
            (#"\b\d+(?:\.\d+)?(?:em|pt|cm|mm|in|px|fr|deg|rad|sp)\b|\b\d+(?:\.\d+)?%|\b\d+(?:\.\d+)?\b"#, [],
                                                                                       { $0.number },   false, false, false),
            // 3. Math $...$
            (#"\$[^$\n]+\$"#,                                    [],                   { $0.math },     false, false, true),
            // 4. Code block ```...```
            (#"```[\s\S]*?```"#,                                 [],                   { $0.code },     false, false, true),
            // 5. Inline code `...`
            (#"`[^`\n]*`"#,                                      [],                   { $0.code },     false, false, true),
            // 6. Label <...> / Ref @... (supports fig:my-label, bib.key, etc.)
            (#"<[a-zA-Z][a-zA-Z0-9_.\-:]*>|@[a-zA-Z_][a-zA-Z0-9_.\-:]*"#, [],        { $0.label },    false, false, false),
            // 7. Bare keywords (in markup context)
            (#"\b(?:else|in|and|or|not|with|as)\b"#,            [],                   { $0.keyword },  true,  false, false),
            // 8. Bare bool/none/auto literals
            (#"\b(?:true|false|none|auto)\b"#,                   [],                   { $0.bool },     false, false, false),
            // 9. Functions #name (general)
            (#"#[a-zA-Z_][a-zA-Z0-9_-]*"#,                      [],                   { $0.functionColor }, false, false, false),
            // 10. #bool — overrides function color
            (#"#(?:true|false|none|auto)\b"#,                    [],                   { $0.bool },     false, false, false),
            // 11. #keyword — bold
            (#"#(?:let|if|else|for|while|import|include|show|set|return|break|continue|and|or|not|in|with|as)\b"#,
                                                                  [],                   { $0.keyword },  true,  false, false),
            // 12. Headings ^={1,6}...
            (#"^={1,6}[^\n]*"#,                                  .anchorsMatchLines,   { $0.heading },  true,  false, false),
            // 13. Strings "..." (overrides tokens inside)
            (#"\"(?:[^\"\\]|\\.)*\""#,                           [],                   { $0.string },   false, false, true),
            // 14. Block comments /* ... */
            (#"/\*[\s\S]*?\*/"#,                                 [],                   { $0.comment },  false, true,  true),
            // 15. Line comments //...
            (#"//[^\n]*"#,                                        .anchorsMatchLines,   { $0.comment },  false, true,  true),
        ]

        rules = specs.compactMap { pattern, options, colorFn, bold, italic, exclude in
            guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
            return Rule(regex: regex, color: colorFn, bold: bold, italic: italic, excludeFromBracketCheck: exclude)
        }
    }

    // MARK: - Highlight

    func highlight(_ textStorage: NSTextStorage) {
        let fullRange = NSRange(location: 0, length: textStorage.length)

        textStorage.beginEditing()

        // Reset to base attributes — clear any previous error underlines too
        textStorage.setAttributes([
            .font: baseFont,
            .foregroundColor: theme.text,
        ], range: fullRange)

        // Collect ranges where brackets should be excluded from mismatch detection
        // (strings, comments, code blocks, math)
        var excludedOffsets = IndexSet()

        // Apply syntax rules
        for rule in rules {
            rule.regex.enumerateMatches(in: textStorage.string, range: fullRange) { match, _, _ in
                guard let range = match?.range else { return }
                textStorage.addAttribute(.foregroundColor, value: rule.color(theme), range: range)
                if rule.bold {
                    textStorage.addAttribute(.font, value: boldFont, range: range)
                } else if rule.italic {
                    textStorage.addAttribute(.font, value: italicFont, range: range)
                }
                if rule.excludeFromBracketCheck, range.length > 0 {
                    excludedOffsets.insert(integersIn: range.location..<(range.location + range.length))
                }
            }
        }

        // Rainbow bracket pass (runs last, overrides all)
        applyRainbowBrackets(textStorage, fullRange: fullRange)

        // Bracket mismatch detection (context-aware)
        applyBracketMismatchUnderlines(textStorage, excludedOffsets: excludedOffsets)

        // Compilation error line underlines
        applyErrorLineUnderlines(textStorage)
        applyJumpLineHighlight(textStorage)

        textStorage.endEditing()
    }

    // MARK: - Rainbow Brackets

    private func applyRainbowBrackets(_ textStorage: NSTextStorage, fullRange: NSRange) {
        let utf16 = textStorage.string.utf16
        let rainbow = theme.rainbow
        let count = rainbow.count
        var depth = 0

        for (i, unit) in utf16.enumerated() {
            switch unit {
            case 123, 40, 91:  // { ( [
                let color = rainbow[depth % count]
                textStorage.addAttribute(.foregroundColor, value: color,
                                         range: NSRange(location: i, length: 1))
                depth += 1
            case 125, 41, 93:  // } ) ]
                if depth > 0 { depth -= 1 }
                let color = rainbow[depth % count]
                textStorage.addAttribute(.foregroundColor, value: color,
                                         range: NSRange(location: i, length: 1))
            default:
                break
            }
        }
    }

    // MARK: - Bracket Mismatch Detection

    private func applyBracketMismatchUnderlines(_ textStorage: NSTextStorage, excludedOffsets: IndexSet) {
        let utf16 = textStorage.string.utf16
        // Stack stores (opening bracket UTF-16 unit, offset)
        var stack: [(UInt16, Int)] = []
        let errorAttrs: [NSAttributedString.Key: Any] = [
            .underlineStyle: NSUnderlineStyle.thick.rawValue,
            .underlineColor: UIColor.systemRed,
            .foregroundColor: UIColor.systemRed,
        ]

        for (i, unit) in utf16.enumerated() {
            guard !excludedOffsets.contains(i) else { continue }
            switch unit {
            case 123, 40, 91:  // { ( [
                stack.append((unit, i))
            case 125, 41, 93:  // } ) ]
                let expected: UInt16 = unit == 125 ? 123 : (unit == 41 ? 40 : 91)
                if let last = stack.last, last.0 == expected {
                    stack.removeLast()
                } else {
                    // Unmatched closing bracket
                    textStorage.addAttributes(errorAttrs, range: NSRange(location: i, length: 1))
                }
            default:
                break
            }
        }

        // Remaining are unmatched opening brackets
        for (_, offset) in stack {
            textStorage.addAttributes(errorAttrs, range: NSRange(location: offset, length: 1))
        }
    }

    // MARK: - Compilation Error Line Underlines

    private func applyErrorLineUnderlines(_ textStorage: NSTextStorage) {
        guard !errorLines.isEmpty else { return }
        let errorUnderline: [NSAttributedString.Key: Any] = [
            .underlineStyle: NSUnderlineStyle.single.rawValue | NSUnderlineStyle.patternDot.rawValue,
            .underlineColor: UIColor.systemRed,
            .backgroundColor: errorHighlightColor,
        ]

        enumerateLines(in: textStorage, targeting: errorLines) { info in
            if info.trimmedRange.length > 0 {
                textStorage.addAttributes(errorUnderline, range: info.trimmedRange)
            }
        }
    }

    private func applyJumpLineHighlight(_ textStorage: NSTextStorage) {
        guard let jumpHighlightLine, jumpHighlightOpacity > 0 else { return }

        enumerateLines(in: textStorage, targeting: [jumpHighlightLine]) { info in
            if info.range.length > 0 {
                textStorage.addAttribute(
                    .backgroundColor,
                    value: jumpHighlightColor(opacity: jumpHighlightOpacity),
                    range: info.range
                )
            }
        }
    }

    func refreshJumpHighlight(
        in textStorage: NSTextStorage,
        previousLine: Int?,
        line: Int?,
        opacity: CGFloat
    ) {
        let clampedOpacity = max(0, min(opacity, 1))
        let affectedLines = Set([previousLine, line].compactMap { $0 })
        jumpHighlightLine = line
        jumpHighlightOpacity = clampedOpacity

        guard !affectedLines.isEmpty else { return }

        textStorage.beginEditing()

        enumerateLines(in: textStorage, targeting: affectedLines) { info in
            if info.range.length > 0 {
                textStorage.removeAttribute(.backgroundColor, range: info.range)
            }
            if errorLines.contains(info.lineNumber), info.trimmedRange.length > 0 {
                textStorage.addAttribute(
                    .backgroundColor,
                    value: errorHighlightColor,
                    range: info.trimmedRange
                )
            }
            if info.lineNumber == line,
               clampedOpacity > 0,
               info.range.length > 0 {
                textStorage.addAttribute(
                    .backgroundColor,
                    value: jumpHighlightColor(opacity: clampedOpacity),
                    range: info.range
                )
            }
        }

        textStorage.endEditing()
    }

    private var errorHighlightColor: UIColor {
        UIColor.systemRed.withAlphaComponent(0.08)
    }

    private func jumpHighlightColor(opacity: CGFloat) -> UIColor {
        UIColor.systemBlue.withAlphaComponent(0.14 * opacity)
    }

    /// Iterate lines of `textStorage` using `NSString.lineRange`,
    /// calling `body` only for lines whose 1-based number is in `targetLines`.
    /// Stops early once all target lines have been visited.
    private func enumerateLines(
        in textStorage: NSTextStorage,
        targeting targetLines: Set<Int>,
        body: (LineInfo) -> Void
    ) {
        let nsText = textStorage.string as NSString
        let length = nsText.length
        var index = 0
        var lineNumber = 1
        var remaining = targetLines

        while index <= length, !remaining.isEmpty {
            let lineRange: NSRange
            if index < length {
                lineRange = nsText.lineRange(for: NSRange(location: index, length: 0))
            } else {
                // Handle trailing newline (empty last line)
                lineRange = NSRange(location: index, length: 0)
            }
            // Exclude the line terminator from the content range
            var contentEnd = NSMaxRange(lineRange)
            while contentEnd > lineRange.location,
                  contentEnd - 1 < length,
                  nsText.character(at: contentEnd - 1) == 10 /* \n */ || nsText.character(at: contentEnd - 1) == 13 /* \r */ {
                contentEnd -= 1
            }
            let contentRange = NSRange(location: lineRange.location, length: contentEnd - lineRange.location)

            if remaining.contains(lineNumber) {
                let firstNonWS = nsText.rangeOfCharacter(
                    from: CharacterSet.whitespaces.inverted,
                    range: contentRange
                ).location
                let trimmedStart = firstNonWS == NSNotFound ? contentRange.length : firstNonWS - contentRange.location

                body(LineInfo(
                    lineNumber: lineNumber,
                    range: contentRange,
                    trimmedRange: NSRange(
                        location: contentRange.location + trimmedStart,
                        length: max(0, contentRange.length - trimmedStart)
                    )
                ))
                remaining.remove(lineNumber)
            }

            let nextIndex = NSMaxRange(lineRange)
            if nextIndex <= index { break }
            index = nextIndex
            lineNumber += 1
        }
    }

    private struct LineInfo {
        let lineNumber: Int
        let range: NSRange
        let trimmedRange: NSRange
    }
}
