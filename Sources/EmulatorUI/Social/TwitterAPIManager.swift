import Foundation
import Combine
import EmulatorKit

class TwitterAPIManager: ObservableObject {
    private let clientId = SocialAPIConfig.Twitter.clientId
    // ⚠️ REMOVED: Client secrets must be handled by backend OAuth proxy
    private let redirectURI = SocialAPIConfig.Twitter.redirectURI
    private let baseURL = "https://api.twitter.com/2"

    @Published var isConnected = false
    @Published var userInfo: TwitterUser?

    func authenticate() -> URL? {
        let scopes = [
            "tweet.read",
            "tweet.write",
            "users.read",
            "offline.access"
        ].joined(separator: "%20")

        // Generate PKCE challenge
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)

        // Store code verifier for later use
        UserDefaults.standard.set(codeVerifier, forKey: "twitter_code_verifier")

        let authURL = "https://twitter.com/i/oauth2/authorize?" +
            "response_type=code&" +
            "client_id=\(clientId)&" +
            "redirect_uri=\(redirectURI)&" +
            "scope=\(scopes)&" +
            "state=\(UUID().uuidString)&" +
            "code_challenge=\(codeChallenge)&" +
            "code_challenge_method=S256"

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
        guard let codeVerifier = UserDefaults.standard.string(forKey: "twitter_code_verifier") else {
            print("Code verifier not found")
            return
        }

        let tokenURL = "https://api.twitter.com/2/oauth2/token"

        var request = URLRequest(url: URL(string: tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyString = "code=\(code)&" +
            "grant_type=authorization_code&" +
            "client_id=\(clientId)&" +
            "redirect_uri=\(redirectURI)&" +
            "code_verifier=\(codeVerifier)"

        request.httpBody = bodyString.data(using: .utf8)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let tokenResponse = try JSONDecoder().decode(TwitterTokenResponse.self, from: data)

            // Store tokens securely
            KeychainManager.shared.storeToken(tokenResponse.access_token, for: "twitter_access_token")
            if let refreshToken = tokenResponse.refresh_token {
                KeychainManager.shared.storeToken(refreshToken, for: "twitter_refresh_token")
            }

            // Clean up code verifier
            UserDefaults.standard.removeObject(forKey: "twitter_code_verifier")

            await MainActor.run {
                isConnected = true
            }

            await getUserInfo()

        } catch {
            print("Twitter token exchange error: \(error)")
        }
    }

    func getUserInfo() async {
        guard let token = KeychainManager.shared.getToken(for: "twitter_access_token") else { return }

        let url = "\(baseURL)/users/me?user.fields=id,name,username,profile_image_url,public_metrics"
        var request = URLRequest(url: URL(string: url)!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(TwitterUserResponse.self, from: data)

            await MainActor.run {
                userInfo = response.data
            }
        } catch {
            print("Twitter user info error: \(error)")
        }
    }

    func postTweet(_ text: String) async -> String? {
        guard let token = KeychainManager.shared.getToken(for: "twitter_access_token") else { return nil }

        let tweetData: [String: Any] = [
            "text": text
        ]

        let jsonData = try? JSONSerialization.data(withJSONObject: tweetData)

        let url = "\(baseURL)/tweets"
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(TwitterTweetResponse.self, from: data)
            print("✅ Tweet posted: \(response.data.id)")
            return response.data.id
        } catch {
            print("Twitter post tweet error: \(error)")
            return nil
        }
    }

    func postStreamGoLive(streamTitle: String, gameName: String, streamURL: String? = nil) async -> String? {
        var tweetText = "🔴 LIVE NOW!\n\n🎮 \(streamTitle)\n\nPlaying: \(gameName)\n\n#RetroGaming #LiveStream #Gaming"

        if let url = streamURL {
            tweetText += "\n\n📺 Watch: \(url)"
        }

        return await postTweet(tweetText)
    }

    func postHighlight(description: String, videoURL: String? = nil) async -> String? {
        var tweetText = "✨ Stream Highlight!\n\n\(description)\n\n#RetroGaming #Gaming #Highlights"

        if let url = videoURL {
            tweetText += "\n\n🎥 Watch: \(url)"
        }

        return await postTweet(tweetText)
    }

    func postScheduleUpdate(nextStream: String, gameTitle: String) async -> String? {
        let tweetText = "📅 Next Stream: \(nextStream)\n\n🎮 Playing: \(gameTitle)\n\nSee you there! 🎉\n\n#RetroGaming #Schedule #Gaming"
        return await postTweet(tweetText)
    }

    // MARK: - PKCE Helper Methods
    private func generateCodeVerifier() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
        return String((0..<128).compactMap { _ in characters.randomElement() })
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        guard let data = verifier.data(using: .utf8) else { return "" }
        let hash = SHA256.hash(data: data)
        return Data(hash).base64URLEncodedString()
    }
}

// MARK: - Data Models
struct TwitterTokenResponse: Codable {
    let access_token: String
    let refresh_token: String?
    let expires_in: Int?
    let token_type: String
}

struct TwitterUserResponse: Codable {
    let data: TwitterUser
}

struct TwitterUser: Codable {
    let id: String
    let name: String
    let username: String
    let profile_image_url: String?
    let public_metrics: TwitterPublicMetrics?
}

struct TwitterPublicMetrics: Codable {
    let followers_count: Int
    let following_count: Int
    let tweet_count: Int
    let listed_count: Int
}

struct TwitterTweetResponse: Codable {
    let data: TwitterTweet
}

struct TwitterTweet: Codable {
    let id: String
    let text: String
}

// MARK: - SHA256 Extension for PKCE
import CryptoKit

extension Data {
    func base64URLEncodedString() -> String {
        return self.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}