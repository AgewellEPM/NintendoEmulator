import Foundation
import Combine

/// Coordinates all social platform API integrations for content creators
class SocialAPICoordinator: ObservableObject {
    @Published var connectedPlatforms: Set<String> = []
    @Published var isAnyConnecting = false

    // API Managers
    @Published var twitchAPI = TwitchAPIManager()
    @Published var youtubeAPI = YouTubeAPIManager()
    @Published var discordAPI = DiscordAPIManager()
    @Published var twitterAPI = TwitterAPIManager()
    @Published var instagramAPI = InstagramAPIManager()
    @Published var tiktokAPI = TikTokAPIManager()

    private var cancellables = Set<AnyCancellable>()

    init() {
        setupConnectionMonitoring()
    }

    private func setupConnectionMonitoring() {
        // Monitor all API connection states
        twitchAPI.$isConnected
            .sink { [weak self] isConnected in
                self?.updateConnectionState("twitch", isConnected: isConnected)
            }
            .store(in: &cancellables)

        youtubeAPI.$isConnected
            .sink { [weak self] isConnected in
                self?.updateConnectionState("youtube", isConnected: isConnected)
            }
            .store(in: &cancellables)

        discordAPI.$isConnected
            .sink { [weak self] isConnected in
                self?.updateConnectionState("discord", isConnected: isConnected)
            }
            .store(in: &cancellables)

        twitterAPI.$isConnected
            .sink { [weak self] isConnected in
                self?.updateConnectionState("twitter", isConnected: isConnected)
            }
            .store(in: &cancellables)

        instagramAPI.$isConnected
            .sink { [weak self] isConnected in
                self?.updateConnectionState("instagram", isConnected: isConnected)
            }
            .store(in: &cancellables)

        tiktokAPI.$isConnected
            .sink { [weak self] isConnected in
                self?.updateConnectionState("tiktok", isConnected: isConnected)
            }
            .store(in: &cancellables)
    }

    private func updateConnectionState(_ platform: String, isConnected: Bool) {
        if isConnected {
            connectedPlatforms.insert(platform)
        } else {
            connectedPlatforms.remove(platform)
        }
    }

    // MARK: - Platform Authentication
    func authenticate(platform: String) -> URL? {
        switch platform.lowercased() {
        case "twitch":
            return twitchAPI.authenticate()
        case "youtube":
            return youtubeAPI.authenticate()
        case "discord":
            return discordAPI.authenticate()
        case "twitter":
            return twitterAPI.authenticate()
        case "instagram":
            return instagramAPI.authenticate()
        case "tiktok":
            return tiktokAPI.authenticate()
        default:
            return nil
        }
    }

    // MARK: - OAuth Callback Handling
    func handleOAuthCallback(url: URL) async {
        let urlString = url.absoluteString

        if urlString.contains("twitch") {
            await twitchAPI.handleCallback(url: url)
        } else if urlString.contains("youtube") {
            await youtubeAPI.handleCallback(url: url)
        } else if urlString.contains("discord") {
            await discordAPI.handleCallback(url: url)
        } else if urlString.contains("twitter") {
            await twitterAPI.handleCallback(url: url)
        } else if urlString.contains("instagram") {
            await instagramAPI.handleCallback(url: url)
        } else if urlString.contains("tiktok") {
            await tiktokAPI.handleCallback(url: url)
        }
    }

    // MARK: - Content Creator Actions

    /// Post a "Going Live" announcement across all connected platforms
    func announceGoingLive(streamTitle: String, gameName: String, streamURL: String?) async {
        // Twitch - Update stream title
        if twitchAPI.isConnected {
            await twitchAPI.updateStreamTitle(streamTitle)
        }

        // Twitter - Post going live tweet
        if twitterAPI.isConnected {
            let _ = await twitterAPI.postStreamGoLive(streamTitle: streamTitle, gameName: gameName, streamURL: streamURL)
        }

        // Discord - Post webhook if configured
        if discordAPI.isConnected {
            // Would need webhook URL from user settings
            // await discordAPI.postStreamUpdate(webhookURL: webhookURL, streamTitle: streamTitle, gameName: gameName)
        }

        // Instagram - Would need image URL for story/post
        // TikTok - Not typically used for live announcements
        // YouTube - Would update stream metadata if live streaming there
    }

    /// Share a gameplay highlight across platforms
    func shareGameplayHighlight(description: String, gameName: String, mediaURL: String?, videoData: Data? = nil) async {
        // Twitter - Post with media
        if twitterAPI.isConnected {
            let _ = await twitterAPI.postHighlight(description: description, videoURL: mediaURL)
        }

        // Instagram - Post image/video
        if instagramAPI.isConnected, let imageURL = mediaURL {
            let _ = await instagramAPI.shareRetroGameplayHighlight(imageURL: imageURL, gameName: gameName, description: description)
        }

        // TikTok - Upload video clip
        if tiktokAPI.isConnected, let videoData = videoData {
            let _ = await tiktokAPI.shareRetroGameplayClip(videoData: videoData, gameName: gameName, description: description)
        }

        // Discord - Post in community channels
        // YouTube - Could upload as YouTube Short
    }

    /// Schedule and announce upcoming streams
    func announceUpcomingStream(scheduledTime: String, streamTitle: String, gameName: String) async {
        if twitterAPI.isConnected {
            let _ = await twitterAPI.postScheduleUpdate(nextStream: scheduledTime, gameTitle: gameName)
        }

        // Instagram - Story announcement
        // Discord - Event creation
        // YouTube - Community post
    }

    // MARK: - Analytics & Insights
    func getConnectedPlatformsSummary() -> String {
        let count = connectedPlatforms.count
        let platforms = Array(connectedPlatforms).joined(separator: ", ")
        return "\(count) platform\(count == 1 ? "" : "s") connected: \(platforms)"
    }

    func getUserInfo(for platform: String) async {
        switch platform.lowercased() {
        case "twitch":
            await twitchAPI.getUserInfo()
        case "youtube":
            await youtubeAPI.getChannelInfo()
        case "discord":
            await discordAPI.getUserInfo()
        case "twitter":
            await twitterAPI.getUserInfo()
        case "instagram":
            await instagramAPI.getUserInfo()
        case "tiktok":
            await tiktokAPI.getUserInfo()
        default:
            break
        }
    }
}