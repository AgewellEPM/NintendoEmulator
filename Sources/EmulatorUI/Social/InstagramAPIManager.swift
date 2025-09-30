import Foundation
import Combine
import EmulatorKit

class InstagramAPIManager: ObservableObject {
    private let clientId = SocialAPIConfig.Instagram.clientId
    private let clientSecret = SocialAPIConfig.Instagram.clientSecret
    private let redirectURI = SocialAPIConfig.Instagram.redirectURI
    private let baseURL = "https://graph.instagram.com"

    @Published var isConnected = false
    @Published var userInfo: InstagramUser?
    @Published var mediaItems: [InstagramMedia] = []

    func authenticate() -> URL? {
        let scopes = [
            "user_profile",
            "user_media"
        ].joined(separator: ",")

        let authURL = "https://api.instagram.com/oauth/authorize?" +
            "client_id=\(clientId)&" +
            "redirect_uri=\(redirectURI)&" +
            "scope=\(scopes)&" +
            "response_type=code"

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
        let tokenURL = "https://api.instagram.com/oauth/access_token"

        var request = URLRequest(url: URL(string: tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyString = "client_id=\(clientId)&" +
            "client_secret=\(clientSecret)&" +
            "grant_type=authorization_code&" +
            "redirect_uri=\(redirectURI)&" +
            "code=\(code)"

        request.httpBody = bodyString.data(using: .utf8)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let tokenResponse = try JSONDecoder().decode(InstagramTokenResponse.self, from: data)

            // Exchange short-lived token for long-lived token
            await exchangeForLongLivedToken(shortToken: tokenResponse.access_token)

        } catch {
            print("Instagram token exchange error: \(error)")
        }
    }

    private func exchangeForLongLivedToken(shortToken: String) async {
        let longTokenURL = "https://graph.instagram.com/access_token?" +
            "grant_type=ig_exchange_token&" +
            "client_secret=\(clientSecret)&" +
            "access_token=\(shortToken)"

        guard let url = URL(string: longTokenURL) else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(InstagramLongTokenResponse.self, from: data)

            // Store long-lived token securely
            KeychainManager.shared.storeToken(response.access_token, for: "instagram_access_token")

            await MainActor.run {
                isConnected = true
            }

            await getUserInfo()

        } catch {
            print("Instagram long-lived token error: \(error)")
        }
    }

    func getUserInfo() async {
        guard let token = KeychainManager.shared.getToken(for: "instagram_access_token") else { return }

        let url = "\(baseURL)/me?fields=id,username,account_type,media_count&access_token=\(token)"
        guard let requestURL = URL(string: url) else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: requestURL)
            let user = try JSONDecoder().decode(InstagramUser.self, from: data)

            await MainActor.run {
                userInfo = user
            }
        } catch {
            print("Instagram user info error: \(error)")
        }
    }

    func getUserMedia() async {
        guard let token = KeychainManager.shared.getToken(for: "instagram_access_token") else { return }

        let url = "\(baseURL)/me/media?fields=id,caption,media_type,media_url,thumbnail_url,timestamp&access_token=\(token)"
        guard let requestURL = URL(string: url) else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: requestURL)
            let response = try JSONDecoder().decode(InstagramMediaResponse.self, from: data)

            await MainActor.run {
                mediaItems = response.data
            }
        } catch {
            print("Instagram media error: \(error)")
        }
    }

    // Note: Instagram API doesn't support direct posting from third-party apps
    // Content creation must be done through Instagram's own app or Creator Studio
    func createMediaContainer(imageURL: String, caption: String) async -> String? {
        guard let token = KeychainManager.shared.getToken(for: "instagram_access_token"),
              let userId = userInfo?.id else { return nil }

        let url = "\(baseURL)/\(userId)/media"

        let parameters: [String: Any] = [
            "image_url": imageURL,
            "caption": caption,
            "access_token": token
        ]

        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyString = parameters.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(InstagramMediaContainerResponse.self, from: data)
            return response.id
        } catch {
            print("Instagram create media container error: \(error)")
            return nil
        }
    }

    func publishMedia(creationId: String) async -> Bool {
        guard let token = KeychainManager.shared.getToken(for: "instagram_access_token"),
              let userId = userInfo?.id else { return false }

        let url = "\(baseURL)/\(userId)/media_publish"

        let parameters: [String: Any] = [
            "creation_id": creationId,
            "access_token": token
        ]

        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyString = parameters.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(InstagramPublishResponse.self, from: data)
            print("✅ Instagram media published: \(response.id)")
            return true
        } catch {
            print("Instagram publish media error: \(error)")
            return false
        }
    }

    // Helper method for posting retro gaming content
    func shareRetroGameplayHighlight(imageURL: String, gameName: String, description: String) async -> Bool {
        let caption = "🎮 \(gameName) gameplay highlight!\n\n\(description)\n\n#RetroGaming #Gaming #\(gameName.replacingOccurrences(of: " ", with: "")) #Nostalgia #GameHighlight"

        guard let creationId = await createMediaContainer(imageURL: imageURL, caption: caption) else {
            return false
        }

        // Wait a moment for processing
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

        return await publishMedia(creationId: creationId)
    }

    func shareStreamAnnouncement(imageURL: String, streamTitle: String, gameName: String, streamTime: String) async -> Bool {
        let caption = "📺 Going live soon!\n\n🎮 \(streamTitle)\n⏰ \(streamTime)\n🕹️ Playing: \(gameName)\n\nCan't wait to see you all there! 🎉\n\n#LiveStream #RetroGaming #Gaming #\(gameName.replacingOccurrences(of: " ", with: ""))"

        guard let creationId = await createMediaContainer(imageURL: imageURL, caption: caption) else {
            return false
        }

        try? await Task.sleep(nanoseconds: 2_000_000_000)
        return await publishMedia(creationId: creationId)
    }
}

// MARK: - Data Models
struct InstagramTokenResponse: Codable {
    let access_token: String
    let user_id: Int
}

struct InstagramLongTokenResponse: Codable {
    let access_token: String
    let token_type: String
    let expires_in: Int
}

struct InstagramUser: Codable {
    let id: String
    let username: String
    let account_type: String
    let media_count: Int?
}

struct InstagramMediaResponse: Codable {
    let data: [InstagramMedia]
    let paging: InstagramPaging?
}

struct InstagramMedia: Codable {
    let id: String
    let caption: String?
    let media_type: String
    let media_url: String?
    let thumbnail_url: String?
    let timestamp: String
}

struct InstagramPaging: Codable {
    let cursors: InstagramCursors?
    let next: String?
}

struct InstagramCursors: Codable {
    let before: String?
    let after: String?
}

struct InstagramMediaContainerResponse: Codable {
    let id: String
}

struct InstagramPublishResponse: Codable {
    let id: String
}