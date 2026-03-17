# CLAUDE.md

This repository is a native iOS/iPadOS Typst editor built with SwiftUI, SwiftData, and a Rust FFI bridge.

## Project Overview

- App target: `Typist`
- Minimum deployment target: iOS/iPadOS 17.0
- Optional iOS 26-only UI enhancements are used behind availability checks
- Data model: `TypistDocument` (`@Model`)
- Typst compilation: Rust static library packaged as `Frameworks/typst_ios.xcframework`
- Pinned Typst version: `0.14.2` (see `rust-ffi/Cargo.toml`)

## Build Setup

The app depends on a generated Rust xcframework. Build it before the first Xcode build or after Rust changes:

```bash
cd rust-ffi
./build-ios.sh
cd ..
```

The xcframework output is generated locally into `Frameworks/typst_ios.xcframework` and is not committed. The build script produces three targets: `aarch64-apple-ios` (device), `aarch64-apple-ios-sim` (M-series simulator), and `x86_64-apple-ios` (Intel simulator).

## Build & Test Commands

```bash
# Debug build for simulator
xcodebuild -project Typist.xcodeproj -scheme Typist -configuration Debug -destination 'generic/platform=iOS Simulator' build

# Release archive for device
xcodebuild -project Typist.xcodeproj -scheme Typist -configuration Release -destination 'generic/platform=iOS' archive

# Unit tests
xcodebuild test -project Typist.xcodeproj -scheme Typist -only-testing:TypistTests -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2'

# UI tests
xcodebuild test -project Typist.xcodeproj -scheme Typist -only-testing:TypistUITests -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2'
```

If the named simulator is unavailable locally, inspect options first:

```bash
xcodebuild -showdestinations -project Typist.xcodeproj -scheme Typist
```

## Architecture

### App Shell
- `Typist/TypistApp.swift`: `@main` entry point; sets up SwiftData `ModelContainer` with `TypistDocument` schema; initializes `SnippetStore`; runs startup cleanup (temp exports, font cache pruning)
- `Typist/ContentView.swift`: `NavigationSplitView` shell; sidebar = document list, detail = editor; injects `ThemeManager`, `AppAppearanceManager`, `AppFontLibrary` into environment; onboarding gate

### Data Model
- `Typist/Models/TypistDocument.swift`: `@Model` with properties: `title`, `content`, `createdAt`, `modifiedAt`, `fontFileNames[]`, `projectID`, `entryFileName`, `imageInsertMode`, `imageDirectoryName`, `lastEditedFileName`, `lastCursorLocation`, `requiresInitialEntrySelection`, import option arrays

### Editor Layer
- `Typist/Editor/TypstTextView.swift`: `UITextView` subclass forced to TextKit 1; integrates gutter, syntax highlighting, completion popup, auto-pairing, keyboard accessory, find/replace, rich paste handling (HTML→text, image extraction, remote URL fetch), keyboard avoidance
- `Typist/Editor/SyntaxHighlighter.swift`: 15 ordered regex rules (bold/italic, numbers+units, math, code blocks, inline code, labels/refs, keywords, literals, functions, bools, hash-keywords, headings, strings, block comments, line comments); rainbow bracket pass (6-color cycle); bracket mismatch detection (red underline); error line highlighting; jump highlight animation
- `Typist/Editor/CompletionEngine.swift`: context-aware completion for hash-prefix (~150 functions + keywords + snippets), parameters (after open paren), values (fonts, labels, image paths), at-prefix (@refs), angle-bracket labels; sources include font paths, BibTeX entries, external labels, image files
- `Typist/Editor/AutoPairEngine.swift`: pairs `{}[]()""$$`; type-over, auto-close, auto-delete, quote/$ awareness, auto-indent on Enter (4-space indent in brackets, triple newline with dedent); all ops registered with undo manager
- `Typist/Editor/SyncCoordinator.swift`: bidirectional editor↔preview sync; direction lock + 150ms cooldown to prevent feedback loops; editor→preview on tap/arrow, preview→editor on PDF tap
- `Typist/Editor/EditorTheme.swift` + `ThemeManager.swift`: Mocha (forced dark), Latte (forced light), System (adaptive); Catppuccin color palette; persisted in UserDefaults
- `Typist/Editor/Snippet.swift` + `SnippetLibrary.swift` + `SnippetStore.swift`: snippet model with `$0` cursor placeholder; built-in library + user custom; persisted as JSON in `Library/ApplicationSupport/Snippets.json`
- `Typist/Editor/HighlightScheduler.swift`: debounced syntax highlighting scheduling
- `Typist/Editor/LineNumberGutterView.swift`: gutter with theme-aware colors and error line markers
- `Typist/Editor/KeyboardAccessoryView.swift`: accessory bar with photo import and snippet insertion buttons

