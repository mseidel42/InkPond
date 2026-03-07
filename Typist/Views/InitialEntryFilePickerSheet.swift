//
//  InitialEntryFilePickerSheet.swift
//  Typist
//

import SwiftUI

struct InitialEntryFilePickerSheet: View {
    @Bindable var document: TypistDocument
    let chooseEntryFile: (String) -> Void
    @State private var fileNames: [String] = []

    var body: some View {
        NavigationStack {
            List {
                if fileNames.isEmpty {
                    ContentUnavailableView(
                        "No .typ Files Found",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("Typist could not find any .typ files in this project.")
                    )
                } else {
                    ForEach(fileNames, id: \.self) { name in
                        Button {
                            chooseEntryFile(name)
                        } label: {
                            HStack {
                                Image(systemName: "doc.plaintext")
                                    .foregroundStyle(.secondary)
                                Text(name)
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.catppuccinBase)
            .navigationTitle("Choose Entry File")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Text("This project does not include main.typ. Choose the file used for compilation.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial)
            }
        }
        .interactiveDismissDisabled()
        .presentationDetents([.medium])
        .onAppear {
            fileNames = ProjectFileManager.listAllTypFiles(for: document)
        }
    }
}
