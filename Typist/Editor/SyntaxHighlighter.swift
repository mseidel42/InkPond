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
    }

    private var rules: [Rule] = []

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
        // (pattern, options, colorKeyPath, bold, italic)
        // Rules applied in order; later rules override earlier ones.
        let specs: [(String, NSRegularExpression.Options, (EditorTheme) -> UIColor, Bool, Bool)] = [
            // 1. Bold *...* / Italic _..._
            (#"\*[^*\n]+\*|_[^_\n]+_"#,                         [],                   { $0.markup },   false, false),
            // 2. Numbers with optional units (% separated to avoid \b mismatch)
            (#"\b\d+(?:\.\d+)?(?:em|pt|cm|mm|in|px|fr|deg|rad|sp)\b|\b\d+(?:\.\d+)?%|\b\d+(?:\.\d+)?\b"#, [],
                                                                                       { $0.number },   false, false),
            // 3. Math $...$
            (#"\$[^$\n]+\$"#,                                    [],                   { $0.math },     false, false),
            // 4. Code block ```...```
            (#"```[\s\S]*?```"#,                                 [],                   { $0.code },     false, false),
            // 5. Inline code `...`
            (#"`[^`\n]*`"#,                                      [],                   { $0.code },     false, false),
            // 6. Label <...> / Ref @... (supports fig:my-label, bib.key, etc.)
            (#"<[a-zA-Z][a-zA-Z0-9_.\-:]*>|@[a-zA-Z_][a-zA-Z0-9_.\-:]*"#, [],        { $0.label },    false, false),
            // 7. Bare keywords (in markup context)
            (#"\b(?:else|in|and|or|not|with|as)\b"#,            [],                   { $0.keyword },  true,  false),
            // 8. Bare bool/none/auto literals
            (#"\b(?:true|false|none|auto)\b"#,                   [],                   { $0.bool },     false, false),
            // 9. Functions #name (general)
            (#"#[a-zA-Z_][a-zA-Z0-9_-]*"#,                      [],                   { $0.functionColor }, false, false),
            // 10. #bool — overrides function color
            (#"#(?:true|false|none|auto)\b"#,                    [],                   { $0.bool },     false, false),
            // 11. #keyword — bold
            (#"#(?:let|if|else|for|while|import|include|show|set|return|break|continue|and|or|not|in|with|as)\b"#,
                                                                  [],                   { $0.keyword },  true,  false),
            // 12. Headings ^={1,6}...
            (#"^={1,6}[^\n]*"#,                                  .anchorsMatchLines,   { $0.heading },  true,  false),
            // 13. Strings "..." (overrides tokens inside)
            (#"\"(?:[^\"\\]|\\.)*\""#,                           [],                   { $0.string },   false, false),
            // 14. Block comments /* ... */
            (#"/\*[\s\S]*?\*/"#,                                 [],                   { $0.comment },  false, true),
            // 15. Line comments //...
            (#"//[^\n]*"#,                                        .anchorsMatchLines,   { $0.comment },  false, true),
        ]

        rules = specs.compactMap { pattern, options, colorFn, bold, italic in
            guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
            return Rule(regex: regex, color: colorFn, bold: bold, italic: italic)
        }
    }

    // MARK: - Highlight

    func highlight(_ textStorage: NSTextStorage) {
        let fullRange = NSRange(location: 0, length: textStorage.length)

        let boldFont = UIFont.monospacedSystemFont(ofSize: baseFont.pointSize, weight: .semibold)
        let italicDescriptor = baseFont.fontDescriptor.withSymbolicTraits(.traitItalic)
        let italicFont = italicDescriptor.map { UIFont(descriptor: $0, size: baseFont.pointSize) } ?? baseFont

        textStorage.beginEditing()

        // Reset to base attributes
        textStorage.setAttributes([
            .font: baseFont,
            .foregroundColor: theme.text,
        ], range: fullRange)

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
            }
        }

        // Rainbow bracket pass (runs last, overrides all)
        applyRainbowBrackets(textStorage, fullRange: fullRange)

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
}
