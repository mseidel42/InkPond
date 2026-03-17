//
//  TypistApp.swift
//  Typist
//
//  Created by Lin Qidi on 2026/3/2.
//

import SwiftUI
import SwiftData

@main
struct TypistApp: App {
    @State private var storageManager = StorageManager()

    private let sharedModelContainer: ModelContainer? = {
        let processInfo = ProcessInfo.processInfo
        let useInMemoryStore = processInfo.arguments.contains("UITEST_IN_MEMORY_STORE")
            || processInfo.environment["UITEST_IN_MEMORY_STORE"] == "1"
        let schema = Schema([
            TypistDocument.self,
        ])

        let storedMode = UserDefaults.standard.string(forKey: "storageMode") ?? StorageMode.local.rawValue
        let iCloudEnabled = storedMode == StorageMode.iCloud.rawValue

        let modelConfiguration: ModelConfiguration
        if useInMemoryStore {
            modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else {
            modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: iCloudEnabled ? .automatic : .none
            )
        }

        return try? ModelContainer(for: schema, configurations: [modelConfiguration])
    }()

    @State private var snippetStore = SnippetStore()

    var body: some Scene {
        WindowGroup {
            if let container = sharedModelContainer {
                ContentView()
                    .modelContainer(container)
                    .environment(snippetStore)
                    .environment(storageManager)
                    .task {
                        ProjectFileManager.storageManager = storageManager
                        ExportManager.cleanupTemporaryExports()
                        FontManager.pruneRegistrationCache()
                    }
            } else {
                DataStoreErrorView()
            }
        }
    }
}

/// Shown when the SwiftData store cannot be opened.
private struct DataStoreErrorView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(L10n.tr("error.datastore.title"))
                .font(.title2.bold())
            Text(L10n.tr("error.datastore.message"))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
}
