import SwiftUI
import Kingfisher

// MARK: - Section Dispatcher

struct BookListStyleDispatcher: View {
    let list: BookList
    let styleIndex: Int

    var body: some View {
        switch styleIndex {
        case 0: GoldRankingSection(list: list)
        case 1: StepLadderSection(list: list)
        case 2: NeonSciFiSection(list: list)
        case 3: AdventureMapSection(list: list)
        case 4: ColorfulBubbleSection(list: list)
        case 5: MinimalStoneSection(list: list)
        case 6: DarkMysterySection(list: list)
        case 7: RoyalTheaterSection(list: list)
        case 8: BookSpineSection(list: list)
        case 9: DifficultyLadderSection(list: list)
        default: GoldRankingSection(list: list)
        }
    }
}

// MARK: - Shared Components

private struct BookListSectionHeader: View {
    let icon: String
    let title: String
    let listId: String
    var foregroundColor: Color = .primary

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.headline)
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)
            }
            .foregroundColor(foregroundColor)

            Spacer()

            NavigationLink {
                BookListDetailView(bookListId: listId)
            } label: {
                Text("查看全部")
                    .font(.subheadline)
                    .foregroundColor(foregroundColor.opacity(0.7))
            }
        }
        .padding(.horizontal)
    }
}

private struct BookCover: View {
    let url: String?
    let width: CGFloat
    let height: CGFloat
    var cornerRadius: CGFloat = 8

    var body: some View {
        if let coverUrl = url, let imageUrl = URL(string: coverUrl) {
            KFImage(imageUrl)
                .placeholder { _ in
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .overlay(Image(systemName: "book.closed.fill").foregroundColor(.gray.opacity(0.5)))
                }
                .fade(duration: 0.2)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: width, height: height)
                .cornerRadius(cornerRadius)
                .clipped()
        } else {
            Rectangle()
                .fill(Color(.systemGray5))
                .frame(width: width, height: height)
                .cornerRadius(cornerRadius)
                .overlay(Image(systemName: "book.closed.fill").foregroundColor(.gray.opacity(0.5)))
        }
    }
}

// MARK: - ① 金榜排行 (高分经典)

private struct GoldRankingSection: View {
    let list: BookList
    private var books: [BookListBook] { Array((list.books ?? []).prefix(8)) }

