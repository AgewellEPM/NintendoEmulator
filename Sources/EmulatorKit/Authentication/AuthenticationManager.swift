import Foundation
import Combine
import CryptoKit
import AuthenticationServices

/// Sprint 1 - AUTH-001: Core Authentication System
/// 8 Story Points - Email/Password registration with verification
@MainActor
public class AuthenticationManager: ObservableObject {
    // MARK: - Published Properties
    @Published public internal(set) var currentUser: User?
    @Published public internal(set) var authState: AuthState = .unauthenticated
    @Published public private(set) var lastError: AuthError?

    // MARK: - Internal Properties (for OAuth integration)
    internal let tokenStorage: SecureTokenStorage
    internal let profileManager: UserProfileManager

    // MARK: - Private Properties
    private let apiService: AuthAPIService
    private var cancellables = Set<AnyCancellable>()

    // 🔒 Rate limiting for brute-force protection
    private var failedLoginAttempts: [String: [Date]] = [:]
    private let maxAttempts = 5
    private let lockoutDuration: TimeInterval = 900 // 15 minutes

    // MARK: - Initialization
    public init(
        apiService: AuthAPIService = AuthAPIService(),
        tokenStorage: SecureTokenStorage = KeychainTokenStorage(),
        profileManager: UserProfileManager = UserProfileManager()
    ) {
        self.apiService = apiService
        self.tokenStorage = tokenStorage
        self.profileManager = profileManager

        setupAuthenticationFlow()
        checkExistingAuthentication()
    }

    // MARK: - Public Authentication Methods

    /// Register new user with email and password
    public func registerUser(
        email: String,
        password: String,
        username: String
    ) async throws {
        guard isValidEmail(email) else {
            throw AuthError.invalidEmail
        }

        guard isValidPassword(password) else {
            throw AuthError.weakPassword
        }

        guard isValidUsername(username) else {
            throw AuthError.invalidUsername
        }

        authState = .loading

        do {
            // 🔒 SECURITY: Send plaintext password over HTTPS (TLS-protected)
            // Backend will hash with Argon2id - NEVER hash passwords client-side
            let request = RegisterRequest(
                email: email,
                password: password,  // Plaintext over TLS
                username: username,
                deviceID: await getDeviceID()
            )

            let response = try await apiService.register(request)

            // Store tokens securely
            try await tokenStorage.store(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken
            )

            // Create user profile
            let user = User(
                id: response.userID,
                email: email,
                username: username,
                isEmailVerified: false,
                createdAt: response.createdAt,
                subscription: .free
            )

            currentUser = user
            authState = .authenticatedUnverified

            // Send verification email
            try await sendEmailVerification()

            NSLog("🔐 User registered successfully: %@", username)

        } catch {
            authState = .unauthenticated
            lastError = error as? AuthError ?? .unknown(error.localizedDescription)
            throw error
        }
    }

    /// Sign in existing user
    public func signIn(email: String, password: String) async throws {
        guard isValidEmail(email) else {
            throw AuthError.invalidEmail
        }

        // 🔒 Check if account is locked out due to failed attempts
        if isLockedOut(for: email) {
            let remainingTime = getRemainingLockoutTime(for: email)
            throw AuthError.accountLockedOut(remainingMinutes: Int(ceil(remainingTime / 60)))
        }

        authState = .loading

        do {
            // 🔒 SECURITY: Send plaintext password over HTTPS (TLS-protected)
            // Backend will compare against Argon2id hash
            let request = SignInRequest(
                email: email,
                password: password,  // Plaintext over TLS
                deviceID: await getDeviceID()
            )

            let response = try await apiService.signIn(request)

            // Store tokens securely
            try await tokenStorage.store(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken
            )

            // Load user profile
            let user = try await profileManager.loadProfile(userID: response.userID)
            currentUser = user

            authState = user.isEmailVerified ? .authenticated : .authenticatedUnverified

            // Clear failed attempts on successful login
            failedLoginAttempts.removeValue(forKey: email)

            NSLog("🔐 User signed in successfully: %@", user.username)

        } catch {
            // Record failed attempt
            recordFailedAttempt(for: email)

            let remainingAttempts = maxAttempts - getFailedAttemptCount(for: email)
            if remainingAttempts <= 0 {
                NSLog("🔒 Account locked out: %@", email)
                throw AuthError.accountLockedOut(remainingMinutes: Int(ceil(lockoutDuration / 60)))
            } else if remainingAttempts <= 2 {
                // Warn user when approaching lockout
                NSLog("⚠️ Failed login for %@. %d attempts remaining", email, remainingAttempts)
            }

            authState = .unauthenticated
            lastError = error as? AuthError ?? .unknown(error.localizedDescription)
            throw error
        }
    }

