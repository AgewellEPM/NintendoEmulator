import Foundation
import Combine

/// Sprint 1 - AUTH-003: User Profile Management System
/// Handles user profile data and preferences
public class UserProfileManager: ObservableObject {
    @Published public private(set) var currentProfile: UserProfile?

    private let apiService: ProfileAPIService
    private let localStorage: UserProfileStorage

    public init(
        apiService: ProfileAPIService = ProfileAPIService(),
        localStorage: UserProfileStorage = FileSystemProfileStorage()
    ) {
        self.apiService = apiService
        self.localStorage = localStorage
    }

    // MARK: - Profile Management

    public func loadProfile(userID: String) async throws -> User {
        // Try to load from local cache first
        if let cachedProfile = try? await localStorage.loadProfile(userID: userID) {
            currentProfile = cachedProfile
            NSLog("📱 Loaded cached profile for user: %@", userID)
        }

        // Fetch latest from server
        let user = try await apiService.getUser(userID: userID)

        // Update local cache
        if let profile = user.profile {
            try await localStorage.saveProfile(profile, userID: userID)
            currentProfile = profile
        }

        return user
    }

    public func updateProfile(_ profile: UserProfile) async throws {
        let updatedProfile = try await apiService.updateProfile(profile)

        // Update local state
        currentProfile = updatedProfile

        // Save to local cache
        try await localStorage.saveProfile(updatedProfile, userID: profile.userID)

        NSLog("👤 Profile updated for user: %@", profile.userID)
    }

    public func uploadAvatar(imageData: Data) async throws -> String {
        let avatarURL = try await apiService.uploadAvatar(imageData: imageData)

        // Update current profile with new avatar URL
        if var profile = currentProfile {
            profile.avatarURL = avatarURL
            currentProfile = profile
            try await localStorage.saveProfile(profile, userID: profile.userID)
        }

        NSLog("🖼️ Avatar uploaded: %@", avatarURL)
        return avatarURL
    }

    public func clearProfile() async {
        currentProfile = nil
        try? await localStorage.clearAllProfiles()
        NSLog("👤 Profile data cleared")
    }

    // MARK: - Preferences Management

    public func updatePreferences(_ preferences: UserPreferences) async throws {
        guard var profile = currentProfile else { return }

        profile.preferences = preferences
        try await updateProfile(profile)
    }

    public func updateStreamingSettings(_ settings: StreamingSettings) async throws {
        guard var profile = currentProfile else { return }

        profile.streamingSettings = settings
        try await updateProfile(profile)
    }
}

// MARK: - Profile API Service

public class ProfileAPIService {
    private let baseURL: URL
    private let session: URLSession
    private let tokenStorage: SecureTokenStorage

    public init(
        baseURL: String = "https://api.nintendoemulator.app/v1",
        tokenStorage: SecureTokenStorage = KeychainTokenStorage()
    ) {
        self.baseURL = URL(string: baseURL)!
        self.tokenStorage = tokenStorage

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }

    public func getUser(userID: String) async throws -> User {
        let url = baseURL.appendingPathComponent("/users/\(userID)")
        let accessToken = try await tokenStorage.getAccessToken()

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthError.serverError("Failed to get user")
        }

        return try JSONDecoder.default.decode(User.self, from: data)
    }

    public func updateProfile(_ profile: UserProfile) async throws -> UserProfile {
        let url = baseURL.appendingPathComponent("/users/\(profile.userID)/profile")
        let accessToken = try await tokenStorage.getAccessToken()

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder.default.encode(profile)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthError.serverError("Failed to update profile")
        }

        return try JSONDecoder.default.decode(UserProfile.self, from: data)
    }

    public func uploadAvatar(imageData: Data) async throws -> String {
        let url = baseURL.appendingPathComponent("/users/avatar")
        let accessToken = try await tokenStorage.getAccessToken()

        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // Create multipart form data
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"avatar\"; filename=\"avatar.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthError.serverError("Failed to upload avatar")
        }

        let uploadResponse = try JSONDecoder.default.decode(AvatarUploadResponse.self, from: data)
        return uploadResponse.url
    }
}

// MARK: - Local Storage

public protocol UserProfileStorage {
    func saveProfile(_ profile: UserProfile, userID: String) async throws
    func loadProfile(userID: String) async throws -> UserProfile
    func clearAllProfiles() async throws
}

public class FileSystemProfileStorage: UserProfileStorage {
    private let profilesDirectory: URL

    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        profilesDirectory = appSupport.appendingPathComponent("NintendoEmulator/Profiles")

        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: profilesDirectory, withIntermediateDirectories: true)
    }

    public func saveProfile(_ profile: UserProfile, userID: String) async throws {
        let fileURL = profilesDirectory.appendingPathComponent("\\(userID).json")
        let data = try JSONEncoder.default.encode(profile)
        try data.write(to: fileURL)
    }

    public func loadProfile(userID: String) async throws -> UserProfile {
        let fileURL = profilesDirectory.appendingPathComponent("\\(userID).json")
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder.default.decode(UserProfile.self, from: data)
    }

    public func clearAllProfiles() async throws {
        let files = try FileManager.default.contentsOfDirectory(at: profilesDirectory, includingPropertiesForKeys: nil)
        for file in files {
            try FileManager.default.removeItem(at: file)
        }
    }
}

// MARK: - Profile Data Types

