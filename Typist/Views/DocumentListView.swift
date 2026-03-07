//
//  DocumentListView.swift
//  Typist
//

import SwiftUI
import SwiftData

struct DocumentListView: View {
    private enum SortOption: String, CaseIterable, Identifiable {
        case modifiedNewest
        case modifiedOldest
        case titleAZ
        case titleZA
        case createdNewest
        case createdOldest

        var id: String { rawValue }

        var label: String {
            switch self {
            case .modifiedNewest: L10n.tr("sort.modified_newest")
            case .modifiedOldest: L10n.tr("sort.modified_oldest")
            case .titleAZ: L10n.tr("sort.title_az")
            case .titleZA: L10n.tr("sort.title_za")
            case .createdNewest: L10n.tr("sort.created_newest")
            case .createdOldest: L10n.tr("sort.created_oldest")
            }
        }

        func areInIncreasingOrder(_ lhs: TypistDocument, _ rhs: TypistDocument) -> Bool {
            switch self {
            case .modifiedNewest:
                lhs.modifiedAt > rhs.modifiedAt
            case .modifiedOldest:
                lhs.modifiedAt < rhs.modifiedAt
            case .titleAZ:
                lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            case .titleZA:
                lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedDescending
            case .createdNewest:
                lhs.createdAt > rhs.createdAt
            case .createdOldest:
                lhs.createdAt < rhs.createdAt
            }
        }
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(ThemeManager.self) private var themeManager
    @Query(sort: \TypistDocument.modifiedAt, order: .reverse) private var documents: [TypistDocument]
    @Binding var selectedDocument: TypistDocument?
    @Binding var searchText: String
    @State private var renamingDocument: TypistDocument?
    @State private var newTitle: String = ""
    @State private var exporter = ExportController()
    @State private var documentToDelete: TypistDocument?
    @State private var showingSettings = false
    @State private var zipImportError: String? = nil
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @State private var monitor = DirectoryMonitor()
    @State private var syncTask: Task<Void, Never>?
    @State private var sortOption: SortOption = .modifiedNewest
    @State private var showingSortPopover = false
    private let rowDateFormat = Date.FormatStyle(date: .abbreviated, time: .shortened)

