import Foundation
import SwiftUI

/// ViewModel for message list view
@MainActor
class MessageListViewModel: ObservableObject {
    @Published var threads: [MessageThread] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasMore = true
    @Published var errorMessage: String?
    @Published var selectedStatus: ThreadStatus?
    @Published var searchText = ""

    private var currentPage = 1
    private let messagingService = MessagingService.shared

    /// Filtered threads based on search text
    var filteredThreads: [MessageThread] {
        if searchText.isEmpty {
            return threads
        }
        return threads.filter { thread in
            thread.subject.localizedCaseInsensitiveContains(searchText) ||
            thread.lastMessagePreview.localizedCaseInsensitiveContains(searchText)
        }
    }

    /// Load initial threads
    func loadThreads() async {
        isLoading = true
        currentPage = 1
        errorMessage = nil

        do {
            if AuthManager.shared.isAuthenticated {
                // Authenticated user: load message threads
                let response = try await messagingService.fetchThreads(page: 1, status: selectedStatus)
                threads = response.threads
                hasMore = response.hasMore
            } else {
                // Guest user: load guest feedback and convert to threads
                let response = try await messagingService.fetchGuestFeedbacks()
                threads = response.feedbacks.map { $0.toMessageThread() }
                hasMore = response.hasMore
            }
            currentPage = 1
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Load more threads (pagination)
    func loadMoreThreads() async {
        // Guest feedback doesn't support pagination currently
        guard AuthManager.shared.isAuthenticated else { return }
        guard !isLoadingMore && hasMore else { return }

        isLoadingMore = true

        do {
            let nextPage = currentPage + 1
            let response = try await messagingService.fetchThreads(page: nextPage, status: selectedStatus)
            threads.append(contentsOf: response.threads)
            hasMore = response.hasMore
            currentPage = nextPage
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingMore = false
    }

    /// Refresh threads
    func refresh() async {
        await loadThreads()
        if AuthManager.shared.isAuthenticated {
            try? await messagingService.fetchUnreadCount()
        }
    }

    /// Filter by status
    func filterByStatus(_ status: ThreadStatus?) {
        selectedStatus = status
        Task {
            await loadThreads()
        }
    }

    /// Clear error
    func clearError() {
        errorMessage = nil
    }
}
