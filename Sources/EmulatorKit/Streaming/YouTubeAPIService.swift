import Foundation
import Combine

/// Sprint 2 - STREAM-002: YouTube Live API Integration Service
/// Handles live streaming to YouTube with OAuth authentication and live broadcast management
public class YouTubeAPIService {
    private let baseURL = URL(string: "https://www.googleapis.com/youtube/v3")!
    private let session: URLSession
    private let clientID: String
    private let clientSecret: String

    @Published public private(set) var isConnected = false
    @Published public private(set) var currentChannel: YouTubeChannel?
    @Published public private(set) var activeBroadcast: YouTubeBroadcast?

    public init(clientID: String = "", clientSecret: String = "") {
        self.clientID = clientID
        self.clientSecret = clientSecret

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }

    // MARK: - OAuth Authentication

    /// Generate YouTube OAuth authorization URL
    public func generateAuthorizationURL(redirectURI: String) -> URL {
        let scope = "https://www.googleapis.com/auth/youtube.force-ssl https://www.googleapis.com/auth/youtube.readonly"
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "state", value: generateState())
        ]
        return components.url!
    }

    /// Exchange authorization code for access token
    public func exchangeCodeForToken(code: String, redirectURI: String) async throws -> YouTubeAuthResponse {
        let url = URL(string: "https://oauth2.googleapis.com/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyComponents = [
            "client_id=\(clientID)",
            "client_secret=\(clientSecret)",
            "code=\(code)",
            "grant_type=authorization_code",
            "redirect_uri=\(redirectURI)"
        ]
        request.httpBody = bodyComponents.joined(separator: "&").data(using: .utf8)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw StreamingError.authenticationFailed
        }

        let authResponse = try JSONDecoder().decode(YouTubeAuthResponse.self, from: data)
        await storeCredentials(authResponse)
        return authResponse
    }

    // MARK: - Channel Management

    /// Get current user's channel information
    public func getChannelInfo() async throws -> YouTubeChannel {
        let url = baseURL.appendingPathComponent("channels")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet,statistics,status"),
            URLQueryItem(name: "mine", value: "true")
        ]

        let request = try await createAuthenticatedRequest(url: components.url!)
        let (data, response) = try await session.data(for: request)

        try validateResponse(response)

        let channelResponse = try JSONDecoder().decode(YouTubeChannelResponse.self, from: data)
        guard let channel = channelResponse.items.first else {
            throw StreamingError.resourceNotFound
        }

        return channel
    }

    // MARK: - Live Streaming Management

    /// Create a new live broadcast
    public func createLiveBroadcast(
        title: String,
        description: String? = nil,
        scheduledStartTime: Date? = nil,
        privacy: YouTubeBroadcastPrivacy = .unlisted
    ) async throws -> YouTubeBroadcast {
        let url = baseURL.appendingPathComponent("liveBroadcasts")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "part", value: "snippet,status")]

        var request = try await createAuthenticatedRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let broadcastData = YouTubeBroadcastRequest(
            snippet: YouTubeBroadcastSnippet(
                title: title,
                description: description,
                scheduledStartTime: scheduledStartTime ?? Date().addingTimeInterval(60) // Start in 1 minute
            ),
            status: YouTubeBroadcastStatus(privacyStatus: privacy.rawValue)
        )

        request.httpBody = try JSONEncoder().encode(broadcastData)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let broadcastResponse = try JSONDecoder().decode(YouTubeBroadcastResponse.self, from: data)
        guard let broadcast = broadcastResponse.items.first else {
            throw StreamingError.serverError("Failed to create broadcast")
        }

        activeBroadcast = broadcast
        NSLog("📺 YouTube broadcast created: \(title)")
        return broadcast
    }

    /// Create a live stream for broadcasting
    public func createLiveStream(title: String, description: String? = nil) async throws -> YouTubeStream {
        let url = baseURL.appendingPathComponent("liveStreams")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "part", value: "snippet,cdn")]

        var request = try await createAuthenticatedRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let streamData = YouTubeStreamRequest(
            snippet: YouTubeStreamSnippet(
                title: title,
                description: description
            ),
            cdn: YouTubeStreamCDN(
                format: "1080p",
                ingestionType: "rtmp"
            )
        )

        request.httpBody = try JSONEncoder().encode(streamData)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let streamResponse = try JSONDecoder().decode(YouTubeStreamResponse.self, from: data)
        guard let stream = streamResponse.items.first else {
            throw StreamingError.serverError("Failed to create stream")
        }

        NSLog("📺 YouTube stream created with key: \(stream.cdn.ingestionInfo?.streamName ?? "unknown")")
        return stream
    }

    /// Bind a stream to a broadcast
    public func bindStreamToBroadcast(broadcastId: String, streamId: String) async throws {
        let url = baseURL.appendingPathComponent("liveBroadcasts/bind")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "part", value: "id,status"),
            URLQueryItem(name: "id", value: broadcastId),
            URLQueryItem(name: "streamId", value: streamId)
        ]

        var request = try await createAuthenticatedRequest(url: components.url!)
        request.httpMethod = "POST"

        let (_, response) = try await session.data(for: request)
        try validateResponse(response)

        NSLog("📺 Stream bound to broadcast successfully")
    }

    /// Start a live broadcast
    public func startBroadcast(broadcastId: String) async throws {
        try await transitionBroadcast(broadcastId: broadcastId, broadcastStatus: "live")
        NSLog("📺 YouTube broadcast started")
    }

    /// Stop a live broadcast
    public func stopBroadcast(broadcastId: String) async throws {
        try await transitionBroadcast(broadcastId: broadcastId, broadcastStatus: "complete")
        activeBroadcast = nil
        NSLog("📺 YouTube broadcast stopped")
    }

    /// Get live broadcast statistics
    public func getBroadcastStatistics(broadcastId: String) async throws -> YouTubeBroadcastStatistics {
        let url = baseURL.appendingPathComponent("liveBroadcasts")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "part", value: "statistics"),
            URLQueryItem(name: "id", value: broadcastId)
        ]

        let request = try await createAuthenticatedRequest(url: components.url!)
        let (data, response) = try await session.data(for: request)

        try validateResponse(response)

        let broadcastResponse = try JSONDecoder().decode(YouTubeBroadcastResponse.self, from: data)
        guard let broadcast = broadcastResponse.items.first,
              let statistics = broadcast.statistics else {
            throw StreamingError.resourceNotFound
        }

        return statistics
    }

    /// Search YouTube categories
    public func searchCategories(query: String = "") async throws -> [YouTubeCategory] {
        let url = baseURL.appendingPathComponent("videoCategories")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "regionCode", value: "US")
        ]

        let request = try await createAuthenticatedRequest(url: components.url!)
        let (data, response) = try await session.data(for: request)

        try validateResponse(response)

        let categoriesResponse = try JSONDecoder().decode(YouTubeCategoryResponse.self, from: data)

        // Filter categories if query is provided
        if query.isEmpty {
            return categoriesResponse.items
        } else {
            return categoriesResponse.items.filter {
                $0.snippet.title.localizedCaseInsensitiveContains(query)
            }
        }
    }

    // MARK: - Connection Management

    /// Test connection to YouTube API
    public func testConnection() async throws -> Bool {
        do {
            _ = try await getChannelInfo()
            await MainActor.run { isConnected = true }
            return true
        } catch {
            await MainActor.run { isConnected = false }
            throw error
        }
    }

    /// Disconnect from YouTube
    public func disconnect() async {
        await clearStoredCredentials()
        await MainActor.run {
            isConnected = false
            currentChannel = nil
            activeBroadcast = nil
        }
    }

    // MARK: - Private Methods

    private func createAuthenticatedRequest(url: URL) async throws -> URLRequest {
        guard let accessToken = await getStoredAccessToken() else {
            throw StreamingError.notAuthenticated
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func transitionBroadcast(broadcastId: String, broadcastStatus: String) async throws {
        let url = baseURL.appendingPathComponent("liveBroadcasts/transition")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "part", value: "status"),
            URLQueryItem(name: "id", value: broadcastId),
            URLQueryItem(name: "broadcastStatus", value: broadcastStatus)
        ]

        var request = try await createAuthenticatedRequest(url: components.url!)
        request.httpMethod = "POST"

        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw StreamingError.networkError
        }

        switch httpResponse.statusCode {
        case 200...299:
            break
        case 401:
            throw StreamingError.notAuthenticated
        case 403:
            throw StreamingError.serverError("Insufficient permissions")
        case 404:
            throw StreamingError.resourceNotFound
        case 429:
            throw StreamingError.rateLimited
        default:
            throw StreamingError.serverError("HTTP \(httpResponse.statusCode)")
        }
    }

    private func generateState() -> String {
        return UUID().uuidString
    }

    // MARK: - Credential Storage

    @MainActor
    private func storeCredentials(_ response: YouTubeAuthResponse) async {
        UserDefaults.standard.set(response.access_token, forKey: "youtube_access_token")
        if let refreshToken = response.refresh_token {
            UserDefaults.standard.set(refreshToken, forKey: "youtube_refresh_token")
        }

        // Get channel info and store
        do {
            let channel = try await getChannelInfo()
            currentChannel = channel
            isConnected = true
        } catch {
            NSLog("⚠️ Failed to fetch channel info after authentication: \(error)")
        }
    }

    private func getStoredAccessToken() async -> String? {
        return UserDefaults.standard.string(forKey: "youtube_access_token")
    }

    private func clearStoredCredentials() async {
        UserDefaults.standard.removeObject(forKey: "youtube_access_token")
        UserDefaults.standard.removeObject(forKey: "youtube_refresh_token")
    }
}

