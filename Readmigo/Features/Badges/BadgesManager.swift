import Foundation

@MainActor
class BadgesManager: ObservableObject {
    static let shared = BadgesManager()

    @Published var allBadges: [Badge] = []
    @Published var earnedBadges: [UserBadge] = []
    @Published var badgeProgress: [BadgeProgress] = []
    @Published var isLoading = false
    @Published var error: String?

    private init() {}

    // MARK: - Computed Properties

    var earnedBadgeIds: Set<String> {
        Set(earnedBadges.map { $0.badge.id })
    }

    var unearnedBadges: [Badge] {
        allBadges.filter { !earnedBadgeIds.contains($0.id) }
    }

    var inProgressBadges: [BadgeProgress] {
        badgeProgress.filter { !$0.isComplete && $0.currentValue > 0 }
    }

    var badgesByCategory: [BadgeCategory: [Badge]] {
        Dictionary(grouping: allBadges, by: { $0.category })
    }

    var earnedBadgesByCategory: [BadgeCategory: [UserBadge]] {
        Dictionary(grouping: earnedBadges, by: { $0.badge.category })
    }

    // MARK: - Fetch All Badges

    func fetchAllBadges() async {
        isLoading = true
        error = nil

        do {
            let response: BadgesResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.badges
            )
            allBadges = response.badges
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Fetch Earned Badges

    func fetchEarnedBadges() async {
        isLoading = true
        error = nil

        do {
            let response: UserBadgesResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.badgesUser
            )
            earnedBadges = response.badges
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Fetch Badge Progress

    func fetchBadgeProgress() async {
        do {
            let response: BadgeProgressResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.badgesProgress
            )
            badgeProgress = response.progress
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Refresh All Data

    func refreshAll() async {
        isLoading = true
        error = nil

        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchAllBadges() }
            group.addTask { await self.fetchEarnedBadges() }
            group.addTask { await self.fetchBadgeProgress() }
        }

        isLoading = false
    }

    // MARK: - Check if Badge is Earned

    func isEarned(_ badge: Badge) -> Bool {
        earnedBadgeIds.contains(badge.id)
    }

    // MARK: - Get Progress for Badge

    func progress(for badge: Badge) -> BadgeProgress? {
        badgeProgress.first { $0.badge.id == badge.id }
    }

    // MARK: - Get User Badge

    func userBadge(for badge: Badge) -> UserBadge? {
        earnedBadges.first { $0.badge.id == badge.id }
    }
}
