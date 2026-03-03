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
    init() {
        // Catppuccin-themed segmented control (adaptive dynamic UIColors)
        UISegmentedControl.appearance().backgroundColor = .catppuccinSurface0
        UISegmentedControl.appearance().selectedSegmentTintColor = .catppuccinBlue
        UISegmentedControl.appearance().setTitleTextAttributes(
            [.foregroundColor: UIColor.catppuccinText], for: .normal)
        UISegmentedControl.appearance().setTitleTextAttributes(
            [.foregroundColor: UIColor.white], for: .selected)
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            TypistDocument.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
