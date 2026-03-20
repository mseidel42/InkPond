//
//  StorageSyncPreferences.swift
//  Typist
//

import Foundation

enum StorageSyncPreferences {
    nonisolated static let storageModeKey = "storageMode"
    nonisolated static let syncFontsKey = "syncAppFontsInICloud"
    nonisolated static let syncPackagesKey = "syncLocalPackagesInICloud"

    nonisolated static var syncProjects: Bool {
        UserDefaults.standard.string(forKey: storageModeKey) == StorageMode.iCloud.rawValue
    }

    nonisolated static var fontPreferenceEnabled: Bool {
        bool(forKey: syncFontsKey, default: true)
    }

    nonisolated static var packagePreferenceEnabled: Bool {
        bool(forKey: syncPackagesKey, default: false)
    }

    nonisolated static var syncFonts: Bool {
        syncProjects && fontPreferenceEnabled
    }

    nonisolated static var syncPackages: Bool {
        syncProjects && packagePreferenceEnabled
    }

    nonisolated private static func bool(forKey key: String, default defaultValue: Bool) -> Bool {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: key) != nil else { return defaultValue }
        return defaults.bool(forKey: key)
    }
}
