import SwiftUI

// MARK: - Bookstore Tab Bar

struct BookstoreTabBar: View {
    let tabs: [BookstoreTab]
    @Binding var selectedTabId: String
    let onTabSelected: (String) -> Void

    /// Effective selected tab ID - uses first tab if selectedTabId is empty
    private var effectiveSelectedId: String {
        selectedTabId.isEmpty ? (tabs.first?.id ?? "") : selectedTabId
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tabs) { tab in
                        BookstoreTabItem(
                            tab: tab,
                            isSelected: tab.id == effectiveSelectedId
                        ) {
                            // Only call the callback - let ViewModel update selectedTabId
                            // This prevents the race condition where binding updates before selectTab runs
                            onTabSelected(tab.id)
                        }
                        .id(tab.id)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .onChange(of: selectedTabId) { _, newValue in
                withAnimation {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Tab Item

private struct BookstoreTabItem: View {
    let tab: BookstoreTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: tab.sfSymbolName)
                    .font(.subheadline)

                Text(tab.displayName)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ? Color.accentColor : Color(.systemGray5))
            )
        }
        .buttonStyle(.plain)
    }
}
