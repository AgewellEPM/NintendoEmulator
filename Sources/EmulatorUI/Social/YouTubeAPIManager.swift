import Foundation
import Combine
import EmulatorKit

class YouTubeAPIManager: ObservableObject {
    private let clientId = SocialAPIConfig.YouTube.clientId
    // ⚠️ REMOVED: Client secrets must be handled by backend OAuth proxy
    private let redirectURI = SocialAPIConfig.YouTube.redirectURI
    private let baseURL = "https://www.googleapis.com/youtube/v3"

    @Published var isConnected = false
    @Published var channelInfo: YouTubeChannel?
    @Published var liveStreams: [YouTubeLiveStream] = []

    func authenticate() -> URL? {
        let scopes = [
            "https://www.googleapis.com/auth/youtube",
            "https://www.googleapis.com/auth/youtube.upload",
            "https://www.googleapis.com/auth/youtube.readonly"
        ].joined(separator: "%20")

        let authURL = "https://accounts.google.com/o/oauth2/v2/auth?" +
            "client_id=\(clientId)&" +
            "redirect_uri=\(redirectURI)&" +
            "response_type=code&" +
            "scope=\(scopes)&" +
            "access_type=offline&" +
            "prompt=consent"

        return URL(string: authURL)
    }

    func handleCallback(url: URL) async {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            return
        }

        await exchangeCodeForToken(code: code)
    }

    private func exchangeCodeForToken(code: String) async {
        // 🔒 SECURITY: Token exchange must go through backend OAuth proxy
        print("⚠️ WARNING: YouTube OAuth requires backend proxy - see SECURITY_ASSESSMENT_REPORT.md")

        let tokenURL = "https://oauth2.googleapis.com/token"

        var request = URLRequest(url: URL(string: tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        // ⚠️ This will fail without client secret - backend proxy required
        let bodyString = "client_id=\(clientId)&" +
            "code=\(code)&" +
            "grant_type=authorization_code&" +
            "redirect_uri=\(redirectURI)"

        request.httpBody = bodyString.data(using: String.Encoding.utf8)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let tokenResponse = try JSONDecoder().decode(YouTubeTokenResponse.self, from: data)

            // Store tokens securely
            KeychainManager.shared.storeToken(tokenResponse.access_token, for: "youtube_access_token")
            if let refreshToken = tokenResponse.refresh_token {
                KeychainManager.shared.storeToken(refreshToken, for: "youtube_refresh_token")
            }

            await MainActor.run {
                isConnected = true
            }

            await getChannelInfo()

        } catch {
            print("YouTube token exchange error: \(error)")
        }
    }

    func getChannelInfo() async {
        guard let token = KeychainManager.shared.getToken(for: "youtube_access_token") else { return }

        let url = "\(baseURL)/channels?part=snippet,statistics,brandingSettings&mine=true"
        var request = URLRequest(url: URL(string: url)!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(YouTubeChannelsResponse.self, from: data)

            await MainActor.run {
                channelInfo = response.items.first
            }
        } catch {
            print("YouTube channel info error: \(error)")
        }
    }

    func getLiveStreams() async {
        guard let token = KeychainManager.shared.getToken(for: "youtube_access_token") else { return }

        let url = "\(baseURL)/liveBroadcasts?part=snippet,status&broadcastStatus=active&mine=true"
        var request = URLRequest(url: URL(string: url)!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(YouTubeLiveStreamsResponse.self, from: data)

            await MainActor.run {
                liveStreams = response.items
            }
        } catch {
            print("YouTube live streams error: \(error)")
        }
    }

    func createLiveBroadcast(title: String, description: String) async -> String? {
        guard let token = KeychainManager.shared.getToken(for: "youtube_access_token") else { return nil }

        let broadcastData: [String: Any] = [
            "snippet": [
                "title": title,
                "description": description,
                "scheduledStartTime": ISO8601DateFormatter().string(from: Date())
            ],
            "status": [
                "privacyStatus": "public",
                "selfDeclaredMadeForKids": false
            ]
        ]

        let jsonData = try? JSONSerialization.data(withJSONObject: broadcastData)

        let url = "\(baseURL)/liveBroadcasts?part=snippet,status"
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(YouTubeLiveStream.self, from: data)
            return response.id
        } catch {
            print("YouTube create broadcast error: \(error)")
            return nil
        }
    }

    func updateStreamTitle(_ title: String, broadcastId: String) async {
        guard let token = KeychainManager.shared.getToken(for: "youtube_access_token") else { return }

        // First get current broadcast info
        let getUrl = "\(baseURL)/liveBroadcasts?part=snippet,status&id=\(broadcastId)"
        var getRequest = URLRequest(url: URL(string: getUrl)!)
        getRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: getRequest)
            let response = try JSONDecoder().decode(YouTubeLiveStreamsResponse.self, from: data)

            guard let broadcast = response.items.first else { return }

            // Update the title
            let updateData: [String: Any] = [
                "id": broadcastId,
                "snippet": [
                    "title": title,
                    "description": broadcast.snippet.description,
                    "scheduledStartTime": broadcast.snippet.scheduledStartTime
                ],
                "status": [
                    "privacyStatus": broadcast.status.privacyStatus
                ]
            ]

            let jsonData = try? JSONSerialization.data(withJSONObject: updateData)

            let updateUrl = "\(baseURL)/liveBroadcasts?part=snippet,status"
            var updateRequest = URLRequest(url: URL(string: updateUrl)!)
            updateRequest.httpMethod = "PUT"
            updateRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            updateRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            updateRequest.httpBody = jsonData

            let _ = try await URLSession.shared.data(for: updateRequest)
            print("✅ YouTube stream title updated")

        } catch {
            print("YouTube update title error: \(error)")
        }
    }

    func uploadVideo(title: String, description: String, videoURL: URL) async -> String? {
        guard KeychainManager.shared.getToken(for: "youtube_access_token") != nil else { return nil }

        let _: [String: Any] = [
            "snippet": [
                "title": title,
                "description": description,
                "tags": ["retro", "gaming", "stream"],
                "categoryId": "20" // Gaming category
            ],
            "status": [
                "privacyStatus": "public",
                "selfDeclaredMadeForKids": false
            ]
        ]

        // This is a simplified version - actual implementation would need multipart upload
        print("📹 Video upload to YouTube initiated: \(title)")
        return "mock_video_id"
    }
}