### Compiler Layer
- `Typist/Compiler/TypstBridge.swift`: Rust FFI wrapper; `compile()` → PDF data; `compileWithSourceMap()` → PDF + `SourceMap`; null-terminated UTF-8 source, font paths (bundled CJK + project + app), rootDir for local file resolution
- `Typist/Compiler/TypstCompiler.swift`: `@Observable @MainActor`; debounced compilation (350ms, `.utility` priority) and immediate compilation (`.medium` priority, for export); 30s timeout; integrates `CompiledPreviewCacheStore`; exposes `pdfDocument`, `errorMessage`, `sourceMap`
- `Typist/Compiler/SourceMap.swift`: sorted arrays by source offset and by (page, yPoints); binary search lookup for both directions
- `Typist/Compiler/ProjectFileManager.swift` (+ Files/Listing/Sync extensions): per-project directory management; file CRUD with path traversal validation; rename with atomic directory move; import files; build recursive project tree; supported image extensions (bmp/eps/gif/heic/jpg/png/svg/webp/etc), font extensions (otf/ttf/woff/woff2)
- `Typist/Compiler/FontManager.swift`: three font sources in precedence: bundled CJK (Source Han Sans/Serif SC), project fonts (`{root}/fonts/`), app fonts (`Library/ApplicationSupport/AppFonts/`); font name extraction from OTF/TTF name table
- `Typist/Compiler/ExportManager.swift`: PDF/source/ZIP export; custom streaming ZIP writer (no external dependency; local file header + central directory + EOCD, CRC-32 per file)
- `Typist/Compiler/ZipImporter.swift`: ZIP project import with entry/image/font extraction
- `Typist/Compiler/DirectoryMonitor.swift`: `DispatchSourceFileSystemObject` watching Documents for external changes
- `Typist/Compiler/CompiledPreviewCacheStore.swift` + `PreviewPackageCacheStore.swift`: disk-based caches keyed by project + source hash + font paths + Typst version

### Views Layer
- `Typist/Views/DocumentList/`: `@Query` sorted by `modifiedAt` desc; search, sort options, rename dialog, swipe-delete, directory monitor sync, ZIP import, export actions
- `Typist/Views/DocumentEditor/DocumentEditorView.swift` (+ Layout/FileOperations/Images extensions): file-based editing state (`currentFileName`, `editorText`, `entrySource`, `compileToken`, `compileFontPaths`); iPad HStack split (adjustable 0.2–0.8), iPhone segmented tabs; toolbar with project files, image insert, fonts, project settings
- `Typist/Views/DocumentEditor/OutlineView.swift`: parses headings from editor text; tap to jump
- `Typist/Views/EditorView.swift`: `UIViewRepresentable` wrapping `TypstTextView`; `insertionRequest` binding for cursor insertion
- `Typist/Views/PreviewPane.swift`: `PDFKitView` (UIViewRepresentable wrapping PDFView); error banner with expandable details; statistics card (pages, words/tokens, characters; CJK-aware via `NLTokenizer`); progress indicator; sync marker animation
- `Typist/Views/SlideshowView.swift`: full-screen PDF presentation with swipe navigation
- `Typist/Views/OnboardingView.swift`: first-launch onboarding flow
- `Typist/Views/SnippetBrowserSheet.swift` + `SnippetEditorSheet.swift`: snippet library UI and custom snippet editor
- `Typist/Views/ProjectFileBrowserSheet.swift`: file browser with .typ/images/fonts sections; tap to open, swipe delete (entry file protected), new file, file import
- `Typist/Views/ProjectSettingsSheet.swift`: entry file picker, image insert format, image subdirectory name
- `Typist/Views/Settings/`: settings root (`SettingsView`), app font management, keyboard shortcuts (iOS 26+), compiled preview cache, package cache, acknowledgements

### Supporting Modules
- `Typist/Storage/AppFontLibrary.swift`: app-wide font import tracking and registration cache
- `Typist/Shared/UI/ActivityView.swift`: `UIActivityViewController` wrapper
- `Typist/Shared/UI/SystemSurface.swift`: glass/blur effect view
- `Typist/Support/InteractionSupport.swift`: haptic feedback helpers + `AccessibilitySupport.announce()`
- `Typist/Localization/L10n.swift`: generated localization lookup (`L10n.tr("key")`, `L10n.format("key", args...)`); languages: en, zh-Hans, zh-Hant-HK, zh-Hant-TW
- `Typist/Bridging/typst_ffi.h`: C header for Rust FFI (`typst_compile`, `typst_compile_with_source_map`, `typst_version`; structs: `TypstResult`, `TypstResultWithMap`, `SourceMapEntry`, `TypstOptions`)

### Rust FFI
- `rust-ffi/`: Rust Typst wrapper and xcframework build script
- Linked in pbxproj with `OTHER_SWIFT_FLAGS: -DTYPST_FFI_AVAILABLE` (both Debug + Release)
- `OTHER_LDFLAGS: -lc++ -framework Security -framework CoreFoundation -framework CoreText -framework CoreGraphics`
- Bridging header: `Typist/Bridging/Typist-Bridging-Header.h` → `typst_ffi.h`

## Conventions

- Default Swift isolation is `MainActor` (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`)
- Rust FFI calls must use `nonisolated` + `Task.detached` to cross the actor boundary
- `Typist/Info.plist` exists and is referenced alongside generated Info.plist settings in the Xcode project
- The project uses `PBXFileSystemSynchronizedRootGroup` — new Swift files are auto-discovered by Xcode without manual xcodeproj edits
- The project is Xcode + Cargo only; there is no npm/Electron stack in this repository
- `@Observable` + `@State` for reactive managers (ThemeManager, SyncCoordinator, TypstCompiler, etc.)
- `UIViewRepresentable` for all UIKit integrations (TypstTextView, PDFKitView)
- All user-facing strings go through `L10n.tr()` / `L10n.format()` for localization
- Accessibility is first-class: all interactive elements have `accessibilityLabel`/`accessibilityHint`/`accessibilityValue`
- Detail views use `.id(document.persistentModelID)` to prevent stale reloads
