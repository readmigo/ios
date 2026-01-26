import SwiftUI
import Kingfisher

// MARK: - AuthorAvatarView

struct AuthorAvatarView: View {
    let author: Author
    var size: CGFloat = 44

    // Predefined colors for avatar backgrounds
    private let avatarColors: [Color] = [
        Color(red: 0.91, green: 0.30, blue: 0.24), // Red
        Color(red: 0.90, green: 0.49, blue: 0.13), // Orange
        Color(red: 0.95, green: 0.77, blue: 0.06), // Yellow
        Color(red: 0.18, green: 0.80, blue: 0.44), // Green
        Color(red: 0.10, green: 0.74, blue: 0.61), // Teal
        Color(red: 0.20, green: 0.60, blue: 0.86), // Blue
        Color(red: 0.56, green: 0.27, blue: 0.68), // Purple
        Color(red: 0.91, green: 0.12, blue: 0.39), // Pink
    ]

    var body: some View {
        Group {
            if let avatarUrl = author.avatarUrl, let url = URL(string: avatarUrl) {
                KFImage(url)
                    .placeholder { _ in placeholderView }
                    .fade(duration: 0.25)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholderView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var placeholderView: some View {
        ZStack {
            Circle()
                .fill(avatarColors[author.avatarColorIndex])

            Text(author.initials)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Small Avatar (for comments)

struct SmallAvatarView: View {
    let userName: String
    let avatarUrl: String?
    var size: CGFloat = 28

    private let avatarColors: [Color] = [
        Color(red: 0.91, green: 0.30, blue: 0.24),
        Color(red: 0.90, green: 0.49, blue: 0.13),
        Color(red: 0.18, green: 0.80, blue: 0.44),
        Color(red: 0.20, green: 0.60, blue: 0.86),
        Color(red: 0.56, green: 0.27, blue: 0.68),
    ]

    private var initials: String {
        let parts = userName.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts.first?.prefix(1) ?? "")\(parts.last?.prefix(1) ?? "")".uppercased()
        }
        return String(userName.prefix(1)).uppercased()
    }

    private var colorIndex: Int {
        var hash = 0
        for char in userName.unicodeScalars {
            hash = Int(char.value) &+ (hash << 5) &- hash
        }
        return abs(hash) % avatarColors.count
    }

    var body: some View {
        Group {
            if let avatarUrl = avatarUrl, let url = URL(string: avatarUrl) {
                KFImage(url)
                    .placeholder { _ in placeholderView }
                    .fade(duration: 0.25)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholderView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var placeholderView: some View {
        ZStack {
            Circle()
                .fill(avatarColors[colorIndex])

            Text(initials)
                .font(.system(size: size * 0.45, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}

