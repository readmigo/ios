import CarPlay
import MediaPlayer

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    var interfaceController: CPInterfaceController?
    private let templateManager = CarPlayTemplateManager.shared
    private var audiobookPlayer = AudiobookPlayer.shared

    // MARK: - CPTemplateApplicationSceneDelegate

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        templateManager.interfaceController = interfaceController

        // Set up the root template
        let rootTemplate = templateManager.createRootTemplate()
        interfaceController.setRootTemplate(rootTemplate, animated: true)

        LoggingService.shared.debug(.app, "[CarPlay] Connected to CarPlay", component: "CarPlaySceneDelegate")
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
        templateManager.interfaceController = nil

        LoggingService.shared.debug(.app, "[CarPlay] Disconnected from CarPlay", component: "CarPlaySceneDelegate")
    }
}

// MARK: - CarPlay Template Manager

@MainActor
class CarPlayTemplateManager: NSObject, ObservableObject {
    static let shared = CarPlayTemplateManager()

    var interfaceController: CPInterfaceController?

    private var audiobookPlayer = AudiobookPlayer.shared
    private var apiClient = APIClient.shared

    // Cache
    private var audiobooks: [AudiobookListItem] = []
    private var recentlyListened: [AudiobookListItem] = []

    override init() {
        super.init()
    }

    // MARK: - Root Template

    func createRootTemplate() -> CPTabBarTemplate {
        let tabs: [CPTemplate] = [
            createNowPlayingTab(),
            createLibraryTab(),
            createRecentTab(),
        ]

        let tabBarTemplate = CPTabBarTemplate(templates: tabs)
        return tabBarTemplate
    }

    // MARK: - Now Playing Tab

    private func createNowPlayingTab() -> CPTemplate {
        let template = CPNowPlayingTemplate.shared
        template.isUpNextButtonEnabled = true
        template.isAlbumArtistButtonEnabled = false

        // Add chapter skip buttons
        template.updateNowPlayingButtons([
            CPNowPlayingRepeatButton(handler: { [weak self] button in
                self?.audiobookPlayer.seek(by: -30)
            }),
            CPNowPlayingShuffleButton(handler: { [weak self] button in
                self?.audiobookPlayer.seek(by: 30)
            }),
            CPNowPlayingPlaybackRateButton(handler: { [weak self] button in
                self?.audiobookPlayer.cyclePlaybackSpeed()
            }),
        ])

        let tabItem = CPListItem(text: "Now Playing", detailText: nil)
        template.tabSystemItem = .featured
        template.tabImage = UIImage(systemName: "headphones")

        return template
    }

    // MARK: - Library Tab

    private func createLibraryTab() -> CPTemplate {
        let items: [CPListItem] = [
            createListItem(title: "All Audiobooks", icon: "books.vertical"),
            createListItem(title: "Continue Listening", icon: "play.circle"),
            createListItem(title: "Downloaded", icon: "arrow.down.circle"),
        ]

        let section = CPListSection(items: items)
        let template = CPListTemplate(title: "Library", sections: [section])
        template.tabImage = UIImage(systemName: "books.vertical")

        template.emptyViewTitleVariants = ["No Audiobooks"]
        template.emptyViewSubtitleVariants = ["Add audiobooks from the Readmigo app"]

        return template
    }

    private func createListItem(title: String, icon: String) -> CPListItem {
        let item = CPListItem(
            text: title,
            detailText: nil,
            image: UIImage(systemName: icon)
        )

        item.handler = { [weak self] item, completion in
            Task { @MainActor in
                await self?.handleLibraryItemTap(title: title)
                completion()
            }
        }

        return item
    }

    private func handleLibraryItemTap(title: String) async {
        switch title {
        case "All Audiobooks":
            await showAllAudiobooks()
        case "Continue Listening":
            await showContinueListening()
        case "Downloaded":
            showDownloaded()
        default:
            break
        }
    }

    // MARK: - Recent Tab

    private func createRecentTab() -> CPTemplate {
        let template = CPListTemplate(title: "Recent", sections: [])
        template.tabImage = UIImage(systemName: "clock")

        Task {
            await loadRecentlyListened(template: template)
        }

        return template
    }

    private func loadRecentlyListened(template: CPListTemplate) async {
        do {
            let items: [AudiobookListItem] = try await apiClient.request(
                endpoint: "/audiobooks/recently-listened?limit=10",
                method: .get
            )
            recentlyListened = items

            let listItems = items.map { audiobook in
                createAudiobookListItem(audiobook)
            }

            let section = CPListSection(items: listItems)
            template.updateSections([section])

        } catch {
            LoggingService.shared.debug(.app, "[CarPlay] Failed to load recent: \(error)", component: "CarPlaySceneDelegate")
        }
    }

    // MARK: - All Audiobooks

    private func showAllAudiobooks() async {
        guard let interfaceController = interfaceController else { return }

        do {
            struct PaginatedResponse: Decodable {
                let items: [AudiobookListItem]
            }

            let response: PaginatedResponse = try await apiClient.request(
                endpoint: "/audiobooks",
                method: .get
            )
            audiobooks = response.items

            let items = response.items.map { audiobook in
                createAudiobookListItem(audiobook)
            }

            let section = CPListSection(items: items, header: "All Audiobooks", sectionIndexTitle: nil)
            let template = CPListTemplate(title: "All Audiobooks", sections: [section])

            try await interfaceController.pushTemplate(template, animated: true)

        } catch {
            LoggingService.shared.debug(.app, "[CarPlay] Failed to load audiobooks: \(error)", component: "CarPlaySceneDelegate")
        }
    }

