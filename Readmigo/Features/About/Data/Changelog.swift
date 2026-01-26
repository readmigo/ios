import Foundation

/// Changelog data
struct Changelog {
    static let entries: [ChangelogEntry] = [
        ChangelogEntry(
            version: "1.0.0",
            date: createDate(year: 2024, month: 12),
            changes: [
                LocalizedChange(
                    en: "Initial release",
                    zhHans: "首次发布",
                    zhHant: "首次發布"
                ),
                LocalizedChange(
                    en: "AI-powered vocabulary learning",
                    zhHans: "AI 驱动的词汇学习",
                    zhHant: "AI 驅動的詞彙學習"
                ),
                LocalizedChange(
                    en: "EPUB reader with immersive mode",
                    zhHans: "支持沉浸式阅读的 EPUB 阅读器",
                    zhHant: "支持沉浸式閱讀的 EPUB 閱讀器"
                ),
                LocalizedChange(
                    en: "English, Simplified Chinese, and Traditional Chinese support",
                    zhHans: "支持英文、简体中文和繁体中文",
                    zhHant: "支持英文、簡體中文和繁體中文"
                ),
                LocalizedChange(
                    en: "Spaced repetition vocabulary review",
                    zhHans: "间隔重复词汇复习",
                    zhHant: "間隔重複詞彙複習"
                ),
                LocalizedChange(
                    en: "Cloud sync across devices",
                    zhHans: "跨设备云同步",
                    zhHant: "跨設備雲同步"
                )
            ]
        )
    ]

    private static func createDate(year: Int, month: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        return Calendar.current.date(from: components) ?? Date()
    }
}
