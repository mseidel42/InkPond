# Typist

Typist 是一个原生 iOS/iPadOS 的 [Typst](https://typst.app/) 编辑器，支持实时预览与 PDF 导出，底层由 Rust FFI 驱动。

<p align="center">
  <a href="https://testflight.apple.com/join/w5jmkR2T"><img src="https://img.shields.io/badge/TestFlight-Beta-0D96F6?logo=apple&logoColor=white" alt="TestFlight"></a>
  <a href="README.md"><img src="https://img.shields.io/badge/English-README-2563EB" alt="English README"></a>
</p>
<p align="center">
  <img src="https://img.shields.io/badge/平台-iOS%2026%20%26%20iPadOS%2026-2563EB" alt="Platform">
  <img src="https://img.shields.io/badge/语言-Swift%205-F59E0B" alt="Language">
  <img src="https://img.shields.io/badge/Typst-0.14.2-0EA5A4" alt="Typst Version">
  <img src="https://img.shields.io/badge/许可证-Apache%202-1D4ED8" alt="License">
</p>

## 语言

- 简体中文（当前）
- English: [README.md](README.md)

## 快速入口

| 操作 | 命令 / 链接 |
|---|---|
| 加入内测 | [testflight.apple.com/join/w5jmkR2T](https://testflight.apple.com/join/w5jmkR2T) |
| 构建 Rust FFI | `cd rust-ffi && ./build-ios.sh` |
| 模拟器 Debug 构建 | `xcodebuild -project Typist.xcodeproj -scheme Typist -configuration Debug -destination 'generic/platform=iOS Simulator' build` |
| 上传 TestFlight | `asc --profile default builds upload --app 6760032537 --ipa /private/tmp/Typist-export/Typist.ipa --output table` |

## 功能特性

- 原生 Typst 编辑体验（含语法高亮）
- 输入时实时 PDF 预览
- 基于 SwiftData 的文档管理
- PDF 与源文件导出
- iPhone / iPad 自适应界面

## 环境要求

- macOS + Xcode 26.3+
- App 目标最低系统：iOS/iPadOS 26.0
- Rust 工具链（`rustup`、`cargo`）用于构建 `typst_ios.xcframework`

## 快速开始

1. 克隆仓库：
   ```bash
   git clone https://github.com/yourusername/Typist.git
   cd Typist
   ```
2. 构建 Rust FFI 框架：
   ```bash
   cd rust-ffi
   ./build-ios.sh
   cd ..
   ```
3. 用 Xcode 打开并运行：
   ```bash
   open Typist.xcodeproj
   ```

## 常用构建命令

```bash
# 模拟器 Debug 构建
xcodebuild -project Typist.xcodeproj -scheme Typist -configuration Debug -destination 'generic/platform=iOS Simulator' build

# 真机 Release Archive
xcodebuild -project Typist.xcodeproj -scheme Typist -configuration Release -destination 'generic/platform=iOS' archive

# 测试
xcodebuild test -project Typist.xcodeproj -scheme Typist -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Rust FFI 说明

- `Frameworks/typst_ios.xcframework` 由 `rust-ffi/build-ios.sh` 生成。
- `Frameworks/**/*.a` 是构建产物，已在 git 中忽略。
- 以下情况请重新执行 `rust-ffi/build-ios.sh`：
  - 升级 Typst / Rust 依赖
  - 修改 `rust-ffi/src/lib.rs`
  - 发布前重建产物

当前固定 Typst 版本：`0.14.2`（见 `rust-ffi/Cargo.toml`）。

## 发布流程（CLI）

```bash
# 1) Archive
xcodebuild -project Typist.xcodeproj -scheme Typist -configuration Release -destination 'generic/platform=iOS' -archivePath /private/tmp/Typist.xcarchive archive

# 2) 导出 IPA（使用你的 ExportOptions.plist）
xcodebuild -exportArchive -archivePath /private/tmp/Typist.xcarchive -exportPath /private/tmp/Typist-export -exportOptionsPlist /private/tmp/Typist-export/ExportOptions.plist

# 3) 上传（示例 app id）
asc --profile default builds upload --app 6760032537 --ipa /private/tmp/Typist-export/Typist.ipa --output table
```

上传后需要等待 App Store Connect 完成处理，再分发到 TestFlight 分组。

## 项目结构

```text
Typist/
├── Typist/
│   ├── Views/
│   ├── Editor/
│   ├── Compiler/
│   ├── Models/
│   ├── Localization/
│   ├── Resources/
│   └── Bridging/
├── rust-ffi/
│   ├── src/lib.rs
│   ├── Cargo.toml
│   └── build-ios.sh
├── Frameworks/
│   └── typst_ios.xcframework/
└── Typist.xcodeproj
```

## 常见问题

- `Typst compiler library not linked`：
  - 执行 `cd rust-ffi && ./build-ios.sh` 后重新编译 App。
- 模拟器链接 `typst_ios` 架构错误：
  - 重新构建 xcframework（脚本会生成 `arm64 + x86_64` 模拟器切片）。
- TestFlight 上传成功但无法立即分发：
  - 构建仍在 App Store Connect 处理中。

## 致谢

- [Typst](https://github.com/typst/typst)：用于排版与 PDF 生成的核心引擎（Apache 2.0）
- [Catppuccin](https://github.com/catppuccin/catppuccin)：编辑器主题所使用的配色体系（MIT）
- [Source Han Sans](https://github.com/adobe-fonts/source-han-sans) / [Source Han Serif](https://github.com/adobe-fonts/source-han-serif)：应用内置的 CJK 字体资源（SIL Open Font License 1.1）
- [swift-bridge](https://github.com/chinedufn/swift-bridge)：Swift/Rust 互操作方案的重要参考（MIT 或 Apache-2.0）

## 特别感谢

- 感谢 [甜甜圈（Donut）](https://donutblogs.com/) 的所有伙伴给予的支持与启发。
