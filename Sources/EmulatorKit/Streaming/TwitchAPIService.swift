import Foundation
import Combine

/// Sprint 2 - STREAM-001: Twitch API Integration Service
/// Handles direct streaming to Twitch platform with OAuth authentication
public class TwitchAPIService {
    private let baseURL = URL(string: "https://api.twitch.tv/helix")!
    private let session: URLSession
    private let clientID: String
    private let clientSecret: String

    @Published public private(set) var isConnected = false
    @Published public private(set) var currentChannel: TwitchChannel?

    public init(clientID: String = "", clientSecret: String = "") {
        self.clientID = clientID
        self.clientSecret = clientSecret

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }

    // MARK: - OAuth Authentication

    /// Generate Twitch OAuth authorization URL
    public func generateAuthorizationURL(redirectURI: String) -> URL {
        let scope = "channel:manage:broadcast+channel:read:stream_key+channel:manage:videos+user:read:broadcast"
        var components = URLComponents(string: "https://id.twitch.tv/oauth2/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "state", value: generateState())
        ]
        return components.url!
    }

    /// Exchange authorization code for access token
    public func exchangeCodeForToken(code: String, redirectURI: String) async throws -> TwitchAuthResponse {
        let url = URL(string: "https://id.twitch.tv/oauth2/token")!
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

        let authResponse = try JSONDecoder().decode(TwitchAuthResponse.self, from: data)
        await storeCredentials(authResponse)
        return authResponse
    }

    // MARK: - Stream Management

