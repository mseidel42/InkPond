//
//  SnippetBrowserSheet.swift
//  InkPond
//

import SwiftUI

struct SnippetBrowserSheet: View {
    @Environment(SnippetStore.self) var snippetStore
    @Environment(\.dismiss) var dismiss

    var onInsert: (Snippet) -> Void

    @State private var searchText = ""
    @State private var showingEditor = false
    @State private var editingSnippet: Snippet?

    var body: some View {
        NavigationStack {
            List {
                let groups = snippetStore.snippetsGroupedByCategory(matching: searchText)
                if groups.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    ForEach(groups, id: \.category) { group in
                        Section(group.category) {
                            ForEach(group.snippets) { snippet in
                                Button {
                                    onInsert(snippet)
                                    dismiss()
                                } label: {
                                    snippetRow(snippet)
                                }
                                .tint(.primary)
                                .contextMenu {
                                    if !snippet.isBuiltIn {
                                        Button {
                                            editingSnippet = snippet
                                        } label: {
                                            Label(L10n.tr("snippet.action.edit"), systemImage: "pencil")
                                        }
                                        Button(role: .destructive) {
                                            snippetStore.delete(snippet)
                                        } label: {
                                            Label(L10n.tr("action.delete"), systemImage: "trash")
                                        }
                                    }
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    if !snippet.isBuiltIn {
                                        Button(role: .destructive) {
                                            snippetStore.delete(snippet)
                                        } label: {
                                            Label(L10n.tr("action.delete"), systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, prompt: Text(L10n.tr("snippet.search.prompt")))
            .navigationTitle(L10n.tr("snippet.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("Done")) { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(L10n.tr("snippet.action.new"))
                }
            }
            .sheet(isPresented: $showingEditor) {
                SnippetEditorSheet()
            }
            .sheet(item: $editingSnippet) { snippet in
                SnippetEditorSheet(snippet: snippet)
            }
        }
    }

    private func snippetRow(_ snippet: Snippet) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(snippet.title)
                    .font(.body)
                if !snippet.isBuiltIn {
                    Text(L10n.tr("snippet.badge.custom"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }
            }
            Text(snippet.body.replacingOccurrences(of: "$0", with: "").prefix(80))
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 2)
    }
}