    var body: some View {
        VStack(spacing: 12) {
            BookListSectionHeader(icon: "chart.bar.fill", title: list.localizedTitle, listId: list.id)

            if !books.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(Array(books.enumerated()), id: \.element.id) { index, book in
                            NavigationLink { BookDetailView(book: book.toBook()) } label: {
                                VStack(spacing: 6) {
                                    ZStack(alignment: .topLeading) {
                                        BookCover(url: book.displayCoverUrl, width: 100, height: 150)

                                        // Gold rank badge
                                        Text("\(index + 1)")
                                            .font(.caption.bold())
                                            .foregroundColor(.white)
                                            .frame(width: 24, height: 24)
                                            .background(
                                                index < 3
                                                    ? Color.orange
                                                    : Color.gray.opacity(0.7)
                                            )
                                            .cornerRadius(6)
                                            .offset(x: -4, y: -4)
                                    }

                                    Text(book.title)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .lineLimit(1)
                                        .foregroundColor(.primary)

                                    Text(book.author)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                .frame(width: 100)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.vertical, 12)
        .background(
            LinearGradient(colors: [Color.orange.opacity(0.08), Color.clear], startPoint: .top, endPoint: .bottom)
        )
    }
}

// MARK: - ② 渐进阶梯 (入门推荐)

private struct StepLadderSection: View {
    let list: BookList
    private var books: [BookListBook] { Array((list.books ?? []).prefix(5)) }

    var body: some View {
        VStack(spacing: 12) {
            BookListSectionHeader(icon: "star.fill", title: list.localizedTitle, listId: list.id)

            if let subtitle = list.subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(spacing: 0) {
                ForEach(books) { book in
                    NavigationLink { BookDetailView(book: book.toBook()) } label: {
                        HStack(spacing: 12) {
                            BookCover(url: book.displayCoverUrl, width: 50, height: 75)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(book.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                    .foregroundColor(.primary)

                                Text(book.author)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            // Word count + difficulty bar
                            VStack(alignment: .trailing, spacing: 4) {
                                if let wc = book.formattedWordCount {
                                    Text(wc + " 字")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                DifficultyBar(score: book.difficultyScore)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)

                    if book.id != books.last?.id {
                        Divider().padding(.leading, 78)
                    }
                }
            }
            .background(Color(.systemGray6).opacity(0.5))
            .cornerRadius(12)
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
    }
}

private struct DifficultyBar: View {
    let score: Double?

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(barColor(for: i))
                    .frame(width: 8, height: 6)
            }
        }
    }

    private func barColor(for index: Int) -> Color {
        guard let score = score else { return Color(.systemGray4) }
        let filled = Int(score / 2)
        return index < filled ? .teal : Color(.systemGray4)
    }
}

// MARK: - ③ 暗色霓虹 (科幻经典)

private struct NeonSciFiSection: View {
    let list: BookList
    private var books: [BookListBook] { Array((list.books ?? []).prefix(8)) }

    var body: some View {
        VStack(spacing: 12) {
            BookListSectionHeader(icon: "sparkles", title: list.localizedTitle, listId: list.id, foregroundColor: .white)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(books) { book in
                        NavigationLink { BookDetailView(book: book.toBook()) } label: {
                            VStack(spacing: 6) {
                                BookCover(url: book.displayCoverUrl, width: 90, height: 135)
                                    .shadow(color: .purple.opacity(0.5), radius: 8, x: 0, y: 4)

                                Text(book.title)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                    .foregroundColor(.white)
                            }
                            .frame(width: 90)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.05, blue: 0.15), Color(red: 0.1, green: 0.05, blue: 0.2)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(16)
        .padding(.horizontal, 8)
    }
}

// MARK: - ④ 地图探险 (冒险故事)

private struct AdventureMapSection: View {
    let list: BookList
    private var books: [BookListBook] { Array((list.books ?? []).prefix(4)) }

    var body: some View {
        VStack(spacing: 12) {
            BookListSectionHeader(icon: "flame.fill", title: list.localizedTitle, listId: list.id)

            if !books.isEmpty {
                HStack(spacing: 12) {
                    // Large featured book
                    if let first = books.first {
                        NavigationLink { BookDetailView(book: first.toBook()) } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                BookCover(url: first.displayCoverUrl, width: 140, height: 210, cornerRadius: 12)
                                Text(first.title)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .lineLimit(2)
                                    .foregroundColor(.primary)
                                Text(first.author)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(width: 140)
                        }
                        .buttonStyle(.plain)
                    }

                    // Stacked list on the right
                    VStack(spacing: 0) {
                        ForEach(Array(books.dropFirst().enumerated()), id: \.element.id) { _, book in
                            NavigationLink { BookDetailView(book: book.toBook()) } label: {
                                HStack(spacing: 10) {
                                    BookCover(url: book.displayCoverUrl, width: 45, height: 68, cornerRadius: 6)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(book.title)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .lineLimit(2)
                                            .foregroundColor(.primary)
                                        Text(book.author)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        if let wc = book.formattedWordCount {
                                            Text(wc + " 字")
                                                .font(.caption2)
                                                .foregroundColor(.orange)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)

                            if book.id != books.last?.id {
                                Divider()
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 12)
        .background(
            LinearGradient(colors: [Color.brown.opacity(0.08), Color.clear], startPoint: .top, endPoint: .bottom)
        )
    }
}

// MARK: - ⑤ 彩色气泡 (儿童文学)

private struct ColorfulBubbleSection: View {
    let list: BookList
    private var books: [BookListBook] { Array((list.books ?? []).prefix(8)) }
    private let pastelColors: [Color] = [.pink, .mint, .cyan, .yellow, .purple, .orange, .green, .blue]

    var body: some View {
        VStack(spacing: 12) {
            BookListSectionHeader(icon: "leaf.fill", title: list.localizedTitle, listId: list.id)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(Array(books.enumerated()), id: \.element.id) { index, book in
                        NavigationLink { BookDetailView(book: book.toBook()) } label: {
                            VStack(spacing: 8) {
                                BookCover(url: book.displayCoverUrl, width: 90, height: 135, cornerRadius: 16)
                                    .shadow(color: pastelColors[index % pastelColors.count].opacity(0.3), radius: 6, x: 0, y: 4)

                                Text(book.title)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                    .foregroundColor(.primary)
                            }
                            .frame(width: 90)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [Color.pink.opacity(0.06), Color.mint.opacity(0.06), Color.cyan.opacity(0.06)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }
}

// MARK: - ⑥ 极简石刻 (哲学思想)

private struct MinimalStoneSection: View {
    let list: BookList
    private var books: [BookListBook] { Array((list.books ?? []).prefix(4)) }

    var body: some View {
        VStack(spacing: 12) {
            BookListSectionHeader(icon: "lightbulb.fill", title: list.localizedTitle, listId: list.id)

            VStack(spacing: 0) {
                ForEach(books) { book in
                    NavigationLink { BookDetailView(book: book.toBook()) } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(book.title)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                Text(book.author)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if let wc = book.formattedWordCount {
                                Text(wc + " 字")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)

                    if book.id != books.last?.id {
                        Divider().padding(.horizontal, 16)
                    }
                }
            }
            .background(Color(.systemGray6).opacity(0.6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 0.5)
            )
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
    }
}

// MARK: - ⑦ 暗色悬疑 (侦探推理)

private struct DarkMysterySection: View {
    let list: BookList
    private var books: [BookListBook] { Array((list.books ?? []).prefix(5)) }

    var body: some View {
        VStack(spacing: 12) {
            BookListSectionHeader(icon: "magnifyingglass", title: list.localizedTitle, listId: list.id, foregroundColor: .white)

            VStack(spacing: 0) {
                ForEach(Array(books.enumerated()), id: \.element.id) { index, book in
                    NavigationLink { BookDetailView(book: book.toBook()) } label: {
                        HStack(spacing: 12) {
                            // Gold number
                            Text("\(index + 1)")
                                .font(.title3.bold())
                                .foregroundColor(.yellow)
                                .frame(width: 28)

                            BookCover(url: book.displayCoverUrl, width: 45, height: 68, cornerRadius: 6)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(book.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Text(book.author)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)

                    if index < books.count - 1 {
                        Divider()
                            .background(Color.white.opacity(0.1))
                            .padding(.leading, 56)
                    }
                }
            }
        }
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                colors: [Color(red: 0.12, green: 0.08, blue: 0.18), Color(red: 0.06, green: 0.04, blue: 0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .padding(.horizontal, 8)
    }
}

// MARK: - ⑧ 皇家剧院 (莎士比亚)

private struct RoyalTheaterSection: View {
    let list: BookList
    private var books: [BookListBook] { list.books ?? [] }

    // Split into tragedy (first 4) and comedy (next 4+)
    private var tragedies: [BookListBook] { Array(books.prefix(4)) }
    private var comedies: [BookListBook] { Array(books.dropFirst(4).prefix(6)) }

    var body: some View {
        VStack(spacing: 12) {
            BookListSectionHeader(icon: "theatermasks.fill", title: list.localizedTitle, listId: list.id)

            VStack(alignment: .leading, spacing: 16) {
                // Tragedies row
                VStack(alignment: .leading, spacing: 8) {
                    Text("悲剧")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.red.opacity(0.8))
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(tragedies) { book in
                                NavigationLink { BookDetailView(book: book.toBook()) } label: {
                                    VStack(spacing: 4) {
                                        BookCover(url: book.displayCoverUrl, width: 75, height: 112, cornerRadius: 8)
                                        Text(book.title)
                                            .font(.caption2)
                                            .lineLimit(1)
                                            .foregroundColor(.primary)
                                    }
                                    .frame(width: 75)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // Comedies row
                VStack(alignment: .leading, spacing: 8) {
                    Text("喜剧")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.blue.opacity(0.8))
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(comedies) { book in
                                NavigationLink { BookDetailView(book: book.toBook()) } label: {
                                    VStack(spacing: 4) {
                                        BookCover(url: book.displayCoverUrl, width: 75, height: 112, cornerRadius: 8)
                                        Text(book.title)
                                            .font(.caption2)
                                            .lineLimit(1)
                                            .foregroundColor(.primary)
                                    }
                                    .frame(width: 75)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .padding(.vertical, 12)
        .background(
            LinearGradient(colors: [Color.purple.opacity(0.06), Color.yellow.opacity(0.04)], startPoint: .top, endPoint: .bottom)
        )
    }
}

// MARK: - ⑨ 书脊堆叠 (鸿篇巨制)

private struct BookSpineSection: View {
    let list: BookList
    private var books: [BookListBook] { list.books ?? [] }
    private let spineColors: [Color] = [.brown, .red, .blue, .green, .purple, .orange]

    var body: some View {
        VStack(spacing: 12) {
            BookListSectionHeader(icon: "book.fill", title: list.localizedTitle, listId: list.id)

            // Book spines visualization
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 3) {
                    ForEach(Array(books.enumerated()), id: \.element.id) { index, book in
                        NavigationLink { BookDetailView(book: book.toBook()) } label: {
                            VStack(spacing: 4) {
                                // Spine
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(spineColors[index % spineColors.count].gradient)
                                    .frame(width: spineWidth(for: book), height: 140)
                                    .overlay {
                                        // Vertical title
                                        Text(book.title)
                                            .font(.system(size: 9))
                                            .fontWeight(.medium)
                                            .foregroundColor(.white)
                                            .rotationEffect(.degrees(-90))
                                            .frame(width: 130)
                                            .lineLimit(1)
                                    }

                                Text(book.formattedWordCount ?? "")
                                    .font(.system(size: 8))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 12)
        .background(
            LinearGradient(colors: [Color.brown.opacity(0.06), Color.clear], startPoint: .bottom, endPoint: .top)
        )
    }

    private func spineWidth(for book: BookListBook) -> CGFloat {
        guard let wc = book.wordCount else { return 40 }
        let maxWC = (books.compactMap { $0.wordCount }.max() ?? 1_000_000)
        let ratio = CGFloat(wc) / CGFloat(maxWC)
        return max(30, ratio * 80)
    }
}

// MARK: - ⑩ 难度阶梯 (英语学习必读)

private struct DifficultyLadderSection: View {
    let list: BookList
    private var books: [BookListBook] {
        Array((list.books ?? []).sorted { ($0.difficultyScore ?? 0) < ($1.difficultyScore ?? 0) }.prefix(6))
    }

    var body: some View {
        VStack(spacing: 12) {
            BookListSectionHeader(icon: "graduationcap.fill", title: list.localizedTitle, listId: list.id)

            VStack(spacing: 0) {
                ForEach(books) { book in
                    NavigationLink { BookDetailView(book: book.toBook()) } label: {
                        HStack(spacing: 12) {
                            BookCover(url: book.displayCoverUrl, width: 45, height: 68, cornerRadius: 6)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(book.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                    .foregroundColor(.primary)
                                Text(book.author)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            // Difficulty indicator
                            VStack(alignment: .trailing, spacing: 2) {
                                if let score = book.difficultyScore {
                                    Text(String(format: "%.1f", score))
                                        .font(.caption.bold())
                                        .foregroundColor(difficultyColor(score))
                                }
                                DifficultyDots(score: book.difficultyScore)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)

                    if book.id != books.last?.id {
                        Divider().padding(.leading, 78)
                    }
                }
            }
            .background(Color(.systemGray6).opacity(0.5))
            .cornerRadius(12)
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(
            LinearGradient(colors: [Color.green.opacity(0.06), Color.clear], startPoint: .top, endPoint: .bottom)
        )
    }

    private func difficultyColor(_ score: Double) -> Color {
        switch score {
        case 0..<3: return .green
        case 3..<5: return .blue
        case 5..<7: return .orange
        default: return .red
        }
    }
}

private struct DifficultyDots: View {
    let score: Double?

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { i in
                Circle()
                    .fill(dotColor(for: i))
                    .frame(width: 6, height: 6)
            }
        }
    }

    private func dotColor(for index: Int) -> Color {
        guard let score = score else { return Color(.systemGray4) }
        let filled = Int(score / 2)
        return index < filled ? .green : Color(.systemGray4)
    }
}
