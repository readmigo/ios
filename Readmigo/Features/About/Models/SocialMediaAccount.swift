import Foundation

/// Social media platform types
enum SocialPlatform: String, CaseIterable, Identifiable {
    case twitter = "X (Twitter)"
    case instagram = "Instagram"
    case facebook = "Facebook"
    case youtube = "YouTube"
    case tiktok = "TikTok"
    case discord = "Discord"

    var id: String { rawValue }

    /// Display name for the platform
    var displayName: String {
        rawValue
    }

    /// SF Symbol icon name for the platform
    var iconName: String {
        switch self {
        case .twitter: return "bird"
        case .instagram: return "camera"
        case .facebook: return "person.2"
        case .youtube: return "play.rectangle"
        case .tiktok: return "music.note"
        case .discord: return "bubble.left.and.bubble.right"
        }
    }

    /// Brand color for the platform
    var brandColor: String {
        switch self {
        case .twitter: return "000000"
        case .instagram: return "E4405F"
        case .facebook: return "1877F2"
        case .youtube: return "FF0000"
        case .tiktok: return "000000"
        case .discord: return "5865F2"
        }
    }
}

/// Social media account model
struct SocialMediaAccount: Identifiable {
    let id = UUID()
    let platform: SocialPlatform
    /// Account handle (e.g., "@Readmigo")
    let handle: String
    /// Deep link URL scheme to open the app
    let deepLink: String?
    /// Fallback web URL
    let webUrl: String

    /// Check if the app is installed and can open the deep link
    var canOpenApp: Bool {
        guard let deepLink = deepLink,
              let url = URL(string: deepLink) else {
            return false
        }
        return UIApplication.shared.canOpenURL(url)
    }

    /// Open the social media account (app or web)
    func open() {
        // Try deep link first
        if let deepLink = deepLink,
           let url = URL(string: deepLink),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            return
        }

        // Fallback to web URL
        if let url = URL(string: webUrl) {
            UIApplication.shared.open(url)
        }
    }
}

import UIKit
