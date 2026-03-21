//
//  DocumentEditorView+Layout.swift
//  InkPond
//

import SwiftUI
import PDFKit
import PhotosUI
import UniformTypeIdentifiers
import UIKit

private extension View {
    @ViewBuilder
    func navigationSubtitleCompat(_ subtitle: String) -> some View {
        if #available(iOS 26, *) {
            self.navigationSubtitle(subtitle)
        } else {
            self
        }
    }
}
struct UIKitMenu: UIViewRepresentable {
    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type:.roundedRect)
        button.setImage(UIImage(systemName: "ellipsis"), for: .normal)
        button.showsMenuAsPrimaryAction = true

        let menu = UIMenu(title: "", preferredElementSize: .medium, children: [
            UIAction(title: "Share", image: UIImage(systemName: "square.and.arrow.up"), handler: { _ in }),
            UIAction(title: "Settings", image: UIImage(systemName: "gearshape"), handler: { _ in }),
            UIAction(title: "Files", image: UIImage(systemName: "folder"), handler: { _ in }),
            UIAction(title: "Info", image: UIImage(systemName: "info.circle"), handler: { _ in }),
            UIAction(title: "Find & Replace", image: UIImage(systemName: "magnifyingglass"), handler: { _ in }),
        ])

        button.menu = menu
        return button
    }

    func updateUIView(_ uiView: UIButton, context: Context) {}
}


extension DocumentEditorView {
    /// Sync is only useful on iPad where both panes are visible simultaneously.
    private var isSyncEnabled: Bool { sizeClass == .regular }

    var editorPane: some View {
        EditorView(
            text: $editorText,
            insertionRequest: $insertionRequest,
            findRequested: $findRequested,
            viewState: $editorViewState,
            cursorJumpOffset: $pendingCursorJump,
            focusCoordinator: focusCoordinator,
            sourceMap: isSyncEnabled && isEditingEntryFile ? compiler.sourceMap : nil,
            syncCoordinator: isSyncEnabled ? syncCoordinator : nil,
            theme: themeManager.currentTheme,
            errorLines: compilationErrorLines,
            onPhotoTapped: { showingPhotoPicker = true },
            onSnippetTapped: { showingSnippetBrowser = true },
            onImagePasted: { pastedImageData, selectedRange in
                importImage(
                    from: .rawData(pastedImageData, suggestedFileName: nil),
                    anchorRange: selectedRange,
                    targetFileName: currentFileName
                )
            },
            onRichPaste: { fragments, selectedRange in
                handleRichPaste(
                    fragments,
                    anchorRange: selectedRange,
                    targetFileName: currentFileName
                )
            },
            fontFamilies: completionFontFamilies,
            bibEntries: cachedBibEntries,
            externalLabels: cachedExternalLabels,
            imageFiles: cachedImageFiles,
            packageSpecs: cachedPackageSpecs
        )
        .onDrop(of: [UTType.image.identifier, UTType.fileURL.identifier],
                isTargeted: $isImageDropTarget,
                perform: handleImageDrop(providers:))
        .overlay {
            if isImageDropTarget {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.accentColor.opacity(0.85), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                    .padding(12)
                    .allowsHitTesting(false)
            }
        }
//        .background(Color(uiColor: .systemGroupedBackground))
        .ignoresSafeArea(edges: .bottom)
    }

    var previewPane: some View {
        PreviewPane(
            compiler: compiler,
            source: entrySource,
            fontPaths: compileFontPaths,
            rootDir: rootDir,
            previewCacheDescriptor: compiledPreviewCacheDescriptor,
            compileToken: compileToken,
            focusCoordinator: focusCoordinator,
            sourceMap: isSyncEnabled ? compiler.sourceMap : nil,
            syncCoordinator: syncCoordinator,
            entryFileName: document.entryFileName,
            onGoToError: { file, line, column in
                navigateToError(file: file, line: line, column: column)
            }
        )
//        .background(Color(uiColor: .systemGroupedBackground))
    }