    // MARK: - Rate Limiting Methods

    private func recordFailedAttempt(for email: String) {
        var attempts = failedLoginAttempts[email] ?? []
        attempts.append(Date())

        // Keep only recent attempts within lockout window
        let cutoff = Date().addingTimeInterval(-lockoutDuration)
        attempts = attempts.filter { $0 > cutoff }

        failedLoginAttempts[email] = attempts
    }

    private func isLockedOut(for email: String) -> Bool {
        return getFailedAttemptCount(for: email) >= maxAttempts
    }

    private func getFailedAttemptCount(for email: String) -> Int {
        guard let attempts = failedLoginAttempts[email] else { return 0 }

        let cutoff = Date().addingTimeInterval(-lockoutDuration)
        return attempts.filter { $0 > cutoff }.count
    }

    private func getRemainingLockoutTime(for email: String) -> TimeInterval {
        guard let attempts = failedLoginAttempts[email],
              let firstAttempt = attempts.first else {
            return 0
        }

        let unlockTime = firstAttempt.addingTimeInterval(lockoutDuration)
        return unlockTime.timeIntervalSince(Date())
    }

    /// Sign out current user
    public func signOut() async {
        guard let user = currentUser else { return }

        do {
            // Revoke tokens on server
            if let accessToken = try? await tokenStorage.getAccessToken() {
                try? await apiService.signOut(accessToken: accessToken)
            }

            // Clear local storage
            try await tokenStorage.clearTokens()
            await profileManager.clearProfile()

            currentUser = nil
            authState = .unauthenticated
            lastError = nil

            NSLog("🔐 User signed out: %@", user.username)

        } catch {
            NSLog("⚠️ Error during sign out: %@", error.localizedDescription)
        }
    }

    /// Send email verification
    public func sendEmailVerification() async throws {
        guard let user = currentUser,
              !user.isEmailVerified else { return }

        let accessToken = try await tokenStorage.getAccessToken()
        try await apiService.sendEmailVerification(accessToken: accessToken)

        NSLog("📧 Email verification sent to: %@", user.email)
    }

    /// Verify email with code
    public func verifyEmail(code: String) async throws {
        guard let user = currentUser else {
            throw AuthError.notAuthenticated
        }

        let accessToken = try await tokenStorage.getAccessToken()
        try await apiService.verifyEmail(accessToken: accessToken, code: code)

        // Update user state
        var updatedUser = user
        updatedUser.isEmailVerified = true
        currentUser = updatedUser
        authState = .authenticated

        NSLog("✅ Email verified for user: %@", user.username)
    }

    /// Reset password
    public func resetPassword(email: String) async throws {
        guard isValidEmail(email) else {
            throw AuthError.invalidEmail
        }

        try await apiService.resetPassword(email: email)
        NSLog("📧 Password reset email sent to: %@", email)
    }

    // MARK: - Token Management

    /// Refresh access token
    internal func refreshTokenIfNeeded() async throws {
        guard let refreshToken = try? await tokenStorage.getRefreshToken() else {
            await signOut()
            throw AuthError.notAuthenticated
        }

        do {
            let response = try await apiService.refreshToken(refreshToken: refreshToken)

            try await tokenStorage.store(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken
            )

        } catch {
            await signOut()
            throw error
        }
    }

    // MARK: - Private Methods

