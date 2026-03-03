//
//  AutoPairEngine.swift
//  Typist
//

import UIKit

struct AutoPairEngine {

    private static let pairs: [(open: String, close: String)] = [
        ("{", "}"),
        ("[", "]"),
        ("(", ")"),
        ("\"", "\""),
        ("$", "$"),
    ]

    private static let openToClose: [String: String] = Dictionary(uniqueKeysWithValues: pairs.map { ($0.open, $0.close) })
    private static let closeChars: Set<String> = Set(pairs.map { $0.close })
    private static let bracketOpens: Set<String> = ["{", "["]

    // MARK: - Insert Text

    /// Returns replacement text and cursor offset from start of replacement, or nil to use default behavior.
    static func handleInsert(_ text: String, in textView: UITextView) -> Bool {
        let storage = textView.textStorage
        let selectedRange = textView.selectedRange
        let nsString = storage.string as NSString

        // Handle Enter key — auto-indent
        if text == "\n" {
            return handleNewline(in: textView, storage: storage, selectedRange: selectedRange, nsString: nsString)
        }

        // Only handle single-character inserts for pairing
        guard text.count == 1 else { return false }

        let cursorLocation = selectedRange.location

        // Type-over: if typing a closing char and next char matches, just move cursor
        if closeChars.contains(text),
           cursorLocation < nsString.length {
            let nextChar = nsString.substring(with: NSRange(location: cursorLocation, length: 1))
            if nextChar == text {
                textView.selectedRange = NSRange(location: cursorLocation + 1, length: 0)
                return true
            }
        }

        // Auto-close: if typing an opening char, insert the pair
        if let close = openToClose[text] {
            // For quotes and $, only auto-close if not already adjacent to same char
            if text == "\"" || text == "$" {
                if cursorLocation > 0 {
                    let prevChar = nsString.substring(with: NSRange(location: cursorLocation - 1, length: 1))
                    if prevChar == text { return false }
                }
                if cursorLocation < nsString.length {
                    let nextChar = nsString.substring(with: NSRange(location: cursorLocation, length: 1))
                    if nextChar == text { return false }
                }
            }

            let pair = text + close
            storage.replaceCharacters(in: selectedRange, with: pair)
            textView.selectedRange = NSRange(location: cursorLocation + 1, length: 0)
            return true
        }

        return false
    }

    // MARK: - Delete Backward

    /// Returns true if handled (deleted both chars of an empty pair).
    static func handleDelete(in textView: UITextView) -> Bool {
        let storage = textView.textStorage
        let selectedRange = textView.selectedRange
        let nsString = storage.string as NSString

        let cursor = selectedRange.location
        guard selectedRange.length == 0, cursor > 0, cursor < nsString.length else { return false }

        let prevChar = nsString.substring(with: NSRange(location: cursor - 1, length: 1))
        let nextChar = nsString.substring(with: NSRange(location: cursor, length: 1))

        if let close = openToClose[prevChar], close == nextChar {
            storage.replaceCharacters(in: NSRange(location: cursor - 1, length: 2), with: "")
            textView.selectedRange = NSRange(location: cursor - 1, length: 0)
            return true
        }

        return false
    }

    // MARK: - Newline / Auto-indent

    private static func handleNewline(in textView: UITextView, storage: NSTextStorage, selectedRange: NSRange, nsString: NSString) -> Bool {
        let cursor = selectedRange.location

        // Find current line's leading whitespace
        let lineRange = nsString.lineRange(for: NSRange(location: cursor, length: 0))
        let lineText = nsString.substring(with: lineRange)
        let leadingWhitespace = String(lineText.prefix(while: { $0 == " " || $0 == "\t" }))

        // Check if char before cursor is a bracket opener
        let charBefore = cursor > 0 ? nsString.substring(with: NSRange(location: cursor - 1, length: 1)) : ""
        let charAfter = cursor < nsString.length ? nsString.substring(with: NSRange(location: cursor, length: 1)) : ""

        if bracketOpens.contains(charBefore) {
            let indent = leadingWhitespace + "    "
            var insertion = "\n" + indent
            // If the matching close bracket is right after cursor, put it on a new line
            let expectedClose = charBefore == "{" ? "}" : "]"
            if charAfter == expectedClose {
                insertion += "\n" + leadingWhitespace
            }
            storage.replaceCharacters(in: selectedRange, with: insertion)
            textView.selectedRange = NSRange(location: cursor + 1 + indent.count, length: 0)
            return true
        }

        // Default: just preserve indentation
        if !leadingWhitespace.isEmpty {
            let insertion = "\n" + leadingWhitespace
            storage.replaceCharacters(in: selectedRange, with: insertion)
            textView.selectedRange = NSRange(location: cursor + insertion.count, length: 0)
            return true
        }

        return false
    }
}