    func splitHandle(totalWidth: CGFloat) -> some View {
        let dragGesture = DragGesture(minimumDistance: 1, coordinateSpace: .named("splitContainer"))
            .onChanged { value in
                let raw = value.location.x / totalWidth
                withTransaction(Transaction(animation: nil)) {
                    editorFraction = min(0.8, max(0.2, raw))
                }
            }

        return Capsule()
            .fill(Color(uiColor: .separator))
            .frame(width: 2, height: 36)
            .overlay {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 28, height: 44)
                    .contentShape(Rectangle())
                    .gesture(dragGesture)
                    .simultaneousGesture(
                        TapGesture(count: 2).onEnded {
                            InteractionFeedback.impact(.medium)
                            withAnimation(.spring(duration: 0.3)) { editorFraction = 0.5 }
                        }
                    )
            }
            .accessibilityElement()
            .accessibilityLabel(L10n.a11yEditorSplitLabel)
            .accessibilityHint(L10n.a11yEditorSplitHint)
            .accessibilityValue(splitHandleAccessibilityValue)
            .accessibilityIdentifier("editor.split-handle")
            .accessibilityAdjustableAction { direction in
                let delta: CGFloat = 0.1
                switch direction {
                case .increment:
                    InteractionFeedback.selection()
                    editorFraction = min(0.8, editorFraction + delta)
                case .decrement:
                    InteractionFeedback.selection()
                    editorFraction = max(0.2, editorFraction - delta)
                @unknown default:
                    break
                }
            }
            .accessibilityAction(named: Text(L10n.a11yEditorSplitReset)) {
                InteractionFeedback.impact(.medium)
                editorFraction = 0.5
            }
    }

    @ViewBuilder
    var contentLayout: some View {
//        ScrollView(showsIndicators: false){
            if sizeClass == .regular {
                GeometryReader { geo in
                    let total = geo.size.width
                    HStack(spacing: 0) {
                        editorPane
                            .ignoresSafeArea(edges:.top)
                            .frame(width: total * editorFraction)
                        splitHandle(totalWidth: total)
                        previewPane
                            .ignoresSafeArea(edges:.top)
                            .scrollEdgeEffectStyle(.soft, for: .all)
                    }
                    .coordinateSpace(name: "splitContainer")
                }
            } else {
                TabView(selection: $selectedTab){
                    Tab("Editor", systemImage: "text.quote", value: 0){
                        editorPane
                    }
                    Tab("Preview", systemImage: "text.document", value:1){
                        previewPane
                            .onChange(of:exporter.isExporting) { _, newValue in
                                if newValue {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        showingProgressView = newValue
                                    }
                                } else {
                                    showingProgressView = newValue
                                }
                            }
                            .overlay {
                                if showingProgressView {
                                    ZStack {
                                        Rectangle()
                                            .fill(.ultraThinMaterial)
                                            .ignoresSafeArea()
                                        ProgressView("Compiling…")
                                            .padding()
                                            .systemFloatingSurface()
                                    }
                                }
                            }
                    }
                }
                .tabViewStyle(.page)
            }
