import Foundation
import AuthenticationServices
import Combine

/// Sprint 1 - AUTH-002: OAuth Integration for Apple and Google
/// 5 Story Points - Social login implementation
@MainActor
public class OAuthManager: NSObject, ObservableObject {
    @Published public private(set) var isLoading = false
    @Published public private(set) var lastError: OAuthError?

    private let authManager: AuthenticationManager
    private let apiService: AuthAPIService

    public init(
        authManager: AuthenticationManager,
        apiService: AuthAPIService = AuthAPIService()
    ) {
        self.authManager = authManager
        self.apiService = apiService
        super.init()
    }

    // MARK: - Sign in with Apple

    public func signInWithApple() async throws {
        isLoading = true
        lastError = nil

        do {
            let appleIDCredential = try await requestAppleIDCredential()
            try await processAppleSignIn(credential: appleIDCredential)

            NSLog("🍎 Sign in with Apple completed successfully")

        } catch {
            let oauthError = error as? OAuthError ?? .appleSignInFailed(error.localizedDescription)
            lastError = oauthError
            isLoading = false
            throw oauthError
        }

        isLoading = false
    }

    private func requestAppleIDCredential() async throws -> ASAuthorizationAppleIDCredential {
        return try await withCheckedThrowingContinuation { continuation in
            let appleIDProvider = ASAuthorizationAppleIDProvider()
            let request = appleIDProvider.createRequest()
            request.requestedScopes = [.fullName, .email]

            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            // Hold a strong reference to the delegate for the duration of the request
            let strongDelegate = AppleSignInDelegate { result in
                continuation.resume(with: result)
            }
            authorizationController.delegate = strongDelegate
            objc_setAssociatedObject(authorizationController, Unmanaged.passUnretained(self).toOpaque(), strongDelegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            authorizationController.presentationContextProvider = self

            authorizationController.performRequests()
        }
    }

    private func processAppleSignIn(credential: ASAuthorizationAppleIDCredential) async throws {
        guard let identityToken = credential.identityToken,
              let identityTokenString = String(data: identityToken, encoding: .utf8) else {
            throw OAuthError.invalidAppleToken
        }

        let request = AppleSignInRequest(
            identityToken: identityTokenString,
            authorizationCode: credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) },
            userIdentifier: credential.user,
            email: credential.email,
            fullName: PersonNameComponents(from: credential.fullName),
            deviceID: await getDeviceID()
        )

        let response = try await apiService.signInWithApple(request)

        // Store tokens and update auth state
        try await authManager.tokenStorage.store(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken
        )

        let user = try await authManager.profileManager.loadProfile(userID: response.userID)
        authManager.currentUser = user
        authManager.authState = user.isEmailVerified ? .authenticated : .authenticatedUnverified
    }

    // MARK: - Sign in with Google

    public func signInWithGoogle() async throws {
        isLoading = true
        lastError = nil

        do {
            let googleCredential = try await requestGoogleCredential()
            try await processGoogleSignIn(credential: googleCredential)

            NSLog("🔵 Sign in with Google completed successfully")

        } catch {
            let oauthError = error as? OAuthError ?? .googleSignInFailed(error.localizedDescription)
            lastError = oauthError
            isLoading = false
            throw oauthError
        }

        isLoading = false
    }

    private func requestGoogleCredential() async throws -> GoogleSignInCredential {
        // Note: In a real implementation, you'd use GoogleSignIn SDK
        // For now, we'll simulate the flow with a web-based OAuth
        return try await performWebBasedGoogleAuth()
    }

    private func performWebBasedGoogleAuth() async throws -> GoogleSignInCredential {
        // Simulate Google OAuth web flow
        // In production, this would open a web view with Google OAuth
        throw OAuthError.googleSignInFailed("Google Sign-In not yet implemented - requires GoogleSignIn SDK")
    }

    private func processGoogleSignIn(credential: GoogleSignInCredential) async throws {
        let request = GoogleSignInRequest(
            idToken: credential.idToken,
            accessToken: credential.accessToken,
            email: credential.email,
            name: credential.name,
            deviceID: await getDeviceID()
        )

        let response = try await apiService.signInWithGoogle(request)

        // Store tokens and update auth state
        try await authManager.tokenStorage.store(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken
        )

        let user = try await authManager.profileManager.loadProfile(userID: response.userID)
        authManager.currentUser = user
        authManager.authState = .authenticated // Google emails are pre-verified
    }

    // MARK: - Account Linking

    public func linkAppleAccount() async throws {
        guard authManager.currentUser != nil else {
            throw OAuthError.notAuthenticated
        }

        let appleCredential = try await requestAppleIDCredential()
        try await linkAppleAccountInternal(credential: appleCredential)
    }

    private func linkAppleAccountInternal(credential: ASAuthorizationAppleIDCredential) async throws {
        guard let identityToken = credential.identityToken,
              let identityTokenString = String(data: identityToken, encoding: .utf8) else {
            throw OAuthError.invalidAppleToken
        }

        let accessToken = try await authManager.tokenStorage.getAccessToken()

        let request = LinkAppleAccountRequest(
            identityToken: identityTokenString,
            userIdentifier: credential.user
        )

        try await apiService.linkAppleAccount(accessToken: accessToken, request: request)

        NSLog("🔗 Apple account linked successfully")
    }

    // MARK: - Helper Methods

    private func getDeviceID() async -> String {
        let deviceIDKey = "com.nintendoemulator.deviceID"

        if let existingID = UserDefaults.standard.string(forKey: deviceIDKey) {
            return existingID
        }

        let newID = UUID().uuidString
        UserDefaults.standard.set(newID, forKey: deviceIDKey)
        return newID
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension OAuthManager: ASAuthorizationControllerPresentationContextProviding {
    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let window = NSApplication.shared.windows.first else {
            fatalError("No window available for Apple Sign In")
        }
        return window
    }
}

