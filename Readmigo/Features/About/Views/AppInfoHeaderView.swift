import SwiftUI

/// App information header with icon, name, and slogan
struct AppInfoHeaderView: View {
    var body: some View {
        VStack(spacing: 12) {
            // App Logo (using the colorful app icon)
            if let iconImage = Bundle.main.appIcon {
                Image(uiImage: iconImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            } else {
                Image("SplashLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            }

            // App Name
            Text("app.name".localized)
                .font(.title)
                .fontWeight(.bold)

            // Slogan
            Text("about.slogan".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

// MARK: - Bundle Extension for App Icon

extension Bundle {
    var appIcon: UIImage? {
        if let icons = infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
           let lastIcon = iconFiles.last {
            return UIImage(named: lastIcon)
        }
        return nil
    }
}