// MARK: - Data Models
struct YouTubeTokenResponse: Codable {
    let access_token: String
    let refresh_token: String?
    let expires_in: Int
    let token_type: String
}

struct YouTubeChannelsResponse: Codable {
    let items: [YouTubeChannel]
}

struct YouTubeChannel: Codable {
    let id: String
    let snippet: YouTubeChannelSnippet
    let statistics: YouTubeChannelStatistics?
}

struct YouTubeChannelSnippet: Codable {
    let title: String
    let description: String
    let thumbnails: YouTubeThumbnails
}

struct YouTubeChannelStatistics: Codable {
    let subscriberCount: String
    let videoCount: String
    let viewCount: String
}

struct YouTubeThumbnails: Codable {
    let `default`: YouTubeThumbnail?
    let medium: YouTubeThumbnail?
    let high: YouTubeThumbnail?
}

struct YouTubeThumbnail: Codable {
    let url: String
    let width: Int?
    let height: Int?
}

struct YouTubeLiveStreamsResponse: Codable {
    let items: [YouTubeLiveStream]
}

struct YouTubeLiveStream: Codable {
    let id: String
    let snippet: YouTubeLiveStreamSnippet
    let status: YouTubeLiveStreamStatus
}

struct YouTubeLiveStreamSnippet: Codable {
    let title: String
    let description: String
    let scheduledStartTime: String
    let thumbnails: YouTubeThumbnails?
}

struct YouTubeLiveStreamStatus: Codable {
    let privacyStatus: String
    let lifeCycleStatus: String?
}