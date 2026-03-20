//
//  LocalPackageManagementView.swift
//  Typist
//

import SwiftUI
import UniformTypeIdentifiers

struct LocalPackageManagementView: View {
    @State private var snapshot = LocalPackageSnapshot(entries: [])
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingFolderImporter = false
    @State private var showingClearAllConfirmation = false
    @State private var importedSpec: String?

    private let store = LocalPackageStore()

    var body: some View {
        List {
            infoSection
            packagesSection
            actionsSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle(L10n.tr("local_packages.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingFolderImporter = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(L10n.tr("local_packages.import"))
            }
        }
        .task { await refresh() }
        .refreshable { await refresh() }
        .fileImporter(
            isPresented: $showingFolderImporter,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task { await importFolder(at: url) }
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
        .alert(L10n.tr("Error"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(L10n.tr("OK")) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .alert(
            L10n.tr("local_packages.imported"),
            isPresented: Binding(
                get: { importedSpec != nil },
                set: { if !$0 { importedSpec = nil } }
            )
        ) {
            Button(L10n.tr("OK")) { importedSpec = nil }
        } message: {
            if let spec = importedSpec {
                Text(L10n.format("local_packages.imported_message", spec))
            }
        }
        .alert(L10n.tr("local_packages.clear_all_title"), isPresented: $showingClearAllConfirmation) {
            Button(L10n.tr("Cancel"), role: .cancel) {}
            Button(L10n.tr("local_packages.clear_all_button"), role: .destructive) {
                Task { await clearAll() }
            }
        } message: {
            Text(L10n.tr("local_packages.clear_all_message"))
        }
    }

    private var infoSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label(L10n.tr("local_packages.info_title"), systemImage: "info.circle")
                    .font(.subheadline.weight(.medium))
                Text(L10n.tr("local_packages.info_body"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var packagesSection: some View {
        Section(L10n.tr("local_packages.section_title")) {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if snapshot.entries.isEmpty {
                Text(L10n.tr("local_packages.empty"))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(snapshot.entries) { entry in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.displayName)
                                .font(.body.weight(.medium))
                            Text(entry.version)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(formattedSize(entry.sizeInBytes))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(L10n.tr("Delete"), role: .destructive) {
                            Task { await delete(entry) }
                        }
                    }
                    .accessibilityLabel(entry.spec)
                    .accessibilityValue(formattedSize(entry.sizeInBytes))
                }
            }
        }
    }

    private var actionsSection: some View {
        Section {
            Button(L10n.tr("local_packages.clear_all_button"), role: .destructive) {
                showingClearAllConfirmation = true
            }
            .disabled(isLoading || snapshot.entries.isEmpty)
        }
    }

    private func refresh() async {
        isLoading = true
        do {
            let rootURL = store.rootURL
            let latestSnapshot = try await Task.detached(priority: .userInitiated) {
                try LocalPackageStore(rootURL: rootURL).snapshot()
            }.value
            snapshot = latestSnapshot
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func importFolder(at url: URL) async {
        do {
            let rootURL = store.rootURL
            let spec = try await Task.detached(priority: .userInitiated) {
                try LocalPackageStore(rootURL: rootURL).importFolder(at: url)
            }.value
            importedSpec = spec
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(_ entry: LocalPackageEntry) async {
        do {
            let rootURL = store.rootURL
            try await Task.detached(priority: .userInitiated) {
                try LocalPackageStore(rootURL: rootURL).remove(entry)
            }.value
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func clearAll() async {
        do {
            let rootURL = store.rootURL
            try await Task.detached(priority: .userInitiated) {
                try LocalPackageStore(rootURL: rootURL).clearAll()
            }.value
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func formattedSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
