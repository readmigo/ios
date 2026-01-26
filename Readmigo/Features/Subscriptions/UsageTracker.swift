import Foundation

@MainActor
class UsageTracker: ObservableObject {
    static let shared = UsageTracker()

    // MARK: - Published Properties

    @Published private(set) var aiCallsToday: Int = 0
    @Published private(set) var vocabularyCount: Int = 0
    @Published private(set) var offlineDownloadCount: Int = 0
    @Published private(set) var voiceChatMinutesThisMonth: Int = 0
    @Published private(set) var booksReadCount: Int = 0

    // MARK: - Storage Keys

    private let aiCallsKey = "usage_ai_calls"
    private let aiCallsDateKey = "usage_ai_calls_date"
    private let voiceChatKey = "usage_voice_chat"
    private let voiceChatMonthKey = "usage_voice_chat_month"
    private let vocabularyCountKey = "usage_vocabulary_count"
    private let offlineCountKey = "usage_offline_count"
    private let booksReadKey = "usage_books_read"

    // MARK: - Init

    private init() {
        loadLocalUsage()
    }

    // MARK: - Load Local Usage

    func loadLocalUsage() {
        // AI 调用次数 (检查是否是今天)
        let savedDate = UserDefaults.standard.string(forKey: aiCallsDateKey) ?? ""
        let today = dateString(from: Date())

        if savedDate == today {
            aiCallsToday = UserDefaults.standard.integer(forKey: aiCallsKey)
        } else {
            aiCallsToday = 0
            UserDefaults.standard.set(today, forKey: aiCallsDateKey)
            UserDefaults.standard.set(0, forKey: aiCallsKey)
        }

        // 语音聊天分钟数 (检查是否是本月)
        let savedMonth = UserDefaults.standard.string(forKey: voiceChatMonthKey) ?? ""
        let currentMonth = monthString(from: Date())

        if savedMonth == currentMonth {
            voiceChatMinutesThisMonth = UserDefaults.standard.integer(forKey: voiceChatKey)
        } else {
            voiceChatMinutesThisMonth = 0
            UserDefaults.standard.set(currentMonth, forKey: voiceChatMonthKey)
            UserDefaults.standard.set(0, forKey: voiceChatKey)
        }

        // 其他计数
        vocabularyCount = UserDefaults.standard.integer(forKey: vocabularyCountKey)
        offlineDownloadCount = UserDefaults.standard.integer(forKey: offlineCountKey)
        booksReadCount = UserDefaults.standard.integer(forKey: booksReadKey)
    }

    // MARK: - Sync from Server

    func syncFromServer() async {
        do {
            let response: UsageResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.usageCurrent
            )

            await MainActor.run {
                self.aiCallsToday = response.aiCallsToday
                self.vocabularyCount = response.vocabularyCount
                self.offlineDownloadCount = response.offlineDownloadCount
                self.voiceChatMinutesThisMonth = response.voiceChatMinutesThisMonth
                self.booksReadCount = response.booksReadCount

                // 保存到本地
                self.saveToLocal()
            }
        } catch {
            print("Failed to sync usage: \(error)")
        }
    }

    // MARK: - Record Usage

    func recordAICall() {
        aiCallsToday += 1
        UserDefaults.standard.set(aiCallsToday, forKey: aiCallsKey)

        Task {
            do {
                let _: EmptyResponse = try await APIClient.shared.request(
                    endpoint: APIEndpoints.usageAI,
                    method: .post
                )
            } catch {
                print("Failed to record AI usage: \(error)")
            }
        }
    }

    func recordVoiceChatMinutes(_ minutes: Int) {
        voiceChatMinutesThisMonth += minutes
        UserDefaults.standard.set(voiceChatMinutesThisMonth, forKey: voiceChatKey)

        Task {
            do {
                let _: EmptyResponse = try await APIClient.shared.request(
                    endpoint: APIEndpoints.usageVoiceChat,
                    method: .post,
                    body: ["minutes": minutes]
                )
            } catch {
                print("Failed to record voice chat usage: \(error)")
            }
        }
    }

    func updateVocabularyCount(_ count: Int) {
        vocabularyCount = count
        UserDefaults.standard.set(count, forKey: vocabularyCountKey)
    }

    func incrementVocabularyCount() {
        vocabularyCount += 1
        UserDefaults.standard.set(vocabularyCount, forKey: vocabularyCountKey)
    }

    func updateOfflineDownloadCount(_ count: Int) {
        offlineDownloadCount = count
        UserDefaults.standard.set(count, forKey: offlineCountKey)
    }

    func incrementOfflineDownloadCount() {
        offlineDownloadCount += 1
        UserDefaults.standard.set(offlineDownloadCount, forKey: offlineCountKey)
    }

    func decrementOfflineDownloadCount() {
        if offlineDownloadCount > 0 {
            offlineDownloadCount -= 1
            UserDefaults.standard.set(offlineDownloadCount, forKey: offlineCountKey)
        }
    }

    func updateBooksReadCount(_ count: Int) {
        booksReadCount = count
        UserDefaults.standard.set(count, forKey: booksReadKey)
    }

    // MARK: - Reset (for testing)

    func resetDailyUsage() {
        aiCallsToday = 0
        UserDefaults.standard.set(0, forKey: aiCallsKey)
        UserDefaults.standard.set(dateString(from: Date()), forKey: aiCallsDateKey)
    }

    func resetMonthlyUsage() {
        voiceChatMinutesThisMonth = 0
        UserDefaults.standard.set(0, forKey: voiceChatKey)
        UserDefaults.standard.set(monthString(from: Date()), forKey: voiceChatMonthKey)
    }

    // MARK: - Helpers

    private func saveToLocal() {
        UserDefaults.standard.set(aiCallsToday, forKey: aiCallsKey)
        UserDefaults.standard.set(dateString(from: Date()), forKey: aiCallsDateKey)
        UserDefaults.standard.set(voiceChatMinutesThisMonth, forKey: voiceChatKey)
        UserDefaults.standard.set(monthString(from: Date()), forKey: voiceChatMonthKey)
        UserDefaults.standard.set(vocabularyCount, forKey: vocabularyCountKey)
        UserDefaults.standard.set(offlineDownloadCount, forKey: offlineCountKey)
        UserDefaults.standard.set(booksReadCount, forKey: booksReadKey)
    }

    private func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func monthString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }
}