public struct UserProfile: Codable, Identifiable {
    public let id: UUID
    public let userID: String
    public var displayName: String
    public var bio: String?
    public var avatarURL: String?
    public var location: String?
    public var website: String?
    public var socialLinks: SocialLinks
    public var preferences: UserPreferences
    public var streamingSettings: StreamingSettings
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        userID: String,
        displayName: String,
        bio: String? = nil,
        avatarURL: String? = nil,
        location: String? = nil,
        website: String? = nil,
        socialLinks: SocialLinks = SocialLinks(),
        preferences: UserPreferences = UserPreferences(),
        streamingSettings: StreamingSettings = StreamingSettings(),
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userID = userID
        self.displayName = displayName
        self.bio = bio
        self.avatarURL = avatarURL
        self.location = location
        self.website = website
        self.socialLinks = socialLinks
        self.preferences = preferences
        self.streamingSettings = streamingSettings
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct SocialLinks: Codable {
    public var twitch: String?
    public var youtube: String?
    public var twitter: String?
    public var discord: String?
    public var tiktok: String?

    public init(
        twitch: String? = nil,
        youtube: String? = nil,
        twitter: String? = nil,
        discord: String? = nil,
        tiktok: String? = nil
    ) {
        self.twitch = twitch
        self.youtube = youtube
        self.twitter = twitter
        self.discord = discord
        self.tiktok = tiktok
    }
}

public struct UserPreferences: Codable {
    public var theme: AppTheme
    public var language: String
    public var notifications: NotificationSettings
    public var privacy: PrivacySettings
    public var accessibility: AccessibilitySettings

    public init(
        theme: AppTheme = .system,
        language: String = "en",
        notifications: NotificationSettings = NotificationSettings(),
        privacy: PrivacySettings = PrivacySettings(),
        accessibility: AccessibilitySettings = AccessibilitySettings()
    ) {
        self.theme = theme
        self.language = language
        self.notifications = notifications
        self.privacy = privacy
        self.accessibility = accessibility
    }
}

public struct StreamingSettings: Codable {
    public var defaultPlatform: StreamingPlatform?
    public var streamTitle: String?
    public var streamCategory: String?
    public var overlayEnabled: Bool
    public var chatModerationEnabled: Bool
    public var recordingEnabled: Bool
    public var qualitySettings: StreamQualitySettings

    public init(
        defaultPlatform: StreamingPlatform? = nil,
        streamTitle: String? = nil,
        streamCategory: String? = nil,
        overlayEnabled: Bool = true,
        chatModerationEnabled: Bool = true,
        recordingEnabled: Bool = false,
        qualitySettings: StreamQualitySettings = StreamQualitySettings()
    ) {
        self.defaultPlatform = defaultPlatform
        self.streamTitle = streamTitle
        self.streamCategory = streamCategory
        self.overlayEnabled = overlayEnabled
        self.chatModerationEnabled = chatModerationEnabled
        self.recordingEnabled = recordingEnabled
        self.qualitySettings = qualitySettings
    }
}

public enum AppTheme: String, Codable, CaseIterable {
    case light, dark, system

    public var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }
}


public struct NotificationSettings: Codable {
    public var email: Bool
    public var push: Bool
    public var streamStart: Bool
    public var followers: Bool
    public var achievements: Bool

    public init(
        email: Bool = true,
        push: Bool = true,
        streamStart: Bool = true,
        followers: Bool = true,
        achievements: Bool = true
    ) {
        self.email = email
        self.push = push
        self.streamStart = streamStart
        self.followers = followers
        self.achievements = achievements
    }
}

public struct PrivacySettings: Codable {
    public var profileVisibility: ProfileVisibility
    public var showOnlineStatus: Bool
    public var allowDirectMessages: Bool
    public var shareAnalytics: Bool

    public init(
        profileVisibility: ProfileVisibility = .public,
        showOnlineStatus: Bool = true,
        allowDirectMessages: Bool = true,
        shareAnalytics: Bool = false
    ) {
        self.profileVisibility = profileVisibility
        self.showOnlineStatus = showOnlineStatus
        self.allowDirectMessages = allowDirectMessages
        self.shareAnalytics = shareAnalytics
    }
}

public enum ProfileVisibility: String, Codable, CaseIterable {
    case `public`, friends, `private`

    public var displayName: String {
        switch self {
        case .public: return "Public"
        case .friends: return "Friends Only"
        case .private: return "Private"
        }
    }
}

public struct AccessibilitySettings: Codable {
    public var reduceMotion: Bool
    public var highContrast: Bool
    public var largeText: Bool
    public var screenReaderOptimized: Bool

    public init(
        reduceMotion: Bool = false,
        highContrast: Bool = false,
        largeText: Bool = false,
        screenReaderOptimized: Bool = false
    ) {
        self.reduceMotion = reduceMotion
        self.highContrast = highContrast
        self.largeText = largeText
        self.screenReaderOptimized = screenReaderOptimized
    }
}

public struct StreamQualitySettings: Codable {
    public var resolution: String
    public var fps: Int
    public var bitrate: Int
    public var encoder: String

    public init(
        resolution: String = "1920x1080",
        fps: Int = 60,
        bitrate: Int = 6000,
        encoder: String = "h264"
    ) {
        self.resolution = resolution
        self.fps = fps
        self.bitrate = bitrate
        self.encoder = encoder
    }
}

private struct AvatarUploadResponse: Codable {
    let url: String
}