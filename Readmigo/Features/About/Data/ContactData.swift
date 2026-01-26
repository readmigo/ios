import Foundation

/// Contact information configuration
struct ContactData {
    /// Support email address
    static let email = "support@readmigo.app"

    /// Support phone number (international format)
    static let phone = "+1 XXX-XXX-XXXX"

    /// All social media accounts
    static let socialMedia: [SocialMediaAccount] = [
        SocialMediaAccount(
            platform: .twitter,
            handle: "@ReadmigoApp",
            deepLink: "twitter://user?screen_name=ReadmigoApp",
            webUrl: "https://x.com/ReadmigoApp"
        ),
        SocialMediaAccount(
            platform: .instagram,
            handle: "@readmigo.app",
            deepLink: "instagram://user?username=readmigo.app",
            webUrl: "https://instagram.com/readmigo.app"
        ),
        SocialMediaAccount(
            platform: .facebook,
            handle: "@ReadmigoApp",
            deepLink: "fb://profile/ReadmigoApp",
            webUrl: "https://facebook.com/ReadmigoApp"
        ),
        SocialMediaAccount(
            platform: .youtube,
            handle: "@Readmigo",
            deepLink: "youtube://www.youtube.com/@Readmigo",
            webUrl: "https://youtube.com/@Readmigo"
        ),
        SocialMediaAccount(
            platform: .tiktok,
            handle: "@readmigo.app",
            deepLink: "snssdk1233://user/profile/readmigo.app",
            webUrl: "https://tiktok.com/@readmigo.app"
        ),
        SocialMediaAccount(
            platform: .discord,
            handle: "Readmigo Community",
            deepLink: "discord://invite/readmigo",
            webUrl: "https://discord.gg/readmigo"
        )
    ]
}
