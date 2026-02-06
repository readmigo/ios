# Readmigo iOS

[![CI](https://github.com/readmigo/ios/actions/workflows/ci.yml/badge.svg)](https://github.com/readmigo/ios/actions/workflows/ci.yml)

Native iOS application for Readmigo - AI-powered English reading companion.

## Tech Stack

- **Language**: Swift
- **UI Framework**: SwiftUI
- **Minimum iOS**: 16.0
- **Architecture**: MVVM

## Features

- Immersive reading experience
- AI-powered word explanations and translations
- Text-to-Speech with sentence highlighting
- Offline reading support
- Vocabulary flashcards with spaced repetition
- Reading progress sync across devices

## Project Structure

```
├── Readmigo/
│   ├── App/             # App entry point
│   ├── Features/
│   │   ├── Auth/        # Authentication
│   │   ├── Library/     # Book library
│   │   ├── Reader/      # Reading experience
│   │   ├── Vocabulary/  # Vocabulary learning
│   │   └── Profile/     # User profile
│   ├── Core/            # Shared utilities
│   └── Resources/       # Assets and localization
└── Readmigo.xcodeproj
```

## Online Services

| Platform | Link |
|----------|------|
| App Store | [Readmigo on App Store](https://apps.apple.com/app/readmigo/id6740539519) |

## Development

```bash
# Open project in Xcode
open Readmigo.xcodeproj

# Build and run on simulator or device
# Xcode > Product > Run (⌘R)
```

## Bundle ID

- Production: `com.readmigo.app`
