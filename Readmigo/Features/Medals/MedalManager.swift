import Foundation
import SwiftUI

@MainActor
class MedalManager: ObservableObject {
    static let shared = MedalManager()

    // MARK: - Published Properties

    @Published var allMedals: [Medal] = []
    @Published var unlockedMedals: [UserMedal] = []
    @Published var progress: [String: MedalProgress] = [:]
    @Published var stats: MedalStats?
    @Published var newlyUnlocked: [UserMedal] = []  // For showing unlock animations
    @Published var isLoading = false
    @Published var error: String?

    // MARK: - Computed Properties

    var totalUnlocked: Int { unlockedMedals.count }
    var totalMedals: Int { allMedals.count }

    var unlockedMedalIds: Set<String> {
        Set(unlockedMedals.map { $0.medalId })
    }

    var unlockedByRarity: [MedalRarity: Int] {
        var result: [MedalRarity: Int] = [:]
        for rarity in MedalRarity.allCases {
            result[rarity] = unlockedMedals.filter { $0.medal.rarity == rarity }.count
        }
        return result
    }

    var unlockedByCategory: [MedalCategory: Int] {
        var result: [MedalCategory: Int] = [:]
        for category in MedalCategory.allCases {
            result[category] = unlockedMedals.filter { $0.medal.category == category }.count
        }
        return result
    }

    var totalByCategory: [MedalCategory: Int] {
        var result: [MedalCategory: Int] = [:]
        for category in MedalCategory.allCases {
            result[category] = allMedals.filter { $0.category == category }.count
        }
        return result
    }

    var displayedMedals: [UserMedal] {
        unlockedMedals
            .filter { $0.isDisplayed }
            .sorted { ($0.displayOrder ?? 0) < ($1.displayOrder ?? 0) }
    }

