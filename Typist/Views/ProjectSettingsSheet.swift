//
//  ProjectSettingsSheet.swift
//  Typist
//

import SwiftUI
import UniformTypeIdentifiers

struct ProjectSettingsSheet: View {
    @Bindable var document: TypistDocument
    var openFile: ((String) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var typFiles: [String] = []
    @State private var showingFontPicker = false
    @State private var bundledFontNames: [(path: String, name: String)] = []
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
                Section(header: Text("Fonts"), footer: Text("Bundled fonts are always available in Typst by their listed names.")) {
                    ForEach(bundledFontNames, id: \.path) { item in
                        HStack {
                            Label(item.name, systemImage: "textformat")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("built-in")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    ForEach(document.fontFileNames, id: \.self) { name in
                        Label(name, systemImage: "doc.text")
                    }
                    .onDelete { offsets in
                        let names = offsets.map { document.fontFileNames[$0] }
                        document.fontFileNames.remove(atOffsets: offsets)
                        for name in names {
                            FontManager.deleteFont(fileName: name, from: document)
                        }
                    }

                    Button { showingFontPicker = true } label: {
                        Label("Add Font…", systemImage: "plus")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.catppuccinBase)
            .navigationTitle("Project Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
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
            // Pre-compute font names off the render cycle (reads font files from disk)
            bundledFontNames = FontManager.bundledCJKFontPaths.map { path in
                let name = FontManager.typstFamilyName(forBundledPath: path)
                    ?? URL(fileURLWithPath: path).lastPathComponent
                return (path: path, name: name)
            }
        }
    }
}
