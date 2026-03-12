//
//  SyntaxHighlighter.swift
//  Typist
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

    /// Lines (1-based) with compilation errors — set externally.
    var errorLines: Set<Int> = []

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

        let boldFont = UIFont.monospacedSystemFont(ofSize: baseFont.pointSize, weight: .semibold)
        let italicDescriptor = baseFont.fontDescriptor.withSymbolicTraits(.traitItalic)
        let italicFont = italicDescriptor.map { UIFont(descriptor: $0, size: baseFont.pointSize) } ?? baseFont

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
        let text = textStorage.string
        let lines = text.components(separatedBy: "\n")
        var offset = 0
        let errorBg = UIColor.systemRed.withAlphaComponent(0.08)
        let errorUnderline: [NSAttributedString.Key: Any] = [
            .underlineStyle: NSUnderlineStyle.single.rawValue | NSUnderlineStyle.patternDot.rawValue,
            .underlineColor: UIColor.systemRed,
            .backgroundColor: errorBg,
        ]

        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let lineLength = (line as NSString).length
            if errorLines.contains(lineNumber), lineLength > 0 {
                // Underline non-whitespace portion of the line
                let trimmedStart = line.utf16.firstIndex(where: { !CharacterSet.whitespaces.contains(Unicode.Scalar($0)!) })
                let nsStart = trimmedStart.map { line.utf16.distance(from: line.utf16.startIndex, to: $0) } ?? 0
                let errorRange = NSRange(location: offset + nsStart, length: lineLength - nsStart)
                textStorage.addAttributes(errorUnderline, range: errorRange)
            }
            offset += lineLength + 1 // +1 for \n
        }
    }
}
