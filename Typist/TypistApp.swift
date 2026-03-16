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
    private let sharedModelContainer: ModelContainer? = {
        let schema = Schema([
            TypistDocument.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        return try? ModelContainer(for: schema, configurations: [modelConfiguration])
    }()

    var body: some Scene {
        WindowGroup {
            if let container = sharedModelContainer {
                ContentView()
                    .modelContainer(container)
                    .task {
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
