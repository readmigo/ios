import SwiftUI

struct QuotesView: View {
    @StateObject private var manager = QuotesManager.shared
    @EnvironmentObject var authManager: AuthManager
    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var selectedQuote: Quote?
    @State private var showingDetail = false
    @State private var showLoginPrompt = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Daily Quote Section
                    if let dailyQuote = manager.dailyQuote {
                        VStack(alignment: .leading, spacing: 12) {
                            DailyQuoteCardView(
                                quote: dailyQuote,
                                onLike: {
                                    guard requireLoginForLike() else { return }
                                    Task { await manager.toggleLike(quote: dailyQuote) }
                                },
                                onShare: {
                                    shareQuote(dailyQuote)
                                }
                            )
                            .onTapGesture {
                                selectedQuote = dailyQuote
                                showingDetail = true
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Trending Section
                    if !manager.trendingQuotes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("quotes.trending".localized)
                                    .font(.title3)
                                    .fontWeight(.bold)
                                Spacer()
                            }
                            .padding(.horizontal)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(manager.trendingQuotes) { quote in
                                        QuoteCardView(
                                            quote: quote,
                                            onLike: {
                                                guard requireLoginForLike() else { return }
                                                Task { await manager.toggleLike(quote: quote) }
                                            },
                                            onShare: {
                                                shareQuote(quote)
                                            },
                                            onTap: {
                                                selectedQuote = quote
                                                showingDetail = true
                                            }
                                        )
                                        .frame(width: 300)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }

                    // Filter Tabs
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("quotes.browse".localized)
                                .font(.title3)
                                .fontWeight(.bold)
                            Spacer()
                        }
                        .padding(.horizontal)

                        // Tags filter
                        if !manager.availableTags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    TagChip(title: "common.all".localized, isSelected: selectedTab == 0) {
                                        selectedTab = 0
                                        Task { await manager.fetchQuotes() }
                                    }

                                    ForEach(Array(manager.availableTags.enumerated()), id: \.element) { index, tag in
                                        TagChip(title: tag, isSelected: selectedTab == index + 1) {
                                            selectedTab = index + 1
                                            Task { await manager.fetchQuotes(tag: tag) }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }

                    // Quotes List
                    LazyVStack(spacing: 16) {
                        ForEach(manager.quotes) { quote in
                            QuoteCardView(
                                quote: quote,
                                onLike: {
                                    guard requireLoginForLike() else { return }
                                    Task { await manager.toggleLike(quote: quote) }
                                },
                                onShare: {
                                    shareQuote(quote)
                                },
                                onTap: {
                                    selectedQuote = quote
                                    showingDetail = true
                                }
                            )
                            .padding(.horizontal)
                            .onAppear {
                                Task { await manager.loadMoreIfNeeded(currentItem: quote) }
                            }
                        }

                        if manager.isLoading {
                            ProgressView()
                                .padding()
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("nav.quotes".localized)
            .searchable(text: $searchText, prompt: "quotes.searchPrompt".localized)
            .onSubmit(of: .search) {
                Task { await manager.fetchQuotes(search: searchText) }
            }
            .elegantRefreshable {
                await refreshData()
            }
            .sheet(isPresented: $showingDetail) {
                if let quote = selectedQuote {
                    QuoteDetailView(quote: quote)
                }
            }
            .task {
                await refreshData()
            }
            .loginPrompt(isPresented: $showLoginPrompt, feature: "like")
        }
    }

    // MARK: - Guest Mode Helpers

    private func requireLoginForLike() -> Bool {
        if authManager.isAuthenticated {
            return true
        } else {
            showLoginPrompt = true
            return false
        }
    }

    private func refreshData() async {
        await manager.fetchDailyQuote()
        await manager.fetchTrendingQuotes()
        await manager.fetchTags()
        await manager.fetchQuotes()
    }

    private func shareQuote(_ quote: Quote) {
        let text = "\"\(quote.text)\"\n— \(quote.author)"
        let activityVC = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - Tag Chip

struct TagChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}
