//
//  DocumentListView.swift
//  InkPond
//

import SwiftUI
import SwiftData

struct DocumentListView: View {
    enum SortField: String, CaseIterable, Identifiable {
        case title
        case modifiedAt
        case createdAt

        var id: String { rawValue }

        var label: String {
            switch self {
            case .title: L10n.tr("sort.field.title")
            case .modifiedAt: L10n.tr("sort.field.modified")
            case .createdAt: L10n.tr("sort.field.created")
            }
        }
    }

    enum SortDirection: String, CaseIterable, Identifiable {
        case ascending
        case descending

        var id: String { rawValue }

        var label: String {
            switch self {
            case .ascending: L10n.tr("sort.direction.ascending")
            case .descending: L10n.tr("sort.direction.descending")
            }
        }

        func orders(_ comparison: ComparisonResult) -> Bool {
            switch self {
            case .ascending:
                comparison == .orderedAscending
            case .descending:
                comparison == .orderedDescending
            }
        }
    }

    @Environment(StorageManager.self) var storageManager
    @Environment(\.modelContext) var modelContext
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.scenePhase) var scenePhase
    @Query(sort: \InkPondDocument.modifiedAt, order: .reverse) var documents: [InkPondDocument]

    @Binding var selectedDocument: InkPondDocument?
    @Binding var searchText: String

    @State var renamingDocument: InkPondDocument?
    @State var newTitle: String = ""
    @State var exporter = ExportController()
    @State var documentToDelete: InkPondDocument?
    @State var showingSettings = false
    @State var projectActionError: String? = nil
    @State var zipImportError: String? = nil
    @State var monitor = DirectoryMonitor()
    @State var syncTask: Task<Void, Never>?
    @State var sortField: SortField = .modifiedAt
    @State var sortDirection: SortDirection = .descending
    @State var showingSortPopover = false
    @State var showingFolderImporter = false

    let rowDateFormat = Date.FormatStyle(date: .abbreviated, time: .shortened)

    var deduplicatedDocuments: [InkPondDocument] {
        Dictionary(grouping: documents, by: \.projectID)
            .values
            .map(preferredDocumentForDuplicateGroup)
    }

    var filteredDocuments: [InkPondDocument] {
        guard !searchText.isEmpty else { return deduplicatedDocuments }
        return deduplicatedDocuments.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var sortedDocuments: [InkPondDocument] {
        filteredDocuments.sorted(by: areDocumentsOrdered)
    }

    var isShowingSearchEmptyState: Bool {
        !searchText.isEmpty && sortedDocuments.isEmpty
    }

    var isShowingLibraryEmptyState: Bool {
        deduplicatedDocuments.isEmpty && searchText.isEmpty
    }

    var isIPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    var body: some View {
        documentList
            .searchable(text: $searchText, prompt: "Search")
            .navigationTitle(L10n.appName)
            .toolbar { if isIPad { iPadToolbar } else { iPhoneToolbar } }
            .overlay {
                if exporter.isExporting {
                    ZStack {
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .ignoresSafeArea()
                        ProgressView("Compiling…")
                            .padding()
                            .systemFloatingSurface(cornerRadius: 12)
                    }
                }
            }
            .sheet(item: $exporter.exportURL) { ActivityView(activityItems: [$0]) }
            .onChange(of: exporter.exportURL) { _, newValue in
                guard newValue != nil else { return }
                InteractionFeedback.notify(.success)
                AccessibilitySupport.announce(L10n.a11yExportReady)
            }
            .onChange(of: exporter.exportError) { _, newValue in
                guard newValue != nil else { return }
                InteractionFeedback.notify(.error)
                AccessibilitySupport.announce(newValue)
            }
            .alert("Export Error", isPresented: Binding(
                get: { exporter.exportError != nil },
                set: { if !$0 { exporter.exportError = nil } }
            )) {
                Button("OK") { exporter.exportError = nil }
            } message: {
                Text(exporter.exportError ?? "")
            }
            .alert("Rename Document", isPresented: Binding(
                get: { renamingDocument != nil },
                set: { if !$0 { renamingDocument = nil } }
            )) {
                TextField("Title", text: $newTitle)
                Button("Rename") {
                    if let doc = renamingDocument {
                        do {
                            let oldProjectID = doc.projectID
                            let newFolderName = try ProjectFileManager.renameProjectDirectory(for: doc, to: newTitle)
                            try? CompiledPreviewCacheStore().moveCache(
                                from: oldProjectID,
                                to: newFolderName,
                                documentTitle: newTitle
                            )
                            doc.projectID = newFolderName
                            doc.title = newTitle
                            doc.modifiedAt = Date()
                        } catch {
                            projectActionError = error.localizedDescription
                        }
                    }
                    renamingDocument = nil
                }
                Button("Cancel", role: .cancel) { renamingDocument = nil }
            }
            .alert("Delete Document", isPresented: Binding(
                get: { documentToDelete != nil },
                set: { if !$0 { documentToDelete = nil } }
            )) {
                Button("Delete", role: .destructive) {
                    if let doc = documentToDelete {
                        do {
                            try ProjectFileManager.deleteProjectDirectory(for: doc)
                            try? CompiledPreviewCacheStore().remove(projectID: doc.projectID)
                            if selectedDocument == doc { selectedDocument = nil }
                            modelContext.delete(doc)
                        } catch {
                            projectActionError = error.localizedDescription
                        }
                        documentToDelete = nil
                    }
                }
                Button("Cancel", role: .cancel) { documentToDelete = nil }
            } message: {
                if let doc = documentToDelete {
                    Text(L10n.deleteDocumentMessage(title: doc.title))
                }
            }
            .alert("Project Error", isPresented: Binding(
                get: { projectActionError != nil },
                set: { if !$0 { projectActionError = nil } }
            )) {
                Button("OK") { projectActionError = nil }
            } message: {
                Text(projectActionError ?? "")
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(onImport: { url in importZip(from: url) })
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { scheduleFilesystemSync(delay: .milliseconds(100)) }
            }
            .onChange(of: selectedDocument?.persistentModelID) { _, newValue in
                guard newValue != nil else { return }
                InteractionFeedback.selection()
            }
            .alert("Import Error", isPresented: Binding(
                get: { zipImportError != nil },
                set: { if !$0 { zipImportError = nil } }
            )) {
                Button("OK") { zipImportError = nil }
            } message: {
                Text(zipImportError ?? "")
            }
            .onChange(of: projectActionError) { _, newValue in
                guard newValue != nil else { return }
                InteractionFeedback.notify(.error)
                AccessibilitySupport.announce(newValue)
            }
            .onChange(of: zipImportError) { _, newValue in
                guard newValue != nil else { return }
                InteractionFeedback.notify(.error)
                AccessibilitySupport.announce(newValue)
            }
            .fileImporter(isPresented: $showingFolderImporter, allowedContentTypes: [.folder]) { result in
                switch result {
                case .success(let url):
                    linkExternalFolder(from: url)
                case .failure(let error):
                    zipImportError = error.localizedDescription
                }
            }
    }
}
