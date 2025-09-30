import Foundation

/// Sprint 1 - AUTH-001: API Service for Authentication
/// Backend communication layer for user authentication
public class AuthAPIService {
    internal let baseURL: URL
    internal let session: URLSession

    public init(baseURL: String = "https://api.nintendoemulator.app/v1") {
        self.baseURL = URL(string: baseURL)!

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    // MARK: - Authentication Requests

    public func register(_ request: RegisterRequest) async throws -> AuthResponse {
        let url = baseURL.appendingPathComponent("/auth/register")
        return try await performRequest(url: url, method: "POST", body: request)
    }

    public func signIn(_ request: SignInRequest) async throws -> AuthResponse {
        let url = baseURL.appendingPathComponent("/auth/signin")
        return try await performRequest(url: url, method: "POST", body: request)
    }

    public func signOut(accessToken: String) async throws {
        let url = baseURL.appendingPathComponent("/auth/signout")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError
        }

        if httpResponse.statusCode >= 400 {
            throw AuthError.serverError("Sign out failed")
        }
    }

    public func refreshToken(refreshToken: String) async throws -> RefreshResponse {
        let url = baseURL.appendingPathComponent("/auth/refresh")
        let request = RefreshRequest(refreshToken: refreshToken)
        return try await performRequest(url: url, method: "POST", body: request)
    }

    public func getCurrentUser(accessToken: String) async throws -> User {
        let url = baseURL.appendingPathComponent("/auth/me")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError
        }

        if httpResponse.statusCode == 401 {
            throw AuthError.notAuthenticated
        }

        if httpResponse.statusCode >= 400 {
            throw AuthError.serverError("Failed to get user info")
        }

        return try JSONDecoder.default.decode(User.self, from: data)
    }

    public func sendEmailVerification(accessToken: String) async throws {
        let url = baseURL.appendingPathComponent("/auth/verify-email/send")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError
        }

        if httpResponse.statusCode >= 400 {
            throw AuthError.serverError("Failed to send verification email")
        }
    }

    public func verifyEmail(accessToken: String, code: String) async throws {
        let url = baseURL.appendingPathComponent("/auth/verify-email")
        let request = VerifyEmailRequest(code: code)

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \\(accessToken)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder.default.encode(request)

        let (_, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError
        }

        if httpResponse.statusCode >= 400 {
            throw AuthError.serverError("Email verification failed")
        }
    }

    public func resetPassword(email: String) async throws {
        let url = baseURL.appendingPathComponent("/auth/reset-password")
        let request = ResetPasswordRequest(email: email)
        let _: EmptyResponse = try await performRequest(url: url, method: "POST", body: request)
    }

    // MARK: - Private Methods

    private func performRequest<T: Encodable, R: Decodable>(
        url: URL,
        method: String,
        body: T
    ) async throws -> R {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Nintendo-Emulator/1.0", forHTTPHeaderField: "User-Agent")

        request.httpBody = try JSONEncoder.default.encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError
        }

        // Handle HTTP errors
        switch httpResponse.statusCode {
        case 200...299:
            break
        case 400:
            throw AuthError.invalidCredentials
        case 409:
            throw AuthError.userExists
        case 404:
            throw AuthError.userNotFound
        case 500...599:
            throw AuthError.serverError("Server error \(httpResponse.statusCode)")
        default:
            throw AuthError.unknown("HTTP \(httpResponse.statusCode)")
        }

        return try JSONDecoder.default.decode(R.self, from: data)
    }
}

// MARK: - Request/Response Types

public struct RegisterRequest: Codable {
    let email: String
    let password: String
    let username: String
    let deviceID: String
}

public struct SignInRequest: Codable {
    let email: String
    let password: String
    let deviceID: String
}

public struct RefreshRequest: Codable {
    let refreshToken: String
}

public struct VerifyEmailRequest: Codable {
    let code: String
}

public struct ResetPasswordRequest: Codable {
    let email: String
}

public struct AuthResponse: Codable {
    let userID: String
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let createdAt: Date
}

public struct RefreshResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
}

private struct EmptyResponse: Codable {}

// MARK: - JSON Coding Extensions

extension JSONEncoder {
    static let `default`: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

extension JSONDecoder {
    static let `default`: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}