    /// Get current stream information
    public func getCurrentStream() async throws -> TwitchStream? {
        guard let userID = await getCurrentUserID() else {
            throw StreamingError.notAuthenticated
        }

        let url = baseURL.appendingPathComponent("streams")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "user_id", value: userID)]

        let request = try await createAuthenticatedRequest(url: components.url!)
        let (data, response) = try await session.data(for: request)

        try validateResponse(response)

        let streamResponse = try JSONDecoder().decode(TwitchStreamsResponse.self, from: data)
        return streamResponse.data.first
    }

    /// Update stream information (title, category, etc.)
    public func updateStreamInfo(title: String?, categoryID: String?) async throws {
        guard let userID = await getCurrentUserID() else {
            throw StreamingError.notAuthenticated
        }

        let url = baseURL.appendingPathComponent("channels")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "broadcaster_id", value: userID)]

        var request = try await createAuthenticatedRequest(url: components.url!)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var updateData: [String: Any] = [:]
        if let title = title { updateData["title"] = title }
        if let categoryID = categoryID { updateData["game_id"] = categoryID }

        request.httpBody = try JSONSerialization.data(withJSONObject: updateData)

        let (_, response) = try await session.data(for: request)
        try validateResponse(response)

        NSLog("🎮 Stream info updated successfully")
    }

    /// Get stream key for broadcasting
    public func getStreamKey() async throws -> String {
        guard let userID = await getCurrentUserID() else {
            throw StreamingError.notAuthenticated
        }

        let url = baseURL.appendingPathComponent("streams/key")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "broadcaster_id", value: userID)]

        let request = try await createAuthenticatedRequest(url: components.url!)
        let (data, response) = try await session.data(for: request)

        try validateResponse(response)

        let keyResponse = try JSONDecoder().decode(TwitchStreamKeyResponse.self, from: data)
        guard let streamKey = keyResponse.data.first?.stream_key else {
            throw StreamingError.streamKeyNotFound
        }

        return streamKey
    }

    /// Search for game categories
    public func searchCategories(query: String) async throws -> [TwitchCategory] {
        let url = baseURL.appendingPathComponent("games")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "name", value: query)]

        let request = try await createAuthenticatedRequest(url: components.url!)
        let (data, response) = try await session.data(for: request)

        try validateResponse(response)

        let categoriesResponse = try JSONDecoder().decode(TwitchCategoriesResponse.self, from: data)
        return categoriesResponse.data
    }

    /// Get user information
    public func getUserInfo() async throws -> TwitchUser {
        let url = baseURL.appendingPathComponent("users")
        let request = try await createAuthenticatedRequest(url: url)
        let (data, response) = try await session.data(for: request)

        try validateResponse(response)

        let userResponse = try JSONDecoder().decode(TwitchUsersResponse.self, from: data)
        guard let user = userResponse.data.first else {
            throw StreamingError.userNotFound
        }

        return user
    }

    // MARK: - Connection Management

    /// Test connection to Twitch API
    public func testConnection() async throws -> Bool {
        do {
            _ = try await getUserInfo()
            await MainActor.run { isConnected = true }
            return true
        } catch {
            await MainActor.run { isConnected = false }
            throw error
        }
    }

    /// Disconnect from Twitch
    public func disconnect() async {
        await clearStoredCredentials()
        await MainActor.run {
            isConnected = false
            currentChannel = nil
        }
    }

    // MARK: - Private Methods

    private func createAuthenticatedRequest(url: URL) async throws -> URLRequest {
        guard let accessToken = await getStoredAccessToken() else {
            throw StreamingError.notAuthenticated
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(clientID, forHTTPHeaderField: "Client-Id")
        return request
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

    private func getCurrentUserID() async -> String? {
        return await getStoredUserID()
    }

    // MARK: - Credential Storage

    @MainActor
    private func storeCredentials(_ response: TwitchAuthResponse) async {
        UserDefaults.standard.set(response.access_token, forKey: "twitch_access_token")
        UserDefaults.standard.set(response.refresh_token, forKey: "twitch_refresh_token")

        // Get user info and store user ID
        do {
            let user = try await getUserInfo()
            UserDefaults.standard.set(user.id, forKey: "twitch_user_id")

            currentChannel = TwitchChannel(
                id: user.id,
                displayName: user.display_name,
                login: user.login,
                profileImageURL: user.profile_image_url
            )
            isConnected = true
        } catch {
            NSLog("⚠️ Failed to fetch user info after authentication: \(error)")
        }
    }

    private func getStoredAccessToken() async -> String? {
        return UserDefaults.standard.string(forKey: "twitch_access_token")
    }

    private func getStoredUserID() async -> String? {
        return UserDefaults.standard.string(forKey: "twitch_user_id")
    }

    private func clearStoredCredentials() async {
        UserDefaults.standard.removeObject(forKey: "twitch_access_token")
        UserDefaults.standard.removeObject(forKey: "twitch_refresh_token")
        UserDefaults.standard.removeObject(forKey: "twitch_user_id")
    }
}

// MARK: - Data Models

public struct TwitchAuthResponse: Codable {
    let access_token: String
    let refresh_token: String
    let expires_in: Int
    let token_type: String
    let scope: [String]
}

public struct TwitchChannel: Codable, Identifiable {
    public let id: String
    public let displayName: String
    public let login: String
    public let profileImageURL: String?
}

public struct TwitchStream: Codable, Identifiable {
    public let id: String
    public let user_id: String
    public let user_login: String
    public let user_name: String
    public let game_id: String
    public let game_name: String
    public let title: String
    public let viewer_count: Int
    public let started_at: String
    public let language: String
    public let thumbnail_url: String
}

public struct TwitchUser: Codable, Identifiable {
    public let id: String
    public let login: String
    public let display_name: String
    public let type: String
    public let broadcaster_type: String
    public let description: String
    public let profile_image_url: String
    public let offline_image_url: String
    public let view_count: Int
    public let created_at: String
}

public struct TwitchCategory: Codable, Identifiable {
    public let id: String
    public let name: String
    public let box_art_url: String
    public let igdb_id: String?
}

// MARK: - API Response Wrappers

private struct TwitchStreamsResponse: Codable {
    let data: [TwitchStream]
}

private struct TwitchUsersResponse: Codable {
    let data: [TwitchUser]
}

private struct TwitchCategoriesResponse: Codable {
    let data: [TwitchCategory]
}

private struct TwitchStreamKeyResponse: Codable {
    let data: [TwitchStreamKeyData]
}

private struct TwitchStreamKeyData: Codable {
    let stream_key: String
}

// MARK: - Error Types

public enum StreamingError: LocalizedError {
    case notAuthenticated
    case authenticationFailed
    case networkError
    case serverError(String)
    case resourceNotFound
    case streamKeyNotFound
    case userNotFound
    case rateLimited
    case invalidConfiguration
    case ghostBridgeNotReady

    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated with streaming platform"
        case .authenticationFailed:
            return "Authentication with streaming platform failed"
        case .networkError:
            return "Network connection error"
        case .serverError(let message):
            return "Server error: \(message)"
        case .resourceNotFound:
            return "Requested resource not found"
        case .streamKeyNotFound:
            return "Stream key not found"
        case .userNotFound:
            return "User not found"
        case .rateLimited:
            return "Rate limit exceeded. Please try again later"
        case .invalidConfiguration:
            return "Invalid streaming configuration"
        case .ghostBridgeNotReady:
            return "GhostBridge is not ready. Please ensure all permissions are granted."
        }
    }
}