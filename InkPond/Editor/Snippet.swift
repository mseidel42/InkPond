//
//  Snippet.swift
//  InkPond
//

import Foundation

struct Snippet: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var category: String
    var body: String
    var keywords: [String]
    let isBuiltIn: Bool

    init(id: UUID = UUID(), title: String, category: String, body: String, keywords: [String] = [], isBuiltIn: Bool = false) {
        self.id = id
        self.title = title
        self.category = category
        self.body = body
        self.keywords = keywords
        self.isBuiltIn = isBuiltIn
    }

    /// Returns the body with `$0` removed, and the character offset where `$0` was.
    func bodyWithCursorOffset() -> (text: String, cursorOffset: Int?) {
        guard let range = body.range(of: "$0") else {
            return (body, nil)
        }
        let offset = body.distance(from: body.startIndex, to: range.lowerBound)
        var text = body
        text.removeSubrange(range)
        return (text, offset)
    }
}