    private func setupAuthenticationFlow() {
        // Monitor token expiration
        Timer.publish(every: 300, on: .main, in: .common) // Check every 5 minutes
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in
                    try? await self?.refreshTokenIfNeeded()
                }
            }
            .store(in: &cancellables)
    }

    private func checkExistingAuthentication() {
        Task {
            do {
                let accessToken = try await tokenStorage.getAccessToken()

                // Validate token with server
                let userResponse = try await apiService.getCurrentUser(accessToken: accessToken)

                currentUser = userResponse
                authState = userResponse.isEmailVerified ? .authenticated : .authenticatedUnverified

                NSLog("🔐 Restored authentication for: %@", userResponse.username)

            } catch {
                // No valid authentication found
                try? await tokenStorage.clearTokens()
                authState = .unauthenticated
            }
        }
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }

    private func isValidPassword(_ password: String) -> Bool {
        // Minimum 8 characters, at least one uppercase, lowercase, and number
        guard password.count >= 8 else { return false }

        let hasUppercase = password.rangeOfCharacter(from: .uppercaseLetters) != nil
        let hasLowercase = password.rangeOfCharacter(from: .lowercaseLetters) != nil
        let hasNumber = password.rangeOfCharacter(from: .decimalDigits) != nil

        return hasUppercase && hasLowercase && hasNumber
    }

    private func isValidUsername(_ username: String) -> Bool {
        // 3-20 characters, alphanumeric and underscore only
        guard username.count >= 3 && username.count <= 20 else { return false }

        let usernameRegex = #"^[A-Za-z0-9_]+$"#
        return username.range(of: usernameRegex, options: .regularExpression) != nil
    }

    private func getDeviceID() async -> String {
        // Generate stable device ID for this installation
        let deviceIDKey = "com.nintendoemulator.deviceID"

        if let existingID = UserDefaults.standard.string(forKey: deviceIDKey) {
            return existingID
        }

        let newID = UUID().uuidString
        UserDefaults.standard.set(newID, forKey: deviceIDKey)
        return newID
    }
}

// MARK: - Supporting Types

public enum AuthState: Equatable {
    case unauthenticated
    case loading
    case authenticatedUnverified
    case authenticated
}

public enum AuthError: LocalizedError {
    case invalidEmail
    case invalidUsername
    case weakPassword
    case userExists
    case userNotFound
    case invalidCredentials
    case notAuthenticated
    case emailNotVerified
    case networkError
    case serverError(String)
    case unknown(String)
    case accountLockedOut(remainingMinutes: Int)  // 🔒 Added for rate limiting

    public var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Please enter a valid email address"
        case .invalidUsername:
            return "Username must be 3-20 characters, letters, numbers, and underscore only"
        case .weakPassword:
            return "Password must be at least 8 characters with uppercase, lowercase, and number"
        case .userExists:
            return "An account with this email already exists"
        case .userNotFound:
            return "No account found with this email"
        case .invalidCredentials:
            return "Invalid email or password"
        case .notAuthenticated:
            return "Please sign in to continue"
        case .emailNotVerified:
            return "Please verify your email address"
        case .networkError:
            return "Network connection error. Please check your internet connection"
        case .serverError(let message):
            return "Server error: \(message)"
        case .unknown(let message):
            return "Unknown error: \(message)"
        case .accountLockedOut(let remainingMinutes):
            return "Account temporarily locked due to too many failed login attempts. Please try again in \(remainingMinutes) minute(s)."
        }
    }
}

public struct User: Codable, Identifiable {
    public let id: String
    public let email: String
    public let username: String
    public var isEmailVerified: Bool
    public let createdAt: Date
    public var subscription: SubscriptionTier
    public var profile: UserProfile?

    public init(
        id: String,
        email: String,
        username: String,
        isEmailVerified: Bool,
        createdAt: Date,
        subscription: SubscriptionTier
    ) {
        self.id = id
        self.email = email
        self.username = username
        self.isEmailVerified = isEmailVerified
        self.createdAt = createdAt
        self.subscription = subscription
    }
}

public enum SubscriptionTier: String, Codable, CaseIterable {
    case free = "free"
    case basic = "basic"
    case pro = "pro"
    case creator = "creator"

    public var displayName: String {
        switch self {
        case .free: return "Free"
        case .basic: return "Basic"
        case .pro: return "Pro"
        case .creator: return "Creator"
        }
    }

    public var monthlyPrice: Decimal {
        switch self {
        case .free: return 0
        case .basic: return 9.99
        case .pro: return 19.99
        case .creator: return 29.99
        }
    }
}

// MARK: - Extensions

// ⚠️ REMOVED: Client-side password hashing extension
// 🔒 SECURITY: Passwords must be hashed ONLY on the backend using Argon2id
//
// Why this is correct:
// 1. TLS protects passwords in transit
// 2. Argon2id is memory-hard and GPU-resistant (SHA256 is not)
// 3. Backend controls salt, iterations, and algorithm
// 4. Prevents downgrade attacks
// 5. Allows easy algorithm upgrades without client updates
//
// Backend implementation (example):
// ```javascript
// const argon2 = require('argon2');
// const hash = await argon2.hash(password, {
//     type: argon2.argon2id,
//     memoryCost: 65536,
//     timeCost: 3,
//     parallelism: 4
// });
// ```