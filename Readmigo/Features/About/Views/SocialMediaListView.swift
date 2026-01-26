import SwiftUI

/// Social media accounts list view
struct SocialMediaListView: View {
    let accounts = ContactData.socialMedia

    var body: some View {
        List {
            Section(header: Text("contact.officialAccounts".localized)) {
                ForEach(accounts) { account in
                    SocialMediaRow(account: account)
                }
            }
        }
        .navigationTitle("contact.socialMedia".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Individual social media row
struct SocialMediaRow: View {
    let account: SocialMediaAccount

    var body: some View {
        Button(action: { account.open() }) {
            HStack(spacing: 12) {
                // Platform icon
                Image(systemName: account.platform.iconName)
                    .font(.title2)
                    .foregroundColor(Color(hex: account.platform.brandColor))
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(account.platform.displayName)
                        .font(.body)
                        .foregroundColor(.primary)

                    Text(account.handle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
