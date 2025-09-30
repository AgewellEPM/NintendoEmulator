import Foundation
import Security
import CryptoKit
import AppKit

/// Secure OAuth manager following OWASP best practices
public class SecureOAuthManager: ObservableObject {
    private let keychain = KeychainTokenStorage()
    private var pendingStates: [String: OAuthSession] = [:]

    public init() {}

    public func initiateOAuth(for platform: SocialPlatform, completion: @escaping (Result<String, SecureOAuthError>) -> Void) {
        // Generate cryptographically secure state and PKCE parameters
        let state = generateSecureState()
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)

        // Store session securely with expiration
        let session = OAuthSession(
            platform: platform,
            state: state,
            codeVerifier: codeVerifier,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(600) // 10 minutes
        )

        pendingStates[state] = session

        // Build secure OAuth URL
        guard let oauthURL = buildSecureOAuthURL(
            platform: platform,
            state: state,
            codeChallenge: codeChallenge
        ) else {
            completion(.failure(.invalidConfiguration))
            return
        }

        // Validate URL before opening
        guard validateURL(oauthURL) else {
            completion(.failure(.invalidURL))
            return
        }

        NSWorkspace.shared.open(oauthURL)
        completion(.success(state))
    }

    public func handleCallback(url: URL) -> Result<OAuthToken, SecureOAuthError> {
        // Extract and validate parameters
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return .failure(.invalidCallback)
        }

        let params = Dictionary<String, String>(uniqueKeysWithValues: queryItems.compactMap { item in
            guard let value = item.value else { return nil }
            return (item.name, value)
        })

        // Validate state parameter (CSRF protection)
        guard let receivedState = params["state"],
              let session = pendingStates[receivedState],
              session.expiresAt > Date() else {
            return .failure(.invalidState)
        }

        // Clean up session
        pendingStates.removeValue(forKey: receivedState)

        // Check for error parameters
        if let error = params["error"] {
            return .failure(.authorizationDenied(error))
        }

        guard let code = params["code"] else {
            return .failure(.missingAuthorizationCode)
        }

        // Exchange code for token (this would be an async network call in practice)
        return exchangeCodeForToken(code: code, session: session)
    }

    private func generateSecureState() -> String {
        return Data.random(length: 32).base64URLEncodedString()
    }

    private func generateCodeVerifier() -> String {
        return Data.random(length: 32).base64URLEncodedString()
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash).base64URLEncodedString()
    }

    private func buildSecureOAuthURL(platform: SocialPlatform, state: String, codeChallenge: String) -> URL? {
        // Get platform-specific configuration from secure storage
        guard let config = getOAuthConfig(for: platform) else { return nil }

        var components = URLComponents(string: config.authorizationEndpoint)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: config.clientId),
            URLQueryItem(name: "redirect_uri", value: config.redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "scope", value: config.scopes.joined(separator: " "))
        ]

        return components?.url
    }

    private func validateURL(_ url: URL) -> Bool {
        // Validate URL scheme and host
        guard let scheme = url.scheme?.lowercased(),
              ["https"].contains(scheme) else {
            return false
        }

        // Validate against allowed hosts
        let allowedHosts = [
            "id.twitch.tv",
            "accounts.google.com",
            "discord.com",
            "twitter.com",
            "api.instagram.com",
            "www.tiktok.com"
        ]

        guard let host = url.host?.lowercased(),
              allowedHosts.contains(host) else {
            return false
        }

        return true
    }

    private func getOAuthConfig(for platform: SocialPlatform) -> OAuthConfig? {
        // In production, this would load from secure configuration
        // Never hardcode credentials in source code
        // Return placeholder OAuth configuration
        // In production, load these from secure environment variables
        switch platform {
        case .twitch:
            return OAuthConfig(
                clientId: "your_twitch_client_id_here",
                redirectUri: "universalemulator://twitch/callback",
                authorizationEndpoint: "https://id.twitch.tv/oauth2/authorize",
                tokenEndpoint: "https://id.twitch.tv/oauth2/token",
                scopes: ["user:read:email", "channel:read:stream_key"]
            )
        case .youtube:
            return OAuthConfig(
                clientId: "your_youtube_client_id_here",
                redirectUri: "universalemulator://youtube/callback",
                authorizationEndpoint: "https://accounts.google.com/o/oauth2/v2/auth",
                tokenEndpoint: "https://oauth2.googleapis.com/token",
                scopes: ["https://www.googleapis.com/auth/youtube"]
            )
        default:
            return OAuthConfig(
                clientId: "placeholder_client_id",
                redirectUri: "universalemulator://callback",
                authorizationEndpoint: "https://example.com/oauth/authorize",
                tokenEndpoint: "https://example.com/oauth/token",
                scopes: ["basic"]
            )
        }
    }

    private func exchangeCodeForToken(code: String, session: OAuthSession) -> Result<OAuthToken, SecureOAuthError> {
        // This is a placeholder - in practice this would be an async network call
        // with proper error handling, retry logic, and token validation
        .failure(.notImplemented)
    }
}

// MARK: - Supporting Types

public struct OAuthSession {
    let platform: SocialPlatform
    let state: String
    let codeVerifier: String
    let createdAt: Date
    let expiresAt: Date
}

public struct OAuthConfig {
    let clientId: String
    let redirectUri: String
    let authorizationEndpoint: String
    let tokenEndpoint: String
    let scopes: [String]
}

public struct OAuthToken {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date
    let scopes: [String]
}

public enum SecureOAuthError: Error, LocalizedError {
    case invalidConfiguration
    case invalidURL
    case invalidCallback
    case invalidState
    case authorizationDenied(String)
    case missingAuthorizationCode
    case tokenExchangeFailed
    case notImplemented

    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "OAuth configuration is invalid"
        case .invalidURL:
            return "Invalid OAuth URL"
        case .invalidCallback:
            return "Invalid OAuth callback"
        case .invalidState:
            return "Invalid or expired OAuth state"
        case .authorizationDenied(let error):
            return "Authorization denied: \(error)"
        case .missingAuthorizationCode:
            return "Missing authorization code"
        case .tokenExchangeFailed:
            return "Failed to exchange code for token"
        case .notImplemented:
            return "OAuth flow not fully implemented"
        }
    }
}

// MARK: - Extensions

extension Data {
    static func random(length: Int) -> Data {
        var data = Data(count: length)
        _ = data.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, length, $0.baseAddress!) }
        return data
    }

    func base64URLEncodedString() -> String {
        return base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

public enum SocialPlatform: String, CaseIterable {
    case twitch = "Twitch"
    case youtube = "YouTube"
    case discord = "Discord"
    case twitter = "Twitter"
    case instagram = "Instagram"
    case tiktok = "TikTok"
}