//
//  L10n.swift
//  Typist
//

import Foundation

enum L10n {
    nonisolated static func tr(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    nonisolated static func format(_ key: String, _ args: CVarArg...) -> String {
        String(format: tr(key), locale: Locale.current, arguments: args)
    }

    nonisolated static var appName: String { tr("app.name") }
    nonisolated static var untitledBase: String { tr("doc.untitled.base") }

    nonisolated static func untitled(number: Int) -> String {
        format("doc.untitled.numbered", number)
    }

    nonisolated static func deleteDocumentMessage(title: String) -> String {
        format("alert.delete_document.message", title)
    }
}
