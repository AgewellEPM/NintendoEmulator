import Foundation
import Combine
import EmulatorKit

class TwitchAPIManager: ObservableObject {
    private let clientId = SocialAPIConfig.Twitch.clientId
    private let redirectURI = SocialAPIConfig.Twitch.redirectURI
    private let baseURL = "https://api.twitch.tv/helix"

    @Published var isConnected = false
    @Published var userInfo: TwitchUser?
    @Published var streamInfo: TwitchStream?

    func authenticate() -> URL? {
        let scopes = [
            "user:read:email",
            "channel:read:stream_key",
            "channel:manage:broadcast",
            "chat:read",
            "chat:edit",
            "channel:moderate"
        ].joined(separator: "%20")

        let authURL = "https://id.twitch.tv/oauth2/authorize?" +
            "client_id=\(clientId)&" +
            "redirect_uri=\(redirectURI)&" +
            "response_type=code&" +
            "scope=\(scopes)&" +
            "force_verify=true"

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
        let tokenURL = "https://id.twitch.tv/oauth2/token"

        var request = URLRequest(url: URL(string: tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyString = "client_id=\(clientId)&" +
            "client_secret=\(SocialAPIConfig.Twitch.clientSecret)&" +
            "code=\(code)&" +
            "grant_type=authorization_code&" +
            "redirect_uri=\(redirectURI)"

        request.httpBody = bodyString.data(using: .utf8)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let tokenResponse = try JSONDecoder().decode(TwitchTokenResponse.self, from: data)

            // Store token securely
            KeychainManager.shared.storeToken(tokenResponse.access_token, for: "twitch_access_token")
            KeychainManager.shared.storeToken(tokenResponse.refresh_token ?? "", for: "twitch_refresh_token")

            await MainActor.run {
                isConnected = true
            }

            await getUserInfo()

        } catch {
            print("Twitch token exchange error: \(error)")
        }
    }

    func getUserInfo() async {
        guard let token = KeychainManager.shared.getToken(for: "twitch_access_token") else { return }

        var request = URLRequest(url: URL(string: "\(baseURL)/users")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(clientId, forHTTPHeaderField: "Client-Id")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(TwitchUsersResponse.self, from: data)

            await MainActor.run {
                userInfo = response.data.first
            }
        } catch {
            print("Twitch user info error: \(error)")
        }
    }

    func getStreamInfo() async {
        guard let token = KeychainManager.shared.getToken(for: "twitch_access_token"),
              let userId = userInfo?.id else { return }

        var request = URLRequest(url: URL(string: "\(baseURL)/streams?user_id=\(userId)")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(clientId, forHTTPHeaderField: "Client-Id")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(TwitchStreamsResponse.self, from: data)

            await MainActor.run {
                streamInfo = response.data.first
            }
        } catch {
            print("Twitch stream info error: \(error)")
        }
    }

    func updateStreamTitle(_ title: String) async {
        guard let token = KeychainManager.shared.getToken(for: "twitch_access_token"),
              let userId = userInfo?.id else { return }

        let updateData = ["title": title]
        let jsonData = try? JSONSerialization.data(withJSONObject: updateData)

        var request = URLRequest(url: URL(string: "\(baseURL)/channels?broadcaster_id=\(userId)")!)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(clientId, forHTTPHeaderField: "Client-Id")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        do {
            let _ = try await URLSession.shared.data(for: request)
            print("✅ Twitch stream title updated")
        } catch {
            print("Twitch update title error: \(error)")
        }
    }

    func getStreamKey() async -> String? {
        guard let token = KeychainManager.shared.getToken(for: "twitch_access_token"),
              let userId = userInfo?.id else { return nil }

        var request = URLRequest(url: URL(string: "\(baseURL)/streams/key?broadcaster_id=\(userId)")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(clientId, forHTTPHeaderField: "Client-Id")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(TwitchStreamKeyResponse.self, from: data)
            return response.data.first?.stream_key
        } catch {
            print("Twitch stream key error: \(error)")
            return nil
        }
    }
}

// MARK: - Data Models
struct TwitchTokenResponse: Codable {
    let access_token: String
    let refresh_token: String?
    let expires_in: Int
    let token_type: String
}

struct TwitchUsersResponse: Codable {
    let data: [TwitchUser]
}

struct TwitchUser: Codable {
    let id: String
    let login: String
    let display_name: String
    let email: String?
    let profile_image_url: String
    let view_count: Int
    let broadcaster_type: String
}

struct TwitchStreamsResponse: Codable {
    let data: [TwitchStream]
}

struct TwitchStream: Codable {
    let id: String
    let user_id: String
    let user_login: String
    let user_name: String
    let game_id: String
    let game_name: String
    let title: String
    let viewer_count: Int
    let started_at: String
    let thumbnail_url: String
}

struct TwitchStreamKeyResponse: Codable {
    let data: [TwitchStreamKey]
}

struct TwitchStreamKey: Codable {
    let stream_key: String
}