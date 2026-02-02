# Changelog

All notable changes to Readmigo iOS app will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.1.0] - 2026-02-02

### Added
- 🌐 Multi-language support for 11 languages:
  - English (en)
  - Simplified Chinese (zh-Hans)
  - Traditional Chinese (zh-Hant)
  - Spanish (es)
  - Arabic (ar)
  - Portuguese (pt)
  - Indonesian (id)
  - French (fr)
  - Japanese (ja)
  - Russian (ru)
  - Korean (ko)
- Complete localization for app interface (22 strings)
- Localized app name and privacy descriptions for all supported languages

### Changed
- Updated version to 2.1.0 (build 20260202)

## [2.0.2] - 2026-01-31

### Added
- Auto-trigger load more in bookstore with retry on failure

### Removed
- Total count header in bookstore
- Popular searches section

### Changed
- Removed tabs and show all books in single list
- Added independent search page with back button

## [2.0.1] - 2026-01-31

### Fixed
- Library cover image loading: fallback to coverUrl when coverThumbUrl returns 404
- Added loadDiskFileSynchronously to KFImage for instant cache loading
- Added loading indicator for chapter content in reader

### Changed
- Added export compliance flag to Info.plist

## [2.0.0] - 2026-01-29

### Added
- Initial release with major features

---

## Version Number Format

- **MARKETING_VERSION**: X.Y.Z (e.g., 2.1.0)
- **CURRENT_PROJECT_VERSION**: YYYYMMDD (e.g., 20260202)

## Links

- [App Store](https://apps.apple.com/app/readmigo)
- [App Store Connect](https://appstoreconnect.apple.com/apps/6740539519/appstore)
- [TestFlight](https://appstoreconnect.apple.com/apps/6740539519/testflight)
