//
//  SettingsView.swift
//  Typist
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(AppFontLibrary.self) var appFontLibrary
    @Environment(AppAppearanceManager.self) var appAppearanceManager
    @Environment(ThemeManager.self) var themeManager
    @Environment(\.dismiss) var dismiss

    @State var showingZipImporter = false
    @State var zipImportError: String?

    var onImport: (URL) -> Void

    var versionString: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return L10n.format("settings.version_format", v, b)
    }

    var typstVersionString: String? {
        guard let version = TypstBridge.runtimeVersion else { return nil }
        return L10n.format("settings.typst_version_format", version)
    }

    var body: some View {
        NavigationStack {
            List {
                headerSection
                appearanceSection
                keyboardShortcutsSection
                projectsSection
                fontsSection
                cacheSection
                aboutSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        InteractionFeedback.impact(.light)
                        dismiss()
                    }
                    .accessibilityIdentifier("settings.done")
                }
            }
            .fileImporter(isPresented: $showingZipImporter, allowedContentTypes: [.zip]) { result in
                switch result {
                case .success(let url):
                    onImport(url)
                    dismiss()
                case .failure(let error):
                    zipImportError = error.localizedDescription
                }
            }
            .alert("Import Error", isPresented: Binding(
                get: { zipImportError != nil },
                set: { if !$0 { zipImportError = nil } }
            )) {
                Button("OK") { zipImportError = nil }
            } message: {
                Text(zipImportError ?? "")
            }
        }
    }
}

extension SettingsView {
    var headerSection: some View {
        Section {
            VStack(spacing: 10) {
                appIconView
                    .frame(width: 88, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                    .accessibilityHidden(true)
                Text("Typist")
                    .font(.title2.bold())
                Text(versionString)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let typstVersionString {
                    Text(typstVersionString)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L10n.a11ySettingsHeaderLabel)
            .accessibilityValue(
                L10n.a11ySettingsHeaderValue(version: versionString, typstVersion: typstVersionString)
            )
        }
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    var appIconView: some View {
        if let icon = Bundle.main.appIcon {
            Image(uiImage: icon)
                .resizable()
                .scaledToFit()
        } else {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.accentColor)
                .overlay(
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.white)
                )
        }
    }

    var appearanceSection: some View {
        Section("Appearance") {
            Picker("App Appearance", selection: Binding(
                get: { appAppearanceManager.mode },
                set: { newMode in
                    withTransaction(Transaction(animation: nil)) {
                        appAppearanceManager.mode = newMode
                    }
                }
            )) {
                Text("Follow System").tag(AppAppearanceMode.system.rawValue)
                Text("Light").tag(AppAppearanceMode.light.rawValue)
                Text("Dark").tag(AppAppearanceMode.dark.rawValue)
            }

            Picker("Editor Theme", selection: Binding(
                get: { themeManager.themeID },
                set: { newID in
                    withTransaction(Transaction(animation: nil)) {
                        themeManager.themeID = newID
                    }
                }
            )) {
                Text("Auto").tag("system")
                Text("Mocha · Dark").tag("mocha")
                Text("Latte · Light").tag("latte")
            }
        }
    }

    var keyboardShortcutsSection: some View {
        Section {
            NavigationLink {
                KeyboardShortcutsView()
            } label: {
                Label(L10n.tr("shortcuts.title"), systemImage: "keyboard")
                    .foregroundStyle(.primary)
            }
            .accessibilityIdentifier("settings.keyboard-shortcuts")
        }
    }

    var projectsSection: some View {
        Section("Projects") {
            Button {
                showingZipImporter = true
            } label: {
                Label("Import ZIP", systemImage: "square.and.arrow.down")
                    .foregroundStyle(.primary)
            }
            .accessibilityIdentifier("settings.import-zip")
        }
    }

    var fontsSection: some View {
        Section("Fonts") {
            NavigationLink {
                AppFontManagementView()
            } label: {
                HStack {
                    Label(L10n.appFontsTitle, systemImage: "character.textbox")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(
                        appFontLibrary.isEmpty
                            ? L10n.appFontsBuiltInOnlySummary
                            : L10n.appFontsImportedSummary(count: appFontLibrary.fileNames.count)
                    )
                    .foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier("settings.fonts")
        }
    }

    var cacheSection: some View {
        Section("Cache") {
            NavigationLink {
                CompiledPreviewCacheManagementView()
            } label: {
                Label("Manage Compile Cache", systemImage: "doc.text.magnifyingglass")
                    .foregroundStyle(.primary)
            }
            .accessibilityIdentifier("settings.compile-cache")

            NavigationLink {
                PreviewPackageCacheManagementView()
            } label: {
                Label("Manage Package Cache", systemImage: "externaldrive.badge.person.crop")
                    .foregroundStyle(.primary)
            }
            .accessibilityIdentifier("settings.cache")
        }
    }

    var aboutSection: some View {
        Section {
            NavigationLink {
                AcknowledgementsView()
            } label: {
                Text("Acknowledgements")
            }
            .accessibilityIdentifier("settings.acknowledgements")
        }
    }
}

private extension Bundle {
    var appIcon: UIImage? {
        if let icons = infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let files = primary["CFBundleIconFiles"] as? [String],
           let name = files.last {
            return UIImage(named: name)
        }
        return UIImage(named: "AppIcon")
    }
}
