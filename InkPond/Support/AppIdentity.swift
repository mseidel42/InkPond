//
//  AppIdentity.swift
//  InkPond
//

import Foundation

enum AppIdentity {
    /// Keep the existing iCloud container identifier so updates continue to see
    /// the same document store after the app rename.
    nonisolated static let iCloudContainerIdentifier = "iCloud.P0int.Typist"

    /// Move snippets into the new app support folder while still migrating the
    /// old location forward on first launch.
    nonisolated static let snippetStoreDirectoryName = "InkPond"
    nonisolated static let legacySnippetStoreDirectoryName = "Typist"
}
