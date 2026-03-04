//
//  DocumentListView.swift
//  Typist
//

import SwiftUI
import SwiftData

struct DocumentListView: View {
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
    @State private var showingThemePicker = false

    private var filteredDocuments: [TypistDocument] {
        guard !searchText.isEmpty else { return documents }
        return documents.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    private var isIPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    var body: some View {
        documentList
            .searchable(text: $searchText, prompt: "Search documents")
            .navigationTitle("Typist")
            .toolbar { if isIPad { iPadToolbar } else { iPhoneToolbar } }
            .toolbarBackground(.visible, for: .navigationBar)
            .overlay {
                if exporter.isExporting {
                    ZStack {
                        Color.black.opacity(0.2).ignoresSafeArea()
                        ProgressView("Compiling…")
                            .padding()
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
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
                    renamingDocument?.title = newTitle
                    renamingDocument?.modifiedAt = Date()
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
                    Text("\"\(doc.title)\" will be permanently deleted.")
                }
            }
    }

    // MARK: - Subviews

    private var documentList: some View {
        List(selection: $selectedDocument) {
            ForEach(filteredDocuments) { document in
                documentRow(document)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.catppuccinMantle)
    }

    private func documentRow(_ document: TypistDocument) -> some View {
        NavigationLink(value: document) {
            VStack(alignment: .leading, spacing: 4) {
                Text(document.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(document.modifiedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(Color.catppuccinSubtext1)
            }
            .padding(.vertical, 2)
        }
        .listRowBackground(Color.catppuccinSurface0)
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

    @ToolbarContentBuilder
    private var iPadToolbar: some ToolbarContent {
        ToolbarItem() {
            Button {
                showingThemePicker = true
            } label: {
                Image(systemName: "paintpalette")
                    .scaleEffect(0.85)
            }
            .tint(themeManager.colorScheme == .light ? .black : .white)
            .popover(isPresented: $showingThemePicker) { themePickerPopover }
        }
        ToolbarItem(placement: .primaryAction) {
            Button(action: addDocument) {
                Image(systemName: "folder.badge.plus")
                    .scaleEffect(0.8)
            }
            .tint(themeManager.colorScheme == .light ? .black : .white)
        }
    }

    @ToolbarContentBuilder
    private var iPhoneToolbar: some ToolbarContent {
        ToolbarItem(placement: .bottomBar) {
            Button {
                showingThemePicker = true
            } label: {
                Image(systemName: "paintpalette")
            }
            .tint(themeManager.colorScheme == .light ? .black : nil)
            .popover(isPresented: $showingThemePicker) { themePickerPopover }
        }
        ToolbarSpacer(.flexible, placement: .bottomBar)
        DefaultToolbarItem(kind: .search, placement: .bottomBar)
        ToolbarSpacer(.flexible, placement: .bottomBar)
        ToolbarItem(placement: .bottomBar) {
            Button(action: addDocument) { Image(systemName: "folder.badge.plus") }
                .tint(themeManager.colorScheme == .light ? .black : nil)
        }
    }

    private var themePickerPopover: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach([("system", "Auto"), ("mocha", "Mocha · Dark"), ("latte", "Latte · Light")], id: \.0) { id, label in
                Button {
                    guard id != themeManager.themeID else { return }
                    withTransaction(Transaction(animation: nil)) {
                        themeManager.themeID = id
                    }
                    showingThemePicker = false
                } label: {
                    HStack {
                        Text(label)
                            .foregroundStyle(.primary)
                        Spacer()
                        if themeManager.themeID == id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                    .contentShape(Rectangle())
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                if id != "latte" { Divider() }
            }
        }
        .frame(minWidth: 200)
        .presentationCompactAdaptation(.popover)
    }

    // MARK: - Actions

    private func addDocument() {
        let doc = TypistDocument(title: "Untitled", content: "")
        modelContext.insert(doc)
        ProjectFileManager.ensureProjectStructure(for: doc)
        try? ProjectFileManager.writeTypFile(named: "main.typ", content: "", for: doc)
        selectedDocument = doc
    }
}
