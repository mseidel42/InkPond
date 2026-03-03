# Typist

A native iOS/iPadOS editor for [Typst](https://typst.app/) — the modern typesetting system.

<p align="center">
  <img src="https://img.shields.io/badge/iOS%2017%2B-blue" alt="Platform">
  <img src="https://img.shields.io/badge/language-Swift%205-orange" alt="Language">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License">
</p>

## Features

- **Native Editing Experience** — Syntax-highlighted editor optimized for Typst markup
- **Live Preview** — Real-time PDF rendering as you type
- **Document Management** — Organize your documents with SwiftData persistence
- **PDF Export** — Generate publication-ready PDFs using the official Typst engine
- **Universal App** — Optimized for both iPhone and iPad with adaptive layout

## Screenshots

*(Screenshots coming soon)*

## Requirements

- iOS 17.0+ / iPadOS 17.0+
- Xcode 26.3+
- Swift 5

## Building

### Prerequisites

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/Typist.git
   cd Typist
   ```

2. Build the Rust FFI framework:
   ```bash
   cd rust-ffi
   ./build-ios.sh
   cd ..
   ```

3. Open the project in Xcode:
   ```bash
   open Typist.xcodeproj
   ```

4. Build and run on your device or simulator.

### Build Commands

```bash
# Debug build
xcodebuild -project Typist.xcodeproj -scheme Typist -configuration Debug build

# Release build
xcodebuild -project Typist.xcodeproj -scheme Typist -configuration Release build

# Run tests
xcodebuild test -project Typist.xcodeproj -scheme Typist -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Architecture

```
Typist/
├── TypistApp.swift          # App entry point
├── ContentView.swift        # Main split view layout
├── Models/
│   └── TypistDocument.swift # SwiftData model
├── Views/
│   ├── DocumentListView.swift
│   ├── DocumentEditorView.swift
│   ├── EditorView.swift
│   └── PreviewPane.swift
├── Editor/
│   ├── TypstTextView.swift  # Custom text editor
│   └── SyntaxHighlighter.swift
├── Compiler/
│   ├── TypstCompiler.swift  # Compilation interface
│   └── TypstBridge.swift    # FFI bridge
└── Bridging/
    └── Typist-Bridging-Header.h

rust-ffi/
├── Cargo.toml               # Rust dependencies (typst 0.14)
├── build-ios.sh             # Build script for iOS framework
└── src/
    └── lib.rs               # Rust FFI bindings
```

## Tech Stack

- **SwiftUI** — Declarative UI framework
- **SwiftData** — Modern data persistence
- **Typst 0.14** — Typesetting engine via Rust FFI
- **Rust** — FFI layer for Typst integration

## Acknowledgements

This project stands on the shoulders of giants. Special thanks to:

- **[Typst](https://github.com/typst/typst)** — The modern typesetting system that powers our PDF rendering. Typst is licensed under the Apache License 2.0.
  - `typst` — Core typesetting engine
  - `typst-pdf` — PDF export functionality
  - `typst-assets` — Font assets

- **[Apple Developer Documentation](https://developer.apple.com/documentation/)** — For SwiftUI, SwiftData, and iOS development resources.

- **[Rust FFI Working Group](https://github.com/rust-lang/nomicon)** — For the Rust FFI patterns and best practices that made the Swift-Rust bridge possible.

## License

MIT License

Copyright (c) 2026 Lin Qidi

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
