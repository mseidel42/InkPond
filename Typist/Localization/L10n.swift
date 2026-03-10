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

    nonisolated static func imageInserted(path: String) -> String {
        format("toast.image_inserted.single", path)
    }

    nonisolated static func imagesInserted(count: Int) -> String {
        format("toast.image_inserted.multiple", count)
    }

    nonisolated static var appFontsTitle: String { tr("app_fonts.title") }
    nonisolated static var projectFontsTitle: String { tr("project_fonts.title") }
    nonisolated static var appFontsBuiltInOnlySummary: String { tr("app_fonts.summary.built_in_only") }
    nonisolated static func appFontsImportedSummary(count: Int) -> String {
        format("app_fonts.summary.imported", count)
    }
    nonisolated static var appFontsErrorTitle: String { tr("app_fonts.alert.error") }
    nonisolated static var appFontsOverviewTitle: String { tr("app_fonts.overview.title") }
    nonisolated static var appFontsOverviewDetail: String { tr("app_fonts.overview.detail") }
    nonisolated static var projectFontsFooter: String { tr("project_fonts.footer") }
    nonisolated static var noProjectFonts: String { tr("project_fonts.empty") }
    nonisolated static var fontScopeBuiltIn: String { tr("font.scope.built_in") }
    nonisolated static var fontScopeApp: String { tr("font.scope.app") }
    nonisolated static var fontScopeProject: String { tr("font.scope.project") }
    nonisolated static var appFontsExportWarningTitle: String { tr("app_fonts.export_warning.title") }
    nonisolated static var appFontsExportWarningMessage: String { tr("app_fonts.export_warning.message") }
}