// MARK: - Data Models

public struct YouTubeAuthResponse: Codable {
    let access_token: String
    let refresh_token: String?
    let expires_in: Int
    let token_type: String
    let scope: String
}

public struct YouTubeChannel: Codable, Identifiable {
    public let id: String
    public let snippet: YouTubeChannelSnippet
    public let statistics: YouTubeChannelStatistics?
    public let status: YouTubeChannelStatus?
}

public struct YouTubeChannelSnippet: Codable {
    public let title: String
    public let description: String
    public let customUrl: String?
    public let publishedAt: String
    public let thumbnails: YouTubeThumbnails
    public let country: String?
}

public struct YouTubeChannelStatistics: Codable {
    public let viewCount: String?
    public let subscriberCount: String?
    public let hiddenSubscriberCount: Bool
    public let videoCount: String?
}

public struct YouTubeChannelStatus: Codable {
    public let privacyStatus: String
    public let isLinked: Bool
    public let longUploadsStatus: String
}

public struct YouTubeBroadcast: Codable, Identifiable {
    public let id: String
    public let snippet: YouTubeBroadcastSnippetResponse
    public let status: YouTubeBroadcastStatusResponse
    public let statistics: YouTubeBroadcastStatistics?
}

public struct YouTubeBroadcastSnippetResponse: Codable {
    public let publishedAt: String
    public let channelId: String
    public let title: String
    public let description: String
    public let thumbnails: YouTubeThumbnails
    public let scheduledStartTime: String
    public let scheduledEndTime: String?
    public let actualStartTime: String?
    public let actualEndTime: String?
}