    var inProgressMedals: [(medal: Medal, progress: MedalProgress)] {
        allMedals.compactMap { medal in
            guard !isUnlocked(medal.id),
                  let medalProgress = progress[medal.code],
                  medalProgress.currentValue > 0 else { return nil }
            return (medal: medal, progress: medalProgress)
        }.sorted { $0.progress.percentage > $1.progress.percentage }
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - API Methods

    /// Load all medals and user data
    func loadMedals() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            async let medalsTask: MedalsResponse = APIClient.shared.request(
                endpoint: APIEndpoints.medals
            )
            async let userMedalsTask: UserMedalsResponse = APIClient.shared.request(
                endpoint: APIEndpoints.medalsUser
            )

            let (medalsResponse, userMedalsResponse) = try await (medalsTask, userMedalsTask)

            self.allMedals = medalsResponse.medals.sorted { $0.displayOrder < $1.displayOrder }
            self.unlockedMedals = userMedalsResponse.unlocked
            self.progress = Dictionary(
                uniqueKeysWithValues: userMedalsResponse.progress.map { ($0.medalCode, $0) }
            )
            self.stats = userMedalsResponse.stats
        } catch {
            self.error = error.localizedDescription
            print("Failed to load medals: \(error)")
        }
    }

    /// Refresh all medal data
    func refreshAll() async {
        await loadMedals()
    }

    /// Check for new medal unlocks
    func checkForNewMedals() async {
        do {
            let response: CheckMedalsResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.medalsCheck,
                method: .post
            )

            if !response.newlyUnlocked.isEmpty {
                // Update local data
                self.unlockedMedals.append(contentsOf: response.newlyUnlocked)

                // Trigger unlock animations
                self.newlyUnlocked = response.newlyUnlocked

                // Show unlock animation for each new medal
                await showUnlockAnimations(for: response.newlyUnlocked)
            }

            // Update progress
            for updatedProgress in response.updatedProgress {
                self.progress[updatedProgress.medalCode] = updatedProgress
            }
        } catch {
            print("Failed to check medals: \(error)")
        }
    }

    /// Get medal detail
    func getMedalDetail(medalId: String) async -> MedalDetailResponse? {
        do {
            let response: MedalDetailResponse = try await APIClient.shared.request(
                endpoint: "\(APIEndpoints.medals)/\(medalId)"
            )
            return response
        } catch {
            print("Failed to get medal detail: \(error)")
            return nil
        }
    }

    /// Set displayed medals on profile
    func setDisplayedMedals(_ medalIds: [String]) async throws {
        let _: EmptyResponse = try await APIClient.shared.request(
            endpoint: APIEndpoints.medalsDisplay,
            method: .put,
            body: SetDisplayMedalsRequest(medalIds: medalIds)
        )

        // Update local state
        for i in unlockedMedals.indices {
            let isDisplayed = medalIds.contains(unlockedMedals[i].medalId)
            let displayOrder = medalIds.firstIndex(of: unlockedMedals[i].medalId)

            // Create updated medal
            unlockedMedals[i] = UserMedal(
                id: unlockedMedals[i].id,
                userId: unlockedMedals[i].userId,
                medalId: unlockedMedals[i].medalId,
                medal: unlockedMedals[i].medal,
                unlockedAt: unlockedMedals[i].unlockedAt,
                unlockedValue: unlockedMedals[i].unlockedValue,
                isDisplayed: isDisplayed,
                displayOrder: displayOrder
            )
        }
    }

    // MARK: - Query Methods

    /// Get medal by ID
    func getMedal(by id: String) -> Medal? {
        allMedals.first { $0.id == id }
    }

    /// Get medal by code
    func getMedal(byCode code: String) -> Medal? {
        allMedals.first { $0.code == code }
    }

    /// Check if medal is unlocked
    func isUnlocked(_ medalId: String) -> Bool {
        unlockedMedalIds.contains(medalId)
    }

    /// Get progress for a medal
    func getProgress(for medalCode: String) -> MedalProgress? {
        progress[medalCode]
    }

    /// Get user medal (if unlocked)
    func getUserMedal(for medalId: String) -> UserMedal? {
        unlockedMedals.first { $0.medalId == medalId }
    }

    /// Get medals by category
    func getMedals(for category: MedalCategory) -> [Medal] {
        allMedals.filter { $0.category == category }
    }

    /// Get medals by rarity
    func getMedals(for rarity: MedalRarity) -> [Medal] {
        allMedals.filter { $0.rarity == rarity }
    }

    /// Get limited edition medals
    func getLimitedMedals() -> [Medal] {
        allMedals.filter { $0.isLimited }
    }

    /// Get active limited edition medals (within time range)
    func getActiveLimitedMedals() -> [Medal] {
        let now = Date()
        return allMedals.filter { medal in
            guard medal.isLimited else { return false }
            if let start = medal.limitedStartAt, now < start { return false }
            if let end = medal.limitedEndAt, now > end { return false }
            return true
        }
    }

    // MARK: - Animation

    private func showUnlockAnimations(for medals: [UserMedal]) async {
        for medal in medals {
            // Post notification for UI to show unlock animation
            NotificationCenter.default.post(
                name: .medalUnlocked,
                object: medal
            )

            // Wait for animation to complete (approximately 2.5 seconds per medal)
            try? await Task.sleep(nanoseconds: 2_500_000_000)
        }

        // Clear newly unlocked list
        newlyUnlocked = []
    }

    /// Clear a specific newly unlocked medal (called when animation completes)
    func clearNewlyUnlocked(_ medalId: String) {
        newlyUnlocked.removeAll { $0.medalId == medalId }
    }

    /// Clear all newly unlocked medals
    func clearAllNewlyUnlocked() {
        newlyUnlocked = []
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let medalUnlocked = Notification.Name("medalUnlocked")
}

// MARK: - API Endpoints Extension

extension APIEndpoints {
    static let medals = "/medals"
    static let medalsUser = "/medals/user"
    static let medalsCheck = "/medals/check"
    static let medalsDisplay = "/medals/display"
}

// MARK: - Empty Response

struct EmptyResponse: Codable {}
