# CLAUDE.md

This repository is a native iOS/iPadOS Typst editor built with SwiftUI, SwiftData, and a Rust FFI bridge.

## Project Overview

- App target: `Typist`
- Minimum deployment target: iOS/iPadOS 17.0
- Optional iOS 26-only UI enhancements are used behind availability checks
- Data model: `TypistDocument` (`@Model`)
- Typst compilation: Rust static library packaged as `Frameworks/typst_ios.xcframework`

## Build Setup

The app depends on a generated Rust xcframework. Build it before the first Xcode build or after Rust changes:

```bash
cd rust-ffi
./build-ios.sh
cd ..
```

The xcframework output is generated locally into `Frameworks/typst_ios.xcframework` and is not committed.

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

- `Typist/TypistApp.swift`: app entry point and SwiftData `ModelContainer`
- `Typist/ContentView.swift`: top-level split-view shell and environment wiring
- `Typist/Models/TypistDocument.swift`: document model and import/config state
- `Typist/Compiler/`: project filesystem management, export flow, Typst bridge/compiler
- `Typist/Editor/`: text view, syntax highlighting, completion, editor theme logic
- `Typist/Views/DocumentList/`: document library UI and filesystem sync
- `Typist/Views/DocumentEditor/`: editor/preview UI, import/export actions, save lifecycle
- `Typist/Views/Settings/`: settings root plus fonts/cache/about subpages
- `Typist/Shared/UI/`: reusable UIKit/SwiftUI bridges and shared UI helpers
- `rust-ffi/`: Rust Typst wrapper and xcframework build script

## Conventions

- Default Swift isolation is `MainActor`
- `Typist/Info.plist` exists and is referenced alongside generated Info.plist settings in the Xcode project
- The project is Xcode + Cargo only; there is no npm/Electron stack in this repository