    private func showContinueListening() async {
        guard let interfaceController = interfaceController else { return }

        let items = recentlyListened.prefix(5).map { audiobook in
            createAudiobookListItem(audiobook)
        }

        let section = CPListSection(items: Array(items))
        let template = CPListTemplate(title: "Continue Listening", sections: [section])

        try? await interfaceController.pushTemplate(template, animated: true)
    }

    private func showDownloaded() {
        guard let interfaceController = interfaceController else { return }

        // Show downloaded audiobooks (placeholder for offline support)
        let template = CPListTemplate(title: "Downloaded", sections: [])
        template.emptyViewTitleVariants = ["No Downloads"]
        template.emptyViewSubtitleVariants = ["Download audiobooks for offline listening"]

        Task {
            try? await interfaceController.pushTemplate(template, animated: true)
        }
    }

    // MARK: - Audiobook List Item

    private func createAudiobookListItem(_ audiobook: AudiobookListItem) -> CPListItem {
        let item = CPListItem(
            text: audiobook.title,
            detailText: audiobook.author,
            image: nil, // Would load from coverUrl
            accessoryImage: nil,
            accessoryType: .disclosureIndicator
        )

        // Load cover image async
        if let coverUrl = audiobook.coverUrl, let url = URL(string: coverUrl) {
            Task {
                if let data = try? Data(contentsOf: url),
                   let image = UIImage(data: data) {
                    item.setImage(image)
                }
            }
        }

        item.handler = { [weak self] _, completion in
            Task { @MainActor in
                await self?.showAudiobookDetail(audiobook)
                completion()
            }
        }

        return item
    }

    // MARK: - Audiobook Detail

    private func showAudiobookDetail(_ listItem: AudiobookListItem) async {
        guard let interfaceController = interfaceController else { return }

        do {
            // Fetch full audiobook details
            let audiobook: Audiobook = try await apiClient.request(
                endpoint: "/audiobooks/\(listItem.id)",
                method: .get
            )

            // Create chapter list
            let chapterItems = audiobook.chapters.enumerated().map { index, chapter in
                let item = CPListItem(
                    text: chapter.title,
                    detailText: formatDuration(chapter.duration)
                )

                item.handler = { [weak self] _, completion in
                    self?.playAudiobook(audiobook, fromChapter: index)
                    completion()
                }

                return item
            }

            let section = CPListSection(items: chapterItems, header: "Chapters", sectionIndexTitle: nil)

            // Add play button at top
            let playItem = CPListItem(
                text: "Play from Beginning",
                detailText: nil,
                image: UIImage(systemName: "play.fill")
            )
            playItem.handler = { [weak self] _, completion in
                self?.playAudiobook(audiobook, fromChapter: 0)
                completion()
            }

            let continueItem = CPListItem(
                text: "Continue",
                detailText: "Resume where you left off",
                image: UIImage(systemName: "play.circle")
            )
            continueItem.handler = { [weak self] _, completion in
                self?.resumeAudiobook(audiobook)
                completion()
            }

            let actionsSection = CPListSection(items: [playItem, continueItem])

            let template = CPListTemplate(
                title: audiobook.title,
                sections: [actionsSection, section]
            )

            try await interfaceController.pushTemplate(template, animated: true)

        } catch {
            LoggingService.shared.debug(.app, "[CarPlay] Failed to load audiobook: \(error)", component: "CarPlaySceneDelegate")
        }
    }

    // MARK: - Playback

    private func playAudiobook(_ audiobook: Audiobook, fromChapter chapter: Int) {
        audiobookPlayer.loadAndPlay(
            audiobook: audiobook,
            startChapter: chapter,
            startPosition: 0
        )

        // Navigate to Now Playing
        Task {
            if let interfaceController = interfaceController {
                let nowPlayingTemplate = CPNowPlayingTemplate.shared
                try? await interfaceController.pushTemplate(nowPlayingTemplate, animated: true)
            }
        }
    }

    private func resumeAudiobook(_ audiobook: Audiobook) {
        // Load and resume from saved position
        Task {
            do {
                let progress: AudiobookProgress = try await apiClient.request(
                    endpoint: "/audiobooks/\(audiobook.id)/progress",
                    method: .get
                )

                audiobookPlayer.loadAndPlay(
                    audiobook: audiobook,
                    startChapter: progress.currentChapter,
                    startPosition: TimeInterval(progress.currentPosition)
                )

                // Navigate to Now Playing
                if let interfaceController = interfaceController {
                    let nowPlayingTemplate = CPNowPlayingTemplate.shared
                    try? await interfaceController.pushTemplate(nowPlayingTemplate, animated: true)
                }
            } catch {
                // Fall back to beginning
                playAudiobook(audiobook, fromChapter: 0)
            }
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}

// MARK: - AudiobookListItem for CarPlay
// Note: Uses AudiobookListItem from Core/Models/Audiobook.swift
