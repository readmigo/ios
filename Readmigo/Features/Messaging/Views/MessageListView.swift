import SwiftUI

/// Message list view (消息中心)
struct MessageListView: View {
    @StateObject private var viewModel = MessageListViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showNewMessage = false
    @State private var selectedThread: MessageThread?

    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading && viewModel.threads.isEmpty {
                    ProgressView()
                } else if viewModel.threads.isEmpty {
                    emptyStateView
                } else {
                    threadListView
                }
            }
            .navigationTitle("messaging.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showNewMessage = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .sheet(isPresented: $showNewMessage) {
                NewMessageView { thread in
                    showNewMessage = false
                    selectedThread = thread
                }
            }
            .navigationDestination(item: $selectedThread) { thread in
                MessageThreadView(threadId: thread.id)
            }
            .alert("Error", isPresented: .init(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.clearError() } }
            )) {
                Button("OK") { viewModel.clearError() }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .task {
                await viewModel.loadThreads()
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var threadListView: some View {
        List {
            // Status filter
            statusFilterView

            // Thread list
            ForEach(viewModel.filteredThreads) { thread in
                Button {
                    selectedThread = thread
                } label: {
                    MessagePreviewCard(thread: thread)
                }
                .buttonStyle(.plain)
                .onAppear {
                    // Load more when reaching end
                    if thread.id == viewModel.filteredThreads.last?.id {
                        Task {
                            await viewModel.loadMoreThreads()
                        }
                    }
                }
            }

            // Loading more indicator
            if viewModel.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            }

            // End of list
            if !viewModel.hasMore && !viewModel.threads.isEmpty {
                HStack {
                    Spacer()
                    Text("No more messages")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .searchable(text: $viewModel.searchText, prompt: "Search messages...")
    }

    @ViewBuilder
    private var statusFilterView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                MessagingFilterChip(
                    title: "All",
                    isSelected: viewModel.selectedStatus == nil
                ) {
                    viewModel.filterByStatus(nil)
                }

                ForEach([ThreadStatus.open, .replied, .closed], id: \.self) { status in
                    MessagingFilterChip(
                        title: status.localizedNameKey.localized,
                        isSelected: viewModel.selectedStatus == status
                    ) {
                        viewModel.filterByStatus(status)
                    }
                }
            }
            .padding(.horizontal)
        }
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("messaging.noMessages".localized)
                .font(.headline)
                .foregroundColor(.secondary)

            Button {
                showNewMessage = true
            } label: {
                Label("messaging.newMessage".localized, systemImage: "plus")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .cornerRadius(24)
            }
        }
        .padding()
    }
}

/// Filter chip component for messaging
private struct MessagingFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color(.systemGray5))
                .cornerRadius(20)
        }
    }
}