//        }
//        .scrollEdgeEffectStyle(.soft, for: .all)
    }

    var shareButtonAction: () -> Void {
        if sizeClass == .regular || selectedTab == previewTab {
            return {
                guard flushPendingSave() else { return }
                exporter.exportPDF(for: document, cachedPDF: compiler.pdfDocument)
            }
        }
        return {
            guard flushPendingSave() else { return }
            exporter.exportTypSource(for: document, fileName: currentFileName)
        }
    }

    var shareButtonLabel: String {
        if sizeClass == .regular || selectedTab == previewTab { return "Share PDF" }
        return "Export .typ"
    }

    var canTriggerPreviewActions: Bool {
        !entrySource.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var resumeBannerLabel: String {
        let fileName = document.lastEditedFileName
        if fileName.isEmpty || fileName == document.entryFileName {
            return L10n.tr("resume.banner.label")
        } else {
            return L10n.format("resume.banner.label_with_file", fileName)
        }
    }

    var resumeBanner: some View {
        Button {
            positionRestoreDismissTask?.cancel()
            withAnimation(.easeInOut(duration: 0.25)) {
                showingPositionRestore = false
            }
            restoreSavedPosition()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .font(.body)
                    .foregroundStyle(.tint)
                Text(resumeBannerLabel)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .systemFloatingSurface(cornerRadius: 999)
            .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        }
        .accessibilityLabel(resumeBannerLabel)
        .accessibilityHint(L10n.tr("resume.banner.a11y_hint"))
    }
    var editorChrome: some View {
        contentLayout
            .navigationTitle(document.title)
            .navigationSubtitleCompat(currentFileName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarRole(.editor)
            .toolbar {
                if(sizeClass == .regular){
                    ToolbarItem(placement: .topBarLeading) {
                        Button {} label: {
                            Label("Back", systemImage: "chevron.left")
                        }
                    }
                }
                ToolbarTitleMenu(){
                    Button { shareButtonAction() } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    Button {triggerZipExport()} label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    Button {triggerZipExport()} label: {
                        Label("Export", systemImage: "square.and.arrow.up.on.square")
                    }
                    Button {triggerZipExport()} label: {
                        Label("Export Project as Zip", systemImage: "zipper.page")
                    }
                    Divider()
                    Button {triggerZipExport()} label: {
                        Label("Print", systemImage: "printer")
                    }
                }
            }
            .toolbar {
                if(sizeClass == .regular){
                    ToolbarItemGroup(placement: .secondaryAction) {
                        Button { } label: {
                            Label("Add breaks, links, footnotes", systemImage: "text.badge.plus")
                        }
                        Button { } label: {
                            Label("Add Bullet List", systemImage: "list.bullet")
                        }
                        Button { } label: {
                            Label("Add Numbered List", systemImage: "list.number")
                        }
                        Button { } label: {
                            Label("Add Table", systemImage: "tablecells")
                        }
                        Button { } label: {
                            Label("Add Image", systemImage: "paperclip")
                        }
                    } label: {
                        Label("Add elements", systemImage: "text.badge.plus")
                    }
                } else{
                    ToolbarItemGroup() {
                        Picker("", selection: $selectedTab) {
                            Label("Editor", systemImage: "text.quote").tag(0)
                            Label("Preview", systemImage: "document").tag(1)
                        }
                        .pickerStyle(.segmented)
                    }
                    ToolbarSpacer(.flexible)
                    
                        ToolbarItem(placement:.topBarTrailing) {
                            if (selectedTab == editorTab){
                                UIKitMenu()
                                    .frame(width: 32, height: 32)
                            } else{
                                Button { showingSlideshow = true } label: {
                                    Label("Slideshow", systemImage: "play.rectangle")
                                }.disabled(!compiler.compiledOnce)
                            }
                        }
                }
            }
            .toolbar {
                if(sizeClass == .regular){
                    ToolbarItem() {
                        Button { showingSlideshow = true } label: {
                            Label("Slideshow", systemImage: "play.rectangle")
                        }.disabled(!compiler.compiledOnce)
                    }
                    
                    ToolbarItem() {
                        Button { showingProjectSettings = true } label: {
                            Label("Project Settings", systemImage: "gearshape")
                        }
                    }
                    ToolbarSpacer(.fixed)
                    
                    ToolbarItem(){
                        Button { shareButtonAction() } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        .accessibilityLabel(Text(shareButtonLabel))
                        .accessibilityHint(L10n.a11yEditorShareHint)
                        .accessibilityIdentifier("editor.share")
                    }
                    ToolbarSpacer(.fixed)
                    
                    ToolbarItem(){
                        Button { findRequested = !findRequested } label: {
                            Label(L10n.tr("action.find_replace"), systemImage: "magnifyingglass")
                        }
                        .accessibilityIdentifier("editor.search")
                    }
                }
            }
//            .toolbar {
//                ToolbarItemGroup(placement: .keyboard) {
//                    Button{} label:{ Text("{") }
//                    Button{} label:{ Text("}") }
//                    Button{} label:{ Text("[") }
//                    Button{} label:{ Text("]") }
//                    Button{} label:{ Text("(") }
//                    Button{} label:{ Text(")") }
//                }
////                            ToolbarItemGroup(placement: .keyboard) {
////                                Button("♣️", action: {})
////                                Button("♥️", action: {})
////                                Button("♠️", action: {})
////                                Button("♦️", action: {})
////                            }
//            }
//            .overlay(alignment: .bottom) {
//                ControlGroup {
//                    Button("{") { }
//                    Button("}") { }
//                    Button("(") { }
//                    Button(")") { }
//                    Button("[") { }
//                    Button("]") { }
//                }
//                .glassEffect(.clear)
//                .frame(height: 48)
//                .ignoresSafeArea()
////                .padding() // 👈 This does the trick
//            }
    }

    var editorPresentation: some View {
        editorChrome
            .photosPicker(isPresented: $showingPhotoPicker,
                          selection: $selectedPhotoItems,
                          maxSelectionCount: 1,
                          matching: .images)
            .onChange(of: selectedPhotoItems) { _, items in handleImageSelection(items) }
            .sheet(isPresented: $showingFileBrowser) {
                ProjectFileBrowserSheet(document: document, currentFileName: currentFileName, openFile: openFile)
            }
            .sheet(isPresented: $showingProjectSettings) {
                ProjectSettingsSheet(document: document, openFile: openFile)
            }
            .sheet(isPresented: $showingImportConfiguration) {
                InitialEntryFilePickerSheet(document: document) { selectedEntry, selectedImageDirectory, selectedFontDirectory in
                    if let selectedEntry {
                        document.entryFileName = selectedEntry
                    }
                    document.requiresInitialEntrySelection = false
                    if let selectedImageDirectory {
                        document.imageDirectoryName = selectedImageDirectory
                    } else {
                        document.imageDirectoryName = "images"
                        ProjectFileManager.ensureImageDirectory(for: document)
                    }
                    if let selectedFontDirectory {
                        _ = ProjectFileManager.importFontFiles(from: selectedFontDirectory, for: document)
                    } else {
                        ProjectFileManager.ensureFontsDirectory(for: document)
                    }
                    document.requiresImportConfiguration = false
                    document.importEntryFileOptions = []
                    document.importImageDirectoryOptions = []
                    document.importFontDirectoryOptions = []
                    showingImportConfiguration = false
                    _ = loadFile(named: document.entryFileName)
                }
            }
    }

    var editorLifecycleHandlers: some View {
        editorPresentation
            .onAppear {
                refreshCompileFontPaths()
                prepareDocumentForEditing()
                refreshReferenceCompletions()
                if hasSavedPosition() {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showingPositionRestore = true
                    }
                    positionRestoreDismissTask = Task { @MainActor in
                        try? await Task.sleep(for: .seconds(4))
                        guard !Task.isCancelled else { return }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showingPositionRestore = false
                        }
                    }
                }
            }
            .onDisappear {
                positionRestoreDismissTask?.cancel()
                positionRestoreDismissTask = nil
                positionSyncTask?.cancel()
                positionSyncTask = nil
                _ = flushPendingSave()
                persistEditorPositionIfNeeded()
                focusCoordinator.clearFocusPreservation()
                compiler.cancel()
            }
            .onChange(of: editorText) { _, newText in
                guard !isLoadingFileContent else { return }
                handleEditorTextChange(newText)
            }
            .onChange(of: document.fontFileNames) { _, _ in
                handleCompileInputsChanged()
            }
            .onChange(of: compileToken) { _, _ in
                refreshReferenceCompletions()
            }
            .onChange(of: syncCoordinator.editorScrollTarget) { _, target in
                guard let target else { return }
                if sizeClass != .regular {
                    selectedTab = 0
                }
                if currentFileName != document.entryFileName {
                    guard openFileIfPossible(named: document.entryFileName) else { return }
                }
                pendingCursorJump = utf16Offset(forLine: target.line, column: target.column, in: editorText)
                syncCoordinator.editorScrollTarget = nil
                InteractionFeedback.impact(.light)
            }
            .onChange(of: appFontLibrary.items) { _, _ in
                handleCompileInputsChanged()
            }
            .onChange(of: currentFileName) { _, newValue in
                guard !newValue.isEmpty else { return }
                scheduleEditorPositionSync(delay: .milliseconds(150))
            }
            .onChange(of: editorViewState.selectedLocation) { _, _ in
                scheduleEditorPositionSync()
            }
    }

    var editorSheetsAndEvents: some View {
        editorLifecycleHandlers
            .onChange(of: insertionRequest) { _, newValue in
                if newValue == nil {
                    pumpPendingInsertionsIfNeeded()
                }
            }
            .onChange(of: currentFileName) { _, _ in
                pumpPendingInsertionsIfNeeded()
            }
            .onChange(of: selectedTab) { _, newTab in
                InteractionFeedback.selection()
                if newTab != 0 {
                    focusCoordinator.dismissKeyboard()
                }
            }
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
            .onChange(of: imageImportError) { _, newValue in
                guard newValue != nil else { return }
                InteractionFeedback.notify(.error)
                AccessibilitySupport.announce(newValue)
            }
            .onChange(of: fileSaveError) { _, newValue in
                guard newValue != nil else { return }
                InteractionFeedback.notify(.error)
                AccessibilitySupport.announce(newValue)
            }
            .onChange(of: previewActionError) { _, newValue in
                guard newValue != nil else { return }
                InteractionFeedback.notify(.error)
                AccessibilitySupport.announce(newValue)
            }
            .onChange(of: compiler.pdfDocument) { _, newValue in
                if newValue != nil {
                    syncCursorToPreviewIfPending()
                }
                guard pendingManualCompileFeedback, newValue != nil, compiler.errorMessage == nil else { return }
                pendingManualCompileFeedback = false
                InteractionFeedback.notify(.success)
                AccessibilitySupport.announce(L10n.a11yCompileSuccess)
            }
            .onChange(of: compiler.errorMessage) { _, newValue in
                compilationErrorLines = recomputeCompilationErrorLines()
                guard pendingManualCompileFeedback, newValue != nil else { return }
                pendingManualCompileFeedback = false
                InteractionFeedback.notify(.error)
                AccessibilitySupport.announce(L10n.a11yCompileFailed)
            }
    }

    var editorOverlaysAndAlerts: some View {
        editorSheetsAndEvents
            .overlay {
                if exporter.isExporting && sizeClass == .regular {
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
            .overlay(alignment: .bottom) {
                if let toast = imageImportToast {
                    Text(toast)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .systemFloatingSurface(cornerRadius: 999)
                        .padding(.bottom, 18)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(toast)
                }
            }
            .sheet(item: $exporter.exportURL) { url in ActivityView(activityItems: [url]) }
            .sheet(isPresented: $showingKeyboardShortcuts) {
                NavigationStack {
                    KeyboardShortcutsView()
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(L10n.tr("Done")) { showingKeyboardShortcuts = false }
                            }
                        }
                }
            }
            .sheet(isPresented: $showingOutline) {
                OutlineView(editorText: editorText) { offset in
                    handleOutlineJump(characterOffset: offset)
                }
            }
            .sheet(isPresented: $showingSnippetBrowser) {
                SnippetBrowserSheet { snippet in
                    let (text, cursorOffset) = snippet.bodyWithCursorOffset()
                    let targetRange = NSRange(
                        location: editorViewState.selectedLocation,
                        length: editorViewState.selectedLength
                    )
                    insertionRequest = EditorInsertionRequest(
                        text: text,
                        targetRange: targetRange,
                        targetFileName: currentFileName
                    )
                    if let cursorOffset {
                        pendingCursorJump = targetRange.location + cursorOffset
                    }
                }
            }
            .fullScreenCover(isPresented: $showingSlideshow) {
                if let pdf = compiler.pdfDocument {
                    SlideshowView(document: pdf)
                }
            }
            .alert("Export Error", isPresented: Binding(
                get: { exporter.exportError != nil },
                set: { if !$0 { exporter.exportError = nil } }
            )) {
                Button("OK") { exporter.exportError = nil }
            } message: {
                Text(exporter.exportError ?? "")
            }
            .alert(L10n.appFontsExportWarningTitle, isPresented: $showingZipExportWarning) {
                Button("Cancel", role: .cancel) {}
                Button("Continue") {
                    guard flushPendingSave() else { return }
                    exporter.exportZip(for: document)
                }
            } message: {
                Text(L10n.appFontsExportWarningMessage)
            }
            .alert("Image Import Error", isPresented: Binding(
                get: { imageImportError != nil },
                set: { if !$0 { imageImportError = nil } }
            )) {
                Button("OK") { imageImportError = nil }
            } message: {
                Text(imageImportError ?? "")
            }
            .alert("File Error", isPresented: Binding(
                get: { fileSaveError != nil },
                set: { if !$0 { fileSaveError = nil } }
            )) {
                Button("OK") { fileSaveError = nil }
            } message: {
                Text(fileSaveError ?? "")
            }
            .alert("Cache Error", isPresented: Binding(
                get: { previewActionError != nil },
                set: { if !$0 { previewActionError = nil } }
            )) {
                Button("OK") { previewActionError = nil }
            } message: {
                Text(previewActionError ?? "")
            }
            .overlay(alignment: .bottom) {
                if showingPositionRestore {
                    resumeBanner
                        .padding(.bottom, 48)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .alert(L10n.tr("icloud.conflict.title"), isPresented: $showingConflictWarning) {
                Button(L10n.tr("icloud.conflict.keep_local")) {
                    resolveConflictKeepLocal()
                }
                Button(L10n.tr("icloud.conflict.keep_remote")) {
                    resolveConflictKeepRemote()
                }
                Button(L10n.tr("Cancel"), role: .cancel) {
                    showingConflictWarning = false
                }
            } message: {
                Text(L10n.format("icloud.conflict.message", conflictFileName))
            }
    }

    var splitHandleAccessibilityValue: String {
        let editorPercent = Int((editorFraction * 100).rounded())
        let previewPercent = max(0, 100 - editorPercent)
        return L10n.a11yEditorSplitValue(editorPercent: editorPercent, previewPercent: previewPercent)
    }
}
