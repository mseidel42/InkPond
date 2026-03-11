//
//  ProjectSettingsSheet.swift
//  Typist
//

import SwiftUI
import UniformTypeIdentifiers

struct ProjectSettingsSheet: View {
    @Bindable var document: TypistDocument
    var openFile: ((String) -> Void)?
    @Environment(AppFontLibrary.self) private var appFontLibrary
    @Environment(\.dismiss) private var dismiss
    @State private var typFiles: [String] = []
    @State private var showingFontPicker = false
    @State private var actionError: String?

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Entry File
                Section("Entry File") {
                    Picker("Entry File", selection: $document.entryFileName) {
                        ForEach(typFiles, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .onChange(of: document.entryFileName) { _, newName in
                        openFile?(newName)
                    }
                }

                // MARK: Image
                Section("Image Insertion") {
                    Picker("Format", selection: $document.imageInsertMode) {
                        Text("#image(\"path\")").tag("image")
                        Text("#figure(image(\"path\"), caption: [...])").tag("figure")
                    }
                }

                Section("Image Directory") {
                    TextField("Subdirectory name", text: $document.imageDirectoryName)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                // MARK: Fonts
                Section(
                    header: Text("Fonts"),
                    footer: Text(L10n.projectFontsFooter)
                ) {
                    Text(L10n.appFontsTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(appFontLibrary.groupedItems) { group in
                        HStack {
                            Label(group.familyName, systemImage: "character.textbox")
                                .foregroundStyle(group.isBuiltIn ? .secondary : .primary)
                            Spacer()
                            Text(group.isBuiltIn ? L10n.fontScopeBuiltIn : L10n.fontScopeApp)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Text(L10n.projectFontsTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if document.fontFileNames.isEmpty {
                        Text(L10n.noProjectFonts)
                            .foregroundStyle(.tertiary)
                    }

                    ForEach(document.fontFileNames, id: \.self) { name in
                        HStack {
                            Label(projectFontDisplayName(for: name), systemImage: "character.textbox")
                            Spacer()
                            Text(L10n.fontScopeProject)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .onDelete { offsets in
                        InteractionFeedback.notify(.warning)
                        let names = offsets.map { document.fontFileNames[$0] }
                        document.fontFileNames.remove(atOffsets: offsets)
                        for name in names {
                            FontManager.deleteFont(fileName: name, from: document)
                        }
                    }

                    Button {
                        InteractionFeedback.impact(.light)
                        showingFontPicker = true
                    } label: {
                        Label("Add Font…", systemImage: "plus.circle")
                    }
                }
            }
            .navigationTitle("Project Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        InteractionFeedback.impact(.light)
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: Binding(
                get: { actionError != nil },
                set: { if !$0 { actionError = nil } }
            )) {
                Button("OK") { actionError = nil }
            } message: {
                Text(actionError ?? "")
            }
        }
        .presentationDetents([.medium, .large])
        .fileImporter(
            isPresented: $showingFontPicker,
            allowedContentTypes: [.font],
            allowsMultipleSelection: true
        ) { result in
            guard case .success(let urls) = result else {
                if case .failure(let error) = result {
                    actionError = error.localizedDescription
                }
                return
            }
            var firstError: Error?
            for url in urls {
                do {
                    let name = try FontManager.importFont(from: url, for: document)
                    if !document.fontFileNames.contains(name) {
                        document.fontFileNames.append(name)
                    }
                } catch {
                    firstError = firstError ?? error
                }
            }
            if let firstError {
                actionError = firstError.localizedDescription
            }
        }
        .onAppear {
            typFiles = ProjectFileManager.listAllTypFiles(for: document)
            if typFiles.isEmpty { typFiles = [document.entryFileName] }
        }
    }

    private func projectFontDisplayName(for fileName: String) -> String {
        guard let path = FontManager.fontFilePath(for: fileName, in: document) else {
            return URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
        }
        return FontManager.typstFamilyName(forBundledPath: path)
            ?? URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
    }
}
