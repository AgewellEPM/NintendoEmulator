import Foundation
import Security

/// Sprint 1 - AUTH-001: Secure Token Storage using Keychain
/// Handles secure storage of authentication tokens
public protocol SecureTokenStorage {
    func store(accessToken: String, refreshToken: String) async throws
    func getAccessToken() async throws -> String
    func getRefreshToken() async throws -> String
    func clearTokens() async throws
}

public class KeychainTokenStorage: SecureTokenStorage {
    private let service = "com.nintendoemulator.auth"
    private let accessTokenKey = "access_token"
    private let refreshTokenKey = "refresh_token"

    public init() {}

    public func store(accessToken: String, refreshToken: String) async throws {
        try await storeToken(accessToken, key: accessTokenKey)
        try await storeToken(refreshToken, key: refreshTokenKey)
        NSLog("🔐 Tokens stored securely in keychain")
    }

    public func getAccessToken() async throws -> String {
        return try await getToken(key: accessTokenKey)
    }

    public func getRefreshToken() async throws -> String {
        return try await getToken(key: refreshTokenKey)
    }

    public func clearTokens() async throws {
        try await deleteToken(key: accessTokenKey)
        try await deleteToken(key: refreshTokenKey)
        NSLog("🔐 Tokens cleared from keychain")
    }

    // MARK: - Private Methods

    private func storeToken(_ token: String, key: String) async throws {
        let data = Data(token.utf8)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        // Delete existing item
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.storeFailed(status)
        }
    }

    private func getToken(key: String) async throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            throw KeychainError.retrieveFailed(status)
        }

        guard let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }

        return token
    }

    private func deleteToken(key: String) async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        // Success or item not found are both acceptable
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}

// MARK: - Keychain Errors

public enum KeychainError: LocalizedError {
    case storeFailed(OSStatus)
    case retrieveFailed(OSStatus)
    case deleteFailed(OSStatus)
    case invalidData

    public var errorDescription: String? {
        switch self {
        case .storeFailed(let status):
            return "Failed to store in keychain: \(status)"
        case .retrieveFailed(let status):
            return "Failed to retrieve from keychain: \(status)"
        case .deleteFailed(let status):
            return "Failed to delete from keychain: \(status)"
        case .invalidData:
            return "Invalid keychain data"
        }
    }
}