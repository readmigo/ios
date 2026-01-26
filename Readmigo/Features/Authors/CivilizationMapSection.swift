import SwiftUI
import Kingfisher

// MARK: - Civilization Map Section

/// 文明地图 - 展示作者在文学史中的位置
struct CivilizationMapSection: View {
    let civilizationMap: CivilizationMap
    let authorName: String
    let authorEra: String?

    var body: some View {
        VStack(spacing: 16) {
            // Literary Position Card
            LiteraryPositionCard(civilizationMap: civilizationMap)

            // Influence Network
            InfluenceNetworkCard(
                influences: civilizationMap.influences,
                authorName: authorName,
                authorEra: authorEra
            )

            // Cross-Domain Contributions
            if let domains = civilizationMap.domains, !domains.isEmpty {
                CrossDomainCard(domains: domains)
            }

            // Historical Context
            if let historicalContext = civilizationMap.historicalContext, !historicalContext.isEmpty {
                HistoricalContextCard(events: historicalContext)
            }
        }
    }
}

// MARK: - Literary Position Card

/// 文学坐标卡片
struct LiteraryPositionCard: View {
    let civilizationMap: CivilizationMap

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "globe")
                    .foregroundColor(.blue)
                Text("civilizationMap.literaryPosition".localized)
                    .font(.headline)
            }

            // Literary Movement & Historical Period
            HStack(spacing: 16) {
                if let movement = civilizationMap.literaryMovement {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("civilizationMap.literaryMovement".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(movement)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let period = civilizationMap.historicalPeriod {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("civilizationMap.historicalPeriod".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(period)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            // Primary Genres
            if let genres = civilizationMap.primaryGenres, !genres.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("civilizationMap.primaryGenres".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    FlowLayout(spacing: 8) {
                        ForEach(genres, id: \.self) { genre in
                            Text(genre)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(12)
                        }
                    }
                }
            }

            // Core Themes
            if let themes = civilizationMap.themes, !themes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("civilizationMap.themes".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    FlowLayout(spacing: 8) {
                        ForEach(themes, id: \.self) { theme in
                            Text(theme)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(.systemGray5))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(.systemGray4), lineWidth: 1)
                                )
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Influence Network Card

/// 影响网络卡片
struct InfluenceNetworkCard: View {
    let influences: InfluenceNetwork
    let authorName: String
    let authorEra: String?

    private let avatarColors: [Color] = [
        Color(red: 0.91, green: 0.30, blue: 0.24),
        Color(red: 0.90, green: 0.49, blue: 0.13),
        Color(red: 0.18, green: 0.80, blue: 0.44),
        Color(red: 0.20, green: 0.60, blue: 0.86),
        Color(red: 0.56, green: 0.27, blue: 0.68),
        Color(red: 0.10, green: 0.74, blue: 0.61),
        Color(red: 0.95, green: 0.77, blue: 0.06),
        Color(red: 0.40, green: 0.50, blue: 0.60),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.purple)
                Text("civilizationMap.influenceNetwork".localized)
                    .font(.headline)
            }

            // Predecessors
            if !influences.predecessors.isEmpty {
                InfluenceSectionRow(
                    title: "civilizationMap.predecessors".localized,
                    subtitle: "civilizationMap.predecessors.subtitle".localized,
                    authors: influences.predecessors,
                    icon: "arrow.right",
                    iconColor: .blue,
                    avatarColors: avatarColors
                )
            }

            // Current Author - Center
            HStack {
                Spacer()
                VStack(spacing: 4) {
                    Text(authorName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    if let era = authorEra {
                        Text(era)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.blue.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.blue, lineWidth: 2)
                )
                .cornerRadius(20)
                Spacer()
            }
            .padding(.vertical, 8)

            // Successors
            if !influences.successors.isEmpty {
                InfluenceSectionRow(
                    title: "civilizationMap.successors".localized,
                    subtitle: "civilizationMap.successors.subtitle".localized,
                    authors: influences.successors,
                    icon: "arrow.left",
                    iconColor: .green,
                    avatarColors: avatarColors
                )
            }

            // Contemporaries
            if !influences.contemporaries.isEmpty {
                InfluenceSectionRow(
                    title: "civilizationMap.contemporaries".localized,
                    subtitle: "civilizationMap.contemporaries.subtitle".localized,
                    authors: influences.contemporaries,
                    icon: "person.2",
                    iconColor: .purple,
                    avatarColors: avatarColors
                )
            }

            // Mentors
            if let mentors = influences.mentors, !mentors.isEmpty {
                InfluenceSectionRow(
                    title: "civilizationMap.mentors".localized,
                    subtitle: "civilizationMap.mentors.subtitle".localized,
                    authors: mentors,
                    icon: "graduationcap.fill",
                    iconColor: .orange,
                    avatarColors: avatarColors
                )
            }

            // Students
            if let students = influences.students, !students.isEmpty {
                InfluenceSectionRow(
                    title: "civilizationMap.students".localized,
                    subtitle: "civilizationMap.students.subtitle".localized,
                    authors: students,
                    icon: "book.fill",
                    iconColor: .cyan,
                    avatarColors: avatarColors
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Influence Section Row

/// 单个影响类别行
struct InfluenceSectionRow: View {
    let title: String
    let subtitle: String
    let authors: [AuthorLink]
    let icon: String
    let iconColor: Color
    let avatarColors: [Color]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(iconColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Authors scroll view
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(authors) { author in
                        AuthorLinkCard(author: author, avatarColors: avatarColors)
                    }
                }
            }
        }
    }
}

// MARK: - Author Link Card

/// 作家链接卡片
struct AuthorLinkCard: View {
    let author: AuthorLink
    let avatarColors: [Color]

    var body: some View {
        NavigationLink {
            AuthorProfileView(authorId: author.id)
        } label: {
            HStack(spacing: 12) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(avatarColors[author.avatarColorIndex])
                        .frame(width: 40, height: 40)

                    if let avatarUrl = author.avatarUrl, let url = URL(string: avatarUrl) {
                        KFImage(url)
                            .placeholder {
                                Text(author.initials)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                    } else {
                        Text(author.initials)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(author.localizedName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if let era = author.era {
                        Text(era)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(8)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Cross Domain Card

/// 跨领域贡献卡片
struct CrossDomainCard: View {
    let domains: [DomainPosition]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "square.grid.2x2.fill")
                    .foregroundColor(.orange)
                Text("civilizationMap.crossDomain".localized)
                    .font(.headline)
            }

            // Domain list
            VStack(alignment: .leading, spacing: 16) {
                ForEach(domains) { domain in
                    VStack(alignment: .leading, spacing: 8) {
                        // Domain name and significance
                        HStack(spacing: 8) {
                            Text(domain.localizedDomain)
                                .font(.subheadline)
                                .fontWeight(.medium)

                            SignificanceBadge(significance: domain.significance)
                        }

                        // Contributions list
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(domain.localizedContributions, id: \.self) { contribution in
                                HStack(alignment: .top, spacing: 8) {
                                    Circle()
                                        .fill(Color.secondary)
                                        .frame(width: 4, height: 4)
                                        .padding(.top, 6)
                                    Text(contribution)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Significance Badge

/// 重要程度标签
struct SignificanceBadge: View {
    let significance: DomainSignificance

    var body: some View {
        Text(significance.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: significance == .minor ? 1 : 0)
            )
    }

    private var backgroundColor: Color {
        switch significance {
        case .major:
            return .blue
        case .moderate:
            return Color(.systemGray5)
        case .minor:
            return .clear
        }
    }

    private var foregroundColor: Color {
        switch significance {
        case .major:
            return .white
        case .moderate:
            return .primary
        case .minor:
            return .secondary
        }
    }

    private var borderColor: Color {
        switch significance {
        case .minor:
            return Color(.systemGray4)
        default:
            return .clear
        }
    }
}

// MARK: - Historical Context Card

/// 历史背景卡片
struct HistoricalContextCard: View {
    let events: [CivilizationHistoricalEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "clock.fill")
                    .foregroundColor(.indigo)
                Text("civilizationMap.historicalContext".localized)
                    .font(.headline)
            }

            // Timeline
            VStack(spacing: 0) {
                ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                    HistoricalEventRow(
                        event: event,
                        isLast: index == events.count - 1
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Historical Event Row

/// 历史事件行
struct HistoricalEventRow: View {
    let event: CivilizationHistoricalEvent
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Timeline dot and line
            VStack(spacing: 0) {
                Circle()
                    .fill(eventColor)
                    .frame(width: 12, height: 12)

                if !isLast {
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("\(event.year)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(eventColor)

                    Text(event.category.displayName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5))
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(eventColor.opacity(0.3), lineWidth: 1)
                        )
                }

                Text(event.localizedTitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, isLast ? 0 : 16)

            Spacer()
        }
    }

    private var eventColor: Color {
        switch event.category {
        case .war:
            return .red
        case .revolution:
            return .orange
        case .cultural:
            return .purple
        case .political:
            return .blue
        case .scientific:
            return .green
        }
    }
}
