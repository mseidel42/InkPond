//
//  SnippetEditorSheet.swift
//  InkPond
//

import SwiftUI

struct SnippetEditorSheet: View {
    @Environment(SnippetStore.self) var snippetStore
    @Environment(\.dismiss) var dismiss

    var snippet: Snippet?

    @State private var title: String = ""
    @State private var category: String = ""
    @State private var snippetBody: String = ""
    @State private var customCategory: String = ""
    @State private var useCustomCategory = false

    private var isEditing: Bool { snippet != nil }

    private var categories: [String] {
        var cats = SnippetLibrary.categoryOrder
        let userCategories = snippetStore.userSnippets.map(\.category)
        for cat in userCategories where !cats.contains(cat) {
            cats.append(cat)
        }
        return cats
    }

    private var effectiveCategory: String {
        useCustomCategory ? customCategory : category
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !snippetBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !effectiveCategory.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.tr("snippet.editor.section.details")) {
                    TextField(L10n.tr("snippet.editor.field.title"), text: $title)
                    if useCustomCategory {
                        TextField(L10n.tr("snippet.editor.field.category"), text: $customCategory)
                        Button(L10n.tr("snippet.editor.action.pick_category")) {
                            useCustomCategory = false
                        }
                    } else {
                        Picker(L10n.tr("snippet.editor.field.category"), selection: $category) {
                            ForEach(categories, id: \.self) { cat in
                                Text(cat).tag(cat)
                            }
                        }
                        Button(L10n.tr("snippet.editor.action.custom_category")) {
                            useCustomCategory = true
                            customCategory = category
                        }
                    }
                }

                Section {
                    TextEditor(text: $snippetBody)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 200)
                } header: {
                    Text(L10n.tr("snippet.editor.section.body"))
                } footer: {
                    Text(L10n.tr("snippet.editor.body.hint"))
                }
            }
            .navigationTitle(isEditing ? L10n.tr("snippet.editor.title.edit") : L10n.tr("snippet.editor.title.new"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("snippet.editor.action.save")) {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear {
                if let snippet {
                    title = snippet.title
                    snippetBody = snippet.body
                    if categories.contains(snippet.category) {
                        category = snippet.category
                    } else {
                        useCustomCategory = true
                        customCategory = snippet.category
                    }
                } else {
                    category = categories.first ?? ""
                }
            }
        }
    }

    private func save() {
        let cat = effectiveCategory.trimmingCharacters(in: .whitespaces)
        if var existing = snippet {
            existing.title = title.trimmingCharacters(in: .whitespaces)
            existing.category = cat
            existing.body = snippetBody
            snippetStore.update(existing)
        } else {
            let newSnippet = Snippet(
                title: title.trimmingCharacters(in: .whitespaces),
                category: cat,
                body: snippetBody
            )
            snippetStore.add(newSnippet)
        }
        dismiss()
    }
}