    private var filteredDocuments: [TypistDocument] {
        guard !searchText.isEmpty else { return documents }
        return documents.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    private var sortedDocuments: [TypistDocument] {
        filteredDocuments.sorted(by: sortOption.areInIncreasingOrder)
    }

    private var isShowingSearchEmptyState: Bool {
        !searchText.isEmpty && sortedDocuments.isEmpty
    }

    private var isShowingLibraryEmptyState: Bool {
        documents.isEmpty && searchText.isEmpty
    }

    private var isIPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    var body: some View {
        documentList
            .searchable(text: $searchText, prompt: "Search")
            .navigationTitle("Typist")
            .toolbar { if isIPad { iPadToolbar } else { iPhoneToolbar } }
            .overlay {
                if exporter.isExporting {
                    ZStack {
                        Color.catppuccinOverlayScrim.ignoresSafeArea()
                        ProgressView("Compiling…")
                            .padding()
                            .catppuccinFloatingSurface(cornerRadius: 12)
                    }
                }
            }
            .sheet(item: $exporter.exportURL) { ActivityView(activityItems: [$0]) }
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
                        let newFolderName = ProjectFileManager.renameProjectDirectory(for: doc, to: newTitle)
                        doc.projectID = newFolderName
                        doc.title = newTitle
                        doc.modifiedAt = Date()
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
                        if selectedDocument == doc { selectedDocument = nil }
                        ProjectFileManager.deleteProjectDirectory(for: doc)
                        modelContext.delete(doc)
                        documentToDelete = nil
                    }
                }
                Button("Cancel", role: .cancel) { documentToDelete = nil }
            } message: {
                if let doc = documentToDelete {
                    Text(L10n.deleteDocumentMessage(title: doc.title))
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(onImport: { url in importZip(from: url) })
                    .preferredColorScheme(themeManager.colorScheme)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { scheduleFilesystemSync(delay: .milliseconds(100)) }
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

    // MARK: - Subviews

    private var documentList: some View {
        List(selection: $selectedDocument) {
            ForEach(sortedDocuments) { document in
                documentRow(document)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.catppuccinBase)
        .overlay {
            if isShowingLibraryEmptyState {
                libraryEmptyState
            } else if isShowingSearchEmptyState {
                searchEmptyState
            }
        }
        .task {
            ProjectFileManager.migrateLegacyStructure(documents: documents)
            syncWithFilesystem()
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            monitor.onChange = { scheduleFilesystemSync() }
            monitor.start(url: docs)
        }
        .onDisappear {
            monitor.stop()
            syncTask?.cancel()
            syncTask = nil
        }
    }

    private func documentRow(_ document: TypistDocument) -> some View {
        let isSelected = selectedDocument === document

        return NavigationLink(value: document) {
            VStack(alignment: .leading, spacing: 4) {
                Text(document.title)
                    .font(.headline)
                    .foregroundStyle(isSelected ? Color.catppuccinBlue : Color.primary)
                    .lineLimit(1)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(L10n.tr("doc.time.created")): \(document.createdAt.formatted(rowDateFormat))")
                    Text("\(L10n.tr("doc.time.modified")): \(document.modifiedAt.formatted(rowDateFormat))")
                }
                .font(.caption)
                .foregroundStyle(Color.catppuccinSubtext1)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
        }
        .listRowBackground(
            ZStack {
                Color.catppuccinElevated
                if isSelected {
                    Color.catppuccinBlue.opacity(0.16)
                }
            }
        )
        .contextMenu {
            Button {
                renamingDocument = document
                newTitle = document.title
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            Divider()
            Button {
                exporter.exportPDF(for: document)
            } label: {
                Label("Share PDF", systemImage: "square.and.arrow.up")
            }
            Button {
                exporter.exportTypSource(for: document, fileName: document.entryFileName)
            } label: {
                Label("Export .typ", systemImage: "doc.text")
            }
            Divider()
            Button(role: .destructive) {
                documentToDelete = document
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var libraryEmptyState: some View {
        ContentUnavailableView {
            Label(L10n.tr("doc.list.empty.title"), systemImage: "folder")
        } description: {
            Text(L10n.tr("doc.list.empty.message"))
        }
    }

    private var searchEmptyState: some View {
        ContentUnavailableView.search(text: searchText)
    }

    private var toolbarButtonTint: Color {
        .catppuccinText
    }

    @ToolbarContentBuilder
    private var iPadToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button { showingSettings = true } label: {
                Image(systemName: "gearshape")
                    .scaleEffect(0.8)
            }
            .tint(toolbarButtonTint)
        }
        ToolbarItem(placement: .primaryAction) {
            sortMenu
        }
        ToolbarItem(placement: .primaryAction) {
            Button(action: addDocument) {
                Image(systemName: "folder.badge.plus")
                    .scaleEffect(0.8)
            }
            .tint(toolbarButtonTint)
        }
    }

    @ToolbarContentBuilder
    private var iPhoneToolbar: some ToolbarContent {
        ToolbarItem(placement: .bottomBar) {
            sortMenu
        }
        ToolbarSpacer(.flexible, placement: .bottomBar)
        DefaultToolbarItem(kind: .search, placement: .bottomBar)
        ToolbarSpacer(.flexible, placement: .bottomBar)
        ToolbarItem(placement: .bottomBar) {
            Button { showingSettings = true } label: {
                Image(systemName: "gearshape")
            }
            .tint(toolbarButtonTint)
        }
        ToolbarSpacer(.flexible, placement: .bottomBar)
        ToolbarItem(placement: .bottomBar) {
            Button(action: addDocument) { Image(systemName: "folder.badge.plus") }
                .tint(toolbarButtonTint)
        }
    }

    private var sortMenu: some View {
        Button { showingSortPopover = true } label: {
            Image(systemName: "arrow.up.arrow.down")
                .scaleEffect(0.8)
        }
        .buttonStyle(.plain)
        .tint(toolbarButtonTint)
        .popover(
            isPresented: $showingSortPopover,
            attachmentAnchor: .point(.bottom),
            arrowEdge: .top
        ) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(SortOption.allCases) { option in
                    Button {
                        sortOption = option
                        showingSortPopover = false
                    } label: {
                        HStack {
                            Text(option.label)
                                .font(.subheadline)
                            Spacer(minLength: 12)
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .opacity(option == sortOption ? 1 : 0)
                        }
                        .foregroundStyle(Color.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background {
                            if option == sortOption {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Color.catppuccinSurface0)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 4)
                }
            }
            .padding(10)
            .frame(minWidth: 188)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .presentationCompactAdaptation(.popover)
        }
    }

    // MARK: - Actions

    /// Coalesce bursty filesystem events into a single sync pass.
    private func scheduleFilesystemSync(delay: Duration = .milliseconds(300)) {
        syncTask?.cancel()
        syncTask = Task {
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                syncWithFilesystem()
            }
        }
    }

    private func syncWithFilesystem() {
        let existingFolders = ProjectFileManager.trackedFolderNames()

        for document in documents where !existingFolders.contains(document.projectID) {
            if selectedDocument == document {
                selectedDocument = nil
            }
            modelContext.delete(document)
        }

        let knownIDs = Set(documents.map { $0.projectID })
        let newFolders = ProjectFileManager.untrackedFolderNames(knownProjectIDs: knownIDs)
        for folderName in newFolders {
            let folderURL = ProjectFileManager.projectDirectory(folderName: folderName)
            let typFiles = ProjectFileManager.listAllTypFiles(in: folderURL)
            let doc = TypistDocument(title: folderName, content: "")
            doc.projectID = folderName
            let resolution = ProjectFileManager.resolveImportedEntryFile(from: typFiles)
            if let entryFile = resolution.entryFileName {
                doc.entryFileName = entryFile
            }
            doc.requiresInitialEntrySelection = resolution.requiresInitialSelection
            modelContext.insert(doc)
        }
    }

    private func nextAvailableTitle() -> String {
        let titles = Set(documents.map { $0.title })
        let base = L10n.untitledBase
        if !titles.contains(base) { return base }
        var i = 1
        while titles.contains(L10n.untitled(number: i)) { i += 1 }
        return L10n.untitled(number: i)
    }

    private func addDocument() {
        let title = nextAvailableTitle()
        let doc = TypistDocument(title: title, content: "")
        doc.projectID = ProjectFileManager.uniqueFolderName(for: title)
        modelContext.insert(doc)
        ProjectFileManager.ensureProjectStructure(for: doc)
        try? ProjectFileManager.writeTypFile(named: "main.typ", content: "", for: doc)
        selectedDocument = doc
    }

    private func importZip(from url: URL) {
        let title = url.deletingPathExtension().lastPathComponent
        let doc = TypistDocument(title: title, content: "")
        doc.projectID = ProjectFileManager.uniqueFolderName(for: title)
        modelContext.insert(doc)
        ProjectFileManager.ensureProjectStructure(for: doc)
        let destDir = ProjectFileManager.projectDirectory(for: doc)

        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        do {
            let extracted = try ZipImporter.extract(from: url, to: destDir)
            let typFiles = extracted.filter { $0.hasSuffix(".typ") }
            let resolution = ProjectFileManager.resolveImportedEntryFile(from: typFiles)
            if let entry = resolution.entryFileName {
                doc.entryFileName = entry
            }
            doc.requiresInitialEntrySelection = resolution.requiresInitialSelection
            selectedDocument = doc
        } catch {
            modelContext.delete(doc)
            ProjectFileManager.deleteProjectDirectory(for: doc)
            zipImportError = error.localizedDescription
        }
    }
}