// MARK: - Apple Sign In Delegate

private class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate {
    private let completion: (Result<ASAuthorizationAppleIDCredential, Error>) -> Void

    init(completion: @escaping (Result<ASAuthorizationAppleIDCredential, Error>) -> Void) {
        self.completion = completion
        super.init()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            completion(.success(appleIDCredential))
        } else {
            completion(.failure(OAuthError.invalidAppleToken))
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        completion(.failure(error))
    }
}

// MARK: - OAuth Errors

public enum OAuthError: LocalizedError {
    case notAuthenticated
    case appleSignInFailed(String)
    case googleSignInFailed(String)
    case invalidAppleToken
    case invalidGoogleToken
    case accountAlreadyLinked
    case linkingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in first"
        case .appleSignInFailed(let message):
            return "Apple Sign In failed: \(message)"
        case .googleSignInFailed(let message):
            return "Google Sign In failed: \(message)"
        case .invalidAppleToken:
            return "Invalid Apple ID token"
        case .invalidGoogleToken:
            return "Invalid Google token"
        case .accountAlreadyLinked:
            return "This account is already linked"
        case .linkingFailed(let message):
            return "Account linking failed: \(message)"
        }
    }
}

// MARK: - OAuth Data Types

public struct AppleSignInRequest: Codable {
    let identityToken: String
    let authorizationCode: String?
    let userIdentifier: String
    let email: String?
    let fullName: PersonNameComponents?
    let deviceID: String
}

public struct GoogleSignInRequest: Codable {
    let idToken: String
    let accessToken: String
    let email: String
    let name: String?
    let deviceID: String
}

public struct LinkAppleAccountRequest: Codable {
    let identityToken: String
    let userIdentifier: String
}

public struct GoogleSignInCredential {
    let idToken: String
    let accessToken: String
    let email: String
    let name: String?
}

extension PersonNameComponents {
    init?(from nameComponents: PersonNameComponents?) {
        guard let components = nameComponents else { return nil }
        self = components
    }
}

// MARK: - API Service Extensions

extension AuthAPIService {
    public func signInWithApple(_ request: AppleSignInRequest) async throws -> AuthResponse {
        let url = baseURL.appendingPathComponent("/auth/apple")
        return try await performRequest(url: url, method: "POST", body: request)
    }

    public func signInWithGoogle(_ request: GoogleSignInRequest) async throws -> AuthResponse {
        let url = baseURL.appendingPathComponent("/auth/google")
        return try await performRequest(url: url, method: "POST", body: request)
    }

    public func linkAppleAccount(accessToken: String, request: LinkAppleAccountRequest) async throws {
        let url = baseURL.appendingPathComponent("/auth/link/apple")

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \\(accessToken)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder.default.encode(request)

        let (_, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OAuthError.linkingFailed("Failed to link Apple account")
        }
    }

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
            throw OAuthError.accountAlreadyLinked
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
