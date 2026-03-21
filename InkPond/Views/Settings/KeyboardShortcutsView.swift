//
//  KeyboardShortcutsView.swift
//  InkPond
//

import SwiftUI

struct KeyboardShortcutsView: View {
    var body: some View {
        List {
            Section(L10n.tr("shortcuts.section.general")) {
                shortcutRow(keys: "⌘F", description: L10n.tr("shortcuts.general.find_replace"))
            }

            Section(L10n.tr("shortcuts.section.completion")) {
                shortcutRow(keys: "↑ / ↓", description: L10n.tr("shortcuts.completion.navigate"))
                shortcutRow(keys: "Enter / Tab", description: L10n.tr("shortcuts.completion.confirm"))
                shortcutRow(keys: "Esc", description: L10n.tr("shortcuts.completion.dismiss"))
            }

            Section(L10n.tr("shortcuts.section.system")) {
                shortcutRow(keys: "⌘Z", description: L10n.tr("shortcuts.system.undo"))
                shortcutRow(keys: "⇧⌘Z", description: L10n.tr("shortcuts.system.redo"))
                shortcutRow(keys: "⌘A", description: L10n.tr("shortcuts.system.select_all"))
                shortcutRow(keys: "⌘C", description: L10n.tr("shortcuts.system.copy"))
                shortcutRow(keys: "⌘X", description: L10n.tr("shortcuts.system.cut"))
                shortcutRow(keys: "⌘V", description: L10n.tr("shortcuts.system.paste"))
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(L10n.tr("shortcuts.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func shortcutRow(keys: String, description: String) -> some View {
        HStack {
            Text(description)
            Spacer()
            Text(keys)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
