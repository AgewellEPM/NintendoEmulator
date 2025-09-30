import Foundation
import Security

/// Secure keychain management for OAuth credentials and tokens
public class KeychainManager {
    public static let shared = KeychainManager()
    private let serviceName = "com.lukekist.NintendoEmulator.oauth"

    public init() {}

    // MARK: - OAuth Configuration Storage

    public func storeOAuthConfig(_ config: OAuthConfig, for platform: SocialPlatform) -> Bool {
        let configData: [String: Any] = [
            "clientId": config.clientId,
            "redirectUri": config.redirectUri,
            "authorizationEndpoint": config.authorizationEndpoint,
            "tokenEndpoint": config.tokenEndpoint,
            "scopes": config.scopes
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: configData) else {
            return false
        }

        return storeData(data, for: "oauth_config_\(platform.rawValue)")
    }

    public func getOAuthConfig(for platform: SocialPlatform) -> OAuthConfig? {
        guard let data = getData(for: "oauth_config_\(platform.rawValue)"),
              let configData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let clientId = configData["clientId"] as? String,
              let redirectUri = configData["redirectUri"] as? String,
              let authEndpoint = configData["authorizationEndpoint"] as? String,
              let tokenEndpoint = configData["tokenEndpoint"] as? String,
              let scopes = configData["scopes"] as? [String] else {
            return nil
        }

        return OAuthConfig(
            clientId: clientId,
            redirectUri: redirectUri,
            authorizationEndpoint: authEndpoint,
            tokenEndpoint: tokenEndpoint,
            scopes: scopes
        )
    }

    // MARK: - Token Storage

    public func storeToken(_ token: OAuthToken, for platform: SocialPlatform) -> Bool {
        let tokenData: [String: Any] = [
            "accessToken": token.accessToken,
            "refreshToken": token.refreshToken ?? "",
            "expiresAt": token.expiresAt.timeIntervalSince1970,
            "scopes": token.scopes
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: tokenData) else {
            return false
        }

        return storeData(data, for: "oauth_token_\(platform.rawValue)")
    }

    public func getToken(for platform: SocialPlatform) -> OAuthToken? {
        guard let data = getData(for: "oauth_token_\(platform.rawValue)"),
              let tokenData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = tokenData["accessToken"] as? String,
              let expiresAtTimestamp = tokenData["expiresAt"] as? TimeInterval,
              let scopes = tokenData["scopes"] as? [String] else {
            return nil
        }

        let refreshToken = tokenData["refreshToken"] as? String
        let expiresAt = Date(timeIntervalSince1970: expiresAtTimestamp)

        return OAuthToken(
            accessToken: accessToken,
            refreshToken: refreshToken?.isEmpty == false ? refreshToken : nil,
            expiresAt: expiresAt,
            scopes: scopes
        )
    }

    public func deleteToken(for platform: SocialPlatform) -> Bool {
        return deleteData(for: "oauth_token_\(platform.rawValue)")
    }

    // MARK: - Generic Secret Storage
    /// Store an arbitrary secret string under a namespaced key in the keychain.
    @discardableResult
    public func setSecret(_ secret: String, for key: String) -> Bool {
        guard let data = secret.data(using: .utf8) else { return false }
        return storeData(data, for: "secret_\(key)")
    }

    /// Retrieve an arbitrary secret string for a namespaced key from the keychain.
    public func getSecret(for key: String) -> String? {
        guard let data = getData(for: "secret_\(key)") else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Delete an arbitrary secret from the keychain.
    @discardableResult
    public func deleteSecret(for key: String) -> Bool {
        deleteData(for: "secret_\(key)")
    }

    // MARK: - Simple Token API (for Social APIs)
    /// Store a token with a simple key - convenience method for Social APIs
    @discardableResult
    public func storeToken(_ token: String, for key: String) -> Bool {
        return setSecret(token, for: key)
    }

    /// Get a token with a simple key - convenience method for Social APIs
    public func getToken(for key: String) -> String? {
        return getSecret(for: key)
    }

    /// Delete a token with a simple key - convenience method for Social APIs
    @discardableResult
    public func deleteToken(for key: String) -> Bool {
        return deleteSecret(for: key)
    }

    // MARK: - Generic Keychain Operations

    private func storeData(_ data: Data, for key: String) -> Bool {
        // First, delete any existing item
        _ = deleteData(for: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    private func getData(for key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data else {
            return nil
        }

        return data
    }

    private func deleteData(for key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Security Utilities

    public func clearAllTokens() -> Bool {
        let platforms = SocialPlatform.allCases
        var success = true

        for platform in platforms {
            if !deleteToken(for: platform) {
                success = false
            }
        }

        return success
    }

    public func validateTokenExpiry(for platform: SocialPlatform) -> Bool {
        guard let token = getToken(for: platform) else {
            return false
        }

        return token.expiresAt > Date()
    }
}
