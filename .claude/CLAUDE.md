# Readmigo iOS Project Guidelines

## Project Overview

Native iOS app built with Swift and SwiftUI.

## Project Structure

```
├── Readmigo/
│   ├── App/              # Application entry
│   ├── Features/         # Feature modules
│   │   ├── Reader/       # Book reading feature
│   │   ├── Library/      # Book library
│   │   └── ...
│   ├── Core/             # Core utilities
│   └── Resources/        # Assets and configs
└── Readmigo.xcodeproj    # Xcode project
```

## Development Rules

### iOS Auto-Deployment

Every time iOS code is modified, automatically compile, install, and launch to connected real device:

- Target Device: 郭宏斌的iPhone (Device ID: 00008030-001A4D290AE8802E)
- Build Command: `xcodebuild -project Readmigo.xcodeproj -scheme Readmigo -destination 'platform=iOS,id=00008030-001A4D290AE8802E' -quiet build`
- Install Command: `xcrun devicectl device install app --device 00008030-001A4D290AE8802E <app_path>`
- Launch Command: `xcrun devicectl device process launch --device 00008030-001A4D290AE8802E com.readmigo.app`

### Key Information

- Bundle ID: `com.readmigo.app`
- 阅读器主文件: `Readmigo/Features/Reader/EnhancedReaderView.swift`（不是 ReaderView.swift）
- 项目路径: `Readmigo/`（源码），`Readmigo.xcodeproj`（项目文件）

### Reader Sync Requirements

iOS 阅读器需与 Content Studio 的 reader-template 保持同步：
- iOS 位置: `Readmigo/Features/Reader/ReaderContentView.swift`
- 任何样式或行为变化必须同时更新两处

## Investigation & Problem Analysis

When investigating problems, output using this template:
```
问题的原因：xxx
解决的思路：xxx
修复的方案：xxx
```

## Online Services

| Platform | URL |
|----------|-----|
| App Store | https://apps.apple.com/app/readmigo |
