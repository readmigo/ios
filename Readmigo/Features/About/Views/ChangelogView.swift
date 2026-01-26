import SwiftUI

/// Changelog / Version history view
struct ChangelogView: View {
    let entries = Changelog.entries

    var body: some View {
        List {
            ForEach(entries) { entry in
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        // Version header
                        HStack {
                            Text("Version \(entry.version)")
                                .font(.headline)
                                .fontWeight(.semibold)

                            Spacer()

                            Text(entry.date, format: .dateTime.month().year())
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Divider()

                        // Changes list
                        ForEach(entry.localizedChanges, id: \.self) { change in
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                    .foregroundColor(.brandPrimary)
                                Text(change)
                                    .font(.subheadline)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .navigationTitle("about.changelog".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}
