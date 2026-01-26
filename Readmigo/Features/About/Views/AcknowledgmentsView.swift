import SwiftUI
import SafariServices

/// Acknowledgments / Credits view
struct AcknowledgmentsView: View {
    @State private var showingSafari = false
    @State private var safariURL: URL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Team section
                VStack(alignment: .leading, spacing: 12) {
                    Text("about.acknowledgments.team".localized)
                        .font(.headline)
                        .foregroundColor(.brandPrimary)

                    Text("about.acknowledgments.teamDescription".localized)
                        .font(.body)
                        .foregroundColor(.secondary)
                }

                Divider()

                // Content Sources section
                VStack(alignment: .leading, spacing: 12) {
                    Text("about.acknowledgments.contentSources".localized)
                        .font(.headline)
                        .foregroundColor(.brandPrimary)

                    VStack(alignment: .leading, spacing: 8) {
                        AcknowledgmentRow(
                            title: "Standard Ebooks",
                            description: "about.acknowledgments.standardEbooksDescription".localized
                        )

                        AcknowledgmentRow(
                            title: "Project Gutenberg",
                            description: "about.acknowledgments.gutenbergDescription".localized
                        )
                    }

                    // View full credits button
                    Button(action: {
                        safariURL = URL(string: "https://readmigo.app/credits")
                        showingSafari = true
                    }) {
                        HStack {
                            Text("about.acknowledgments.viewFullCredits".localized)
                                .font(.subheadline)
                            Image(systemName: "arrow.up.right.square")
                                .font(.subheadline)
                        }
                        .foregroundColor(.brandPrimary)
                    }
                    .padding(.top, 4)
                }

                Divider()

                // Special Thanks section
                VStack(alignment: .leading, spacing: 12) {
                    Text("about.acknowledgments.specialThanks".localized)
                        .font(.headline)
                        .foregroundColor(.brandPrimary)

                    VStack(alignment: .leading, spacing: 8) {
                        AcknowledgmentRow(
                            title: "about.acknowledgments.betaTesters".localized,
                            description: "about.acknowledgments.betaTestersDescription".localized
                        )

                        AcknowledgmentRow(
                            title: "about.acknowledgments.community".localized,
                            description: "about.acknowledgments.communityDescription".localized
                        )

                        AcknowledgmentRow(
                            title: "about.acknowledgments.openSource".localized,
                            description: "about.acknowledgments.openSourceDescription".localized
                        )
                    }
                }

                Divider()

                // Made with love
                HStack {
                    Spacer()
                    Text("about.madeWith".localized)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.top, 16)
            }
            .padding()
        }
        .navigationTitle("about.acknowledgments".localized)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingSafari) {
            if let url = safariURL {
                SafariView(url: url)
            }
        }
    }
}

struct AcknowledgmentRow: View {
    let title: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)

            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}