public struct YouTubeBroadcastStatusResponse: Codable {
    public let lifeCycleStatus: String
    public let privacyStatus: String
    public let recordingStatus: String
    public let madeForKids: Bool
    public let selfDeclaredMadeForKids: Bool
}

public struct YouTubeBroadcastStatistics: Codable {
    public let concurrentViewers: String?
    public let totalChatCount: String?
}

public struct YouTubeStream: Codable, Identifiable {
    public let id: String
    public let snippet: YouTubeStreamSnippetResponse
    public let cdn: YouTubeStreamCDNResponse
    public let status: YouTubeStreamStatus
}

public struct YouTubeStreamSnippetResponse: Codable {
    public let publishedAt: String
    public let channelId: String
    public let title: String
    public let description: String
}

public struct YouTubeStreamCDNResponse: Codable {
    public let format: String
    public let ingestionType: String
    public let ingestionInfo: YouTubeIngestionInfo?
    public let resolution: String?
    public let frameRate: String?
}

public struct YouTubeIngestionInfo: Codable {
    public let streamName: String
    public let ingestionAddress: String
    public let backupIngestionAddress: String?
}

public struct YouTubeStreamStatus: Codable {
    public let streamStatus: String
    public let healthStatus: YouTubeStreamHealthStatus?
}

public struct YouTubeStreamHealthStatus: Codable {
    public let status: String
    public let lastUpdateTimeSeconds: String
    public let configurationIssues: [YouTubeConfigurationIssue]?
}

public struct YouTubeConfigurationIssue: Codable {
    public let type: String
    public let severity: String
    public let reason: String
    public let description: String
}

public struct YouTubeCategory: Codable, Identifiable {
    public let id: String
    public let snippet: YouTubeCategorySnippet
}

public struct YouTubeCategorySnippet: Codable {
    public let channelId: String
    public let title: String
    public let assignable: Bool
}

public struct YouTubeThumbnails: Codable {
    public let `default`: YouTubeThumbnail?
    public let medium: YouTubeThumbnail?
    public let high: YouTubeThumbnail?
}

public struct YouTubeThumbnail: Codable {
    public let url: String
    public let width: Int
    public let height: Int
}

// MARK: - Request Models

private struct YouTubeBroadcastRequest: Codable {
    let snippet: YouTubeBroadcastSnippet
    let status: YouTubeBroadcastStatus
}

private struct YouTubeBroadcastSnippet: Codable {
    let title: String
    let description: String?
    let scheduledStartTime: Date
}

private struct YouTubeBroadcastStatus: Codable {
    let privacyStatus: String
}

private struct YouTubeStreamRequest: Codable {
    let snippet: YouTubeStreamSnippet
    let cdn: YouTubeStreamCDN
}

private struct YouTubeStreamSnippet: Codable {
    let title: String
    let description: String?
}

private struct YouTubeStreamCDN: Codable {
    let format: String
    let ingestionType: String
}

// MARK: - Response Wrappers

private struct YouTubeChannelResponse: Codable {
    let items: [YouTubeChannel]
}

private struct YouTubeBroadcastResponse: Codable {
    let items: [YouTubeBroadcast]
}

private struct YouTubeStreamResponse: Codable {
    let items: [YouTubeStream]
}

private struct YouTubeCategoryResponse: Codable {
    let items: [YouTubeCategory]
}

// MARK: - Enums

public enum YouTubeBroadcastPrivacy: String, CaseIterable {
    case `private` = "private"
    case `public` = "public"
    case unlisted = "unlisted"

    public var displayName: String {
        switch self {
        case .private: return "Private"
        case .public: return "Public"
        case .unlisted: return "Unlisted"
        }
    }
}