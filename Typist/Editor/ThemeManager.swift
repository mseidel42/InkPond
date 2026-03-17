//
//  ThemeManager.swift
//  Typist
//

import Observation
import Foundation

@Observable
final class ThemeManager {
    private static let defaultsKey = "editorThemeID"
    private let defaults: UserDefaults

    var themeID: String {
        didSet { defaults.set(themeID, forKey: Self.defaultsKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        themeID = defaults.string(forKey: Self.defaultsKey) ?? "system"
    }

    var currentTheme: EditorTheme {
        switch themeID {
        case "mocha": return .mocha
        case "latte": return .latte
        default:      return .system
        }
    }
}
