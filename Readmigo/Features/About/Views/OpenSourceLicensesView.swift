import SwiftUI
import SafariServices

/// Open source licenses list view
struct OpenSourceLicensesView: View {
    let licenses = Licenses.all

    var body: some View {
        List {
            ForEach(licenses) { license in
                NavigationLink {
                    LicenseDetailView(license: license)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(license.name)
                                .font(.body)

                            if let version = license.version {
                                Text(version)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Text(license.license.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("about.openSourceLicenses".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// License detail view
struct LicenseDetailView: View {
    let license: OpenSourceLicense
    @State private var showingSafari = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(license.name)
                        .font(.title2)
                        .fontWeight(.bold)

                    if let version = license.version {
                        Text("Version \(version)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Text(license.license.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.brandPrimary)

                    if let url = license.url {
                        Button {
                            showingSafari = true
                        } label: {
                            HStack {
                                Image(systemName: "link")
                                Text("View on GitHub")
                            }
                            .font(.subheadline)
                        }
                        .sheet(isPresented: $showingSafari) {
                            SafariView(url: url)
                        }
                    }
                }
                .padding(.bottom, 8)

                Divider()

                // License text
                Text(license.licenseText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .navigationTitle(license.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
