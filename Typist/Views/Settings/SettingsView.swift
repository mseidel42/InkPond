//
//  SettingsView.swift
//  Typist
//

import SwiftUI
import SwiftData
import UIKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(AppFontLibrary.self) var appFontLibrary
    @Environment(AppAppearanceManager.self) var appAppearanceManager
    @Environment(ThemeManager.self) var themeManager
    @Environment(StorageManager.self) var storageManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss

    @State var showingZipImporter = false
    @State var zipImportError: String?
    @State private var cloudSyncMonitor = CloudSyncMonitor()

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
                iCloudSection
                appearanceSection
                keyboardShortcutsSection
                projectsSection
                fontsSection
                cacheSection
                aboutSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle(L10n.tr("Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("Done")) {
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
            .alert(L10n.tr("Import Error"), isPresented: Binding(
                get: { zipImportError != nil },
                set: { if !$0 { zipImportError = nil } }
            )) {
                Button(L10n.tr("OK")) { zipImportError = nil }
            } message: {
                Text(zipImportError ?? "")
            }
            .onAppear {
                storageManager.refreshICloudAvailability()
                if storageManager.isUsingiCloud {
                    cloudSyncMonitor.startMonitoringAll()
                }
            }
            .onChange(of: storageManager.mode) { _, newMode in
                if newMode == .iCloud {
                    cloudSyncMonitor.startMonitoringAll()
                } else {
                    cloudSyncMonitor.stopMonitoring()
                }
            }
            .onDisappear {
                cloudSyncMonitor.stopMonitoring()
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
                Text(L10n.appName)
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

    var iCloudSection: some View {
        Section {
            if storageManager.isMigrating {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        ProgressView()
                        Text(L10n.tr("icloud.migrating"))
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: storageManager.migrationProgress)
                        .tint(.accentColor)
                }
            } else {
                Toggle(isOn: Binding(
                    get: { storageManager.mode == .iCloud },
                    set: { newValue in
                        let targetMode: StorageMode = newValue ? .iCloud : .local
                        let descriptor = FetchDescriptor<TypistDocument>()
                        let documents = (try? modelContext.fetch(descriptor)) ?? []
                        Task {
                            await storageManager.setMode(targetMode, documents: documents)
                        }
                    }
                )) {
                    Label(L10n.tr("icloud.sync_toggle"), systemImage: "icloud")
                }
                .disabled(!storageManager.iCloudAvailable && storageManager.mode != .iCloud)
            }

            if let error = storageManager.migrationError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if storageManager.mode == .iCloud {
                iCloudSyncStatusRow

                HStack(spacing: 10) {
                    Image(systemName: "lightbulb.min")
                        .foregroundStyle(.orange)
                    Text(L10n.tr("icloud.keep_downloaded_tip"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
        } header: {
            Text(L10n.tr("icloud.title"))
        } footer: {
            Text(storageManager.mode == .iCloud
                 ? L10n.tr("icloud.sync_footer.on")
                 : L10n.tr("icloud.sync_footer.off"))
        }
    }

    @ViewBuilder
    var iCloudSyncStatusRow: some View {
        let summary = cloudSyncMonitor.summary
        let lightColor = syncLightColor(for: summary)

        Label {
            HStack {
                syncStatusText(for: summary)
                Spacer()
                if cloudSyncMonitor.isGathering || summary.hasActivity {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
        } icon: {
            Circle()
                .fill(lightColor)
                .frame(width: 10, height: 10)
                .shadow(color: lightColor.opacity(0.5), radius: 3)
        }
    }

    private func syncLightColor(for summary: CloudSyncMonitor.SyncSummary) -> Color {
        if cloudSyncMonitor.isGathering { return .yellow }
        if summary.errored > 0 { return .red }
        if summary.hasActivity || summary.notDownloaded > 0 { return .yellow }
        if summary.total == 0 { return .secondary }
        return .green
    }

    private func syncStatusText(for summary: CloudSyncMonitor.SyncSummary) -> some View {
        Group {
            if cloudSyncMonitor.isGathering {
                Text(L10n.tr("icloud.status.checking"))
            } else if summary.errored > 0 {
                Text(L10n.format("icloud.status.error", summary.errored))
            } else if summary.hasActivity {
                if summary.downloading > 0 && summary.uploading > 0 {
                    Text(L10n.format("icloud.status.syncing", summary.downloading + summary.uploading))
                } else if summary.downloading > 0 {
                    Text(L10n.format("icloud.status.downloading", summary.downloading))
                } else {
                    Text(L10n.format("icloud.status.uploading", summary.uploading))
                }
            } else if summary.notDownloaded > 0 {
                Text(L10n.format("icloud.status.not_downloaded", summary.notDownloaded))
            } else if summary.total == 0 {
                Text(L10n.tr("icloud.status.no_files"))
            } else {
                Text(L10n.format("icloud.status.synced", summary.total))
            }
        }
        .foregroundStyle(.secondary)
    }

    var appearanceSection: some View {
        Section(L10n.tr("Appearance")) {
            Picker(selection: Binding(
                get: { appAppearanceManager.mode },
                set: { newMode in
                    withTransaction(Transaction(animation: nil)) {
                        appAppearanceManager.mode = newMode
                    }
                }
            )) {
                Text(L10n.tr("Follow System")).tag(AppAppearanceMode.system.rawValue)
                Text(L10n.tr("Light")).tag(AppAppearanceMode.light.rawValue)
                Text(L10n.tr("Dark")).tag(AppAppearanceMode.dark.rawValue)
            } label: {
                Label(L10n.tr("App Appearance"), systemImage: "circle.lefthalf.filled")
            }

            Picker(selection: Binding(
                get: { themeManager.themeID },
                set: { newID in
                    withTransaction(Transaction(animation: nil)) {
                        themeManager.themeID = newID
                    }
                }
            )) {
                Text(L10n.tr("Auto")).tag("system")
                Text(L10n.tr("Mocha · Dark")).tag("mocha")
                Text(L10n.tr("Latte · Light")).tag("latte")
            } label: {
                Label(L10n.tr("Editor Theme"), systemImage: "paintpalette")
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
        Section(L10n.tr("Projects")) {
            Button {
                showingZipImporter = true
            } label: {
                Label(L10n.tr("Import ZIP"), systemImage: "square.and.arrow.down")
                    .foregroundStyle(.primary)
            }
            .accessibilityIdentifier("settings.import-zip")
        }
    }

    var fontsSection: some View {
        Section(L10n.tr("Fonts")) {
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
        Section(L10n.tr("Cache")) {
            NavigationLink {
                CompiledPreviewCacheManagementView()
            } label: {
                Label(L10n.tr("Manage Compile Cache"), systemImage: "doc.text.magnifyingglass")
                    .foregroundStyle(.primary)
            }
            .accessibilityIdentifier("settings.compile-cache")

            NavigationLink {
                PreviewPackageCacheManagementView()
            } label: {
                Label(L10n.tr("Manage Package Cache"), systemImage: "externaldrive.badge.person.crop")
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
                Label(L10n.tr("Acknowledgements"), systemImage: "heart")
                    .foregroundStyle(.primary)
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
