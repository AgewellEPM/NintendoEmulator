import Foundation
import SwiftUI
import Combine

/// Sprint 2 - CREATOR-002: Stream Overlay Management System
/// Manages customizable overlays for live streaming
@MainActor
public class StreamOverlayManager: ObservableObject {
    // MARK: - Published Properties
    @Published public private(set) var activeOverlay: StreamOverlay?
    @Published public private(set) var availableTemplates: [OverlayTemplate] = []
    @Published public private(set) var userOverlays: [StreamOverlay] = []
    @Published public private(set) var isPreviewMode = false

    // MARK: - Private Properties
    private let storage = OverlayStorage()
    private var cancellables = Set<AnyCancellable>()

    public init() {
        loadDefaultTemplates()
        loadUserOverlays()
    }

    // MARK: - Overlay Management

    /// Create a new overlay from a template
    public func createOverlay(from template: OverlayTemplate, name: String) -> StreamOverlay {
        let overlay = StreamOverlay(
            id: UUID(),
            name: name,
            template: template,
            elements: template.elements.map { templateElement in
                OverlayElement(
                    id: UUID(),
                    type: templateElement.type,
                    position: templateElement.position,
                    size: templateElement.size,
                    properties: templateElement.properties,
                    isVisible: templateElement.isVisible,
                    zIndex: templateElement.zIndex
                )
            },
            settings: OverlaySettings(),
            createdAt: Date(),
            modifiedAt: Date()
        )

        userOverlays.append(overlay)
        saveUserOverlays()
        return overlay
    }

    /// Update an existing overlay
    public func updateOverlay(_ overlay: StreamOverlay) {
        guard let index = userOverlays.firstIndex(where: { $0.id == overlay.id }) else { return }

        var updatedOverlay = overlay
        updatedOverlay.modifiedAt = Date()
        userOverlays[index] = updatedOverlay

        if activeOverlay?.id == overlay.id {
            activeOverlay = updatedOverlay
        }

        saveUserOverlays()
    }

    /// Delete an overlay
    public func deleteOverlay(_ overlay: StreamOverlay) {
        userOverlays.removeAll { $0.id == overlay.id }

        if activeOverlay?.id == overlay.id {
            activeOverlay = nil
        }

        saveUserOverlays()
    }

    /// Activate an overlay for streaming
    public func activateOverlay(_ overlay: StreamOverlay) {
        activeOverlay = overlay
        isPreviewMode = false
    }

    /// Deactivate the current overlay
    public func deactivateOverlay() {
        activeOverlay = nil
        isPreviewMode = false
    }

    /// Enter preview mode with an overlay
    public func previewOverlay(_ overlay: StreamOverlay) {
        activeOverlay = overlay
        isPreviewMode = true
    }

    /// Exit preview mode
    public func exitPreview() {
        if isPreviewMode {
            activeOverlay = nil
            isPreviewMode = false
        }
    }

    // MARK: - Element Management

    /// Add an element to an overlay
    public func addElement(_ element: OverlayElement, to overlay: StreamOverlay) {
        guard let index = userOverlays.firstIndex(where: { $0.id == overlay.id }) else { return }

        var updatedOverlay = overlay
        updatedOverlay.elements.append(element)
        updatedOverlay.modifiedAt = Date()

        userOverlays[index] = updatedOverlay

        if activeOverlay?.id == overlay.id {
            activeOverlay = updatedOverlay
        }

        saveUserOverlays()
    }

    /// Update an element in an overlay
    public func updateElement(_ element: OverlayElement, in overlay: StreamOverlay) {
        guard let overlayIndex = userOverlays.firstIndex(where: { $0.id == overlay.id }),
              let elementIndex = userOverlays[overlayIndex].elements.firstIndex(where: { $0.id == element.id }) else { return }

        userOverlays[overlayIndex].elements[elementIndex] = element
        userOverlays[overlayIndex].modifiedAt = Date()

        if activeOverlay?.id == overlay.id {
            activeOverlay = userOverlays[overlayIndex]
        }

        saveUserOverlays()
    }

    /// Remove an element from an overlay
    public func removeElement(_ element: OverlayElement, from overlay: StreamOverlay) {
        guard let overlayIndex = userOverlays.firstIndex(where: { $0.id == overlay.id }) else { return }

        userOverlays[overlayIndex].elements.removeAll { $0.id == element.id }
        userOverlays[overlayIndex].modifiedAt = Date()

        if activeOverlay?.id == overlay.id {
            activeOverlay = userOverlays[overlayIndex]
        }

        saveUserOverlays()
    }

    // MARK: - Template Management

    /// Duplicate an overlay as a new template
    public func saveAsTemplate(overlay: StreamOverlay, name: String, description: String) -> OverlayTemplate {
        let template = OverlayTemplate(
            id: UUID(),
            name: name,
            description: description,
            category: .custom,
            elements: overlay.elements.map { element in
                OverlayTemplateElement(
                    type: element.type,
                    position: element.position,
                    size: element.size,
                    properties: element.properties,
                    isVisible: element.isVisible,
                    zIndex: element.zIndex
                )
            },
            previewImageURL: nil,
            isBuiltIn: false,
            createdAt: Date()
        )

        availableTemplates.append(template)
        saveTemplates()
        return template
    }

    // MARK: - Data Management

    private func loadDefaultTemplates() {
        availableTemplates = [
            // Minimalist Template
            OverlayTemplate(
                id: UUID(),
                name: "Minimalist",
                description: "Clean and simple overlay with webcam and basic info",
                category: .minimalist,
                elements: [
                    OverlayTemplateElement(
                        type: .webcam,
                        position: CGPoint(x: 0.8, y: 0.8),
                        size: CGSize(width: 0.18, height: 0.24),
                        properties: OverlayElementProperties(
                            backgroundColor: .clear,
                            borderColor: .white,
                            borderWidth: 2,
                            cornerRadius: 12,
                            opacity: 1.0
                        ),
                        isVisible: true,
                        zIndex: 10
                    ),
                    OverlayTemplateElement(
                        type: .streamInfo,
                        position: CGPoint(x: 0.02, y: 0.02),
                        size: CGSize(width: 0.25, height: 0.08),
                        properties: OverlayElementProperties(
                            fontName: "SF Pro Display",
                            fontSize: 16,
                            textColor: .white,
                            backgroundColor: .black.opacity(0.5),
                            cornerRadius: 8
                        ),
                        isVisible: true,
                        zIndex: 5
                    )
                ],
                previewImageURL: nil,
                isBuiltIn: true,
                createdAt: Date()
            ),

            // Gaming Template
            OverlayTemplate(
                id: UUID(),
                name: "Gaming Pro",
                description: "Full-featured gaming overlay with all the essentials",
                category: .gaming,
                elements: [
                    OverlayTemplateElement(
                        type: .webcam,
                        position: CGPoint(x: 0.75, y: 0.7),
                        size: CGSize(width: 0.23, height: 0.28),
                        properties: OverlayElementProperties(
                            borderColor: .blue,
                            borderWidth: 3,
                            cornerRadius: 16,
                            glowEffect: true
                        ),
                        isVisible: true,
                        zIndex: 15
                    ),
                    OverlayTemplateElement(
                        type: .chat,
                        position: CGPoint(x: 0.02, y: 0.3),
                        size: CGSize(width: 0.25, height: 0.4),
                        properties: OverlayElementProperties(
                            fontSize: 12,
                            backgroundColor: .black.opacity(0.7),
                            cornerRadius: 12
                        ),
                        isVisible: true,
                        zIndex: 8
                    ),
                    OverlayTemplateElement(
                        type: .recentFollower,
                        position: CGPoint(x: 0.02, y: 0.72),
                        size: CGSize(width: 0.22, height: 0.06),
                        properties: OverlayElementProperties(
                            fontSize: 14,
                            textColor: .white,
                            backgroundColor: .purple.opacity(0.8),
                            cornerRadius: 8
                        ),
                        isVisible: true,
                        zIndex: 12
                    ),
                    OverlayTemplateElement(
                        type: .donation,
                        position: CGPoint(x: 0.02, y: 0.8),
                        size: CGSize(width: 0.22, height: 0.06),
                        properties: OverlayElementProperties(
                            fontSize: 14,
                            textColor: .white,
                            backgroundColor: .green.opacity(0.8),
                            cornerRadius: 8
                        ),
                        isVisible: true,
                        zIndex: 12
                    )
                ],
                previewImageURL: nil,
                isBuiltIn: true,
                createdAt: Date()
            ),

            // Creative Template
            OverlayTemplate(
                id: UUID(),
                name: "Creative Studio",
                description: "Perfect for creative content with room for artwork",
                category: .creative,
                elements: [
                    OverlayTemplateElement(
                        type: .webcam,
                        position: CGPoint(x: 0.02, y: 0.7),
                        size: CGSize(width: 0.25, height: 0.28),
                        properties: OverlayElementProperties(
                            borderColor: .orange,
                            borderWidth: 2,
                            cornerRadius: 20,
                            shadowEnabled: true
                        ),
                        isVisible: true,
                        zIndex: 10
                    ),
                    OverlayTemplateElement(
                        type: .streamInfo,
                        position: CGPoint(x: 0.3, y: 0.9),
                        size: CGSize(width: 0.4, height: 0.08),
                        properties: OverlayElementProperties(
                            fontName: "SF Pro Display",
                            fontSize: 18,
                            textColor: .white,
                            backgroundColor: .orange.opacity(0.8),
                            cornerRadius: 25
                        ),
                        isVisible: true,
                        zIndex: 8
                    )
                ],
                previewImageURL: nil,
                isBuiltIn: true,
                createdAt: Date()
            )
        ]
    }

    private func loadUserOverlays() {
        Task {
            do {
                userOverlays = try await storage.loadOverlays()
            } catch {
                NSLog("Failed to load user overlays: \(error)")
                userOverlays = []
            }
        }
    }

    private func saveUserOverlays() {
        Task {
            do {
                try await storage.saveOverlays(userOverlays)
            } catch {
                NSLog("Failed to save user overlays: \(error)")
            }
        }
    }

    private func saveTemplates() {
        Task {
            do {
                try await storage.saveTemplates(availableTemplates.filter { !$0.isBuiltIn })
            } catch {
                NSLog("Failed to save templates: \(error)")
            }
        }
    }
}

// MARK: - Data Models

public struct StreamOverlay: Codable, Identifiable {
    public let id: UUID
    public var name: String
    public let template: OverlayTemplate
    public var elements: [OverlayElement]
    public var settings: OverlaySettings
    public let createdAt: Date
    public var modifiedAt: Date

    public init(
        id: UUID,
        name: String,
        template: OverlayTemplate,
        elements: [OverlayElement],
        settings: OverlaySettings,
        createdAt: Date,
        modifiedAt: Date
    ) {
        self.id = id
        self.name = name
        self.template = template
        self.elements = elements
        self.settings = settings
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

public struct OverlayTemplate: Codable, Identifiable {
    public let id: UUID
    public let name: String
    public let description: String
    public let category: OverlayCategory
    public let elements: [OverlayTemplateElement]
    public let previewImageURL: String?
    public let isBuiltIn: Bool
    public let createdAt: Date

    public init(
        id: UUID,
        name: String,
        description: String,
        category: OverlayCategory,
        elements: [OverlayTemplateElement],
        previewImageURL: String? = nil,
        isBuiltIn: Bool,
        createdAt: Date
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.elements = elements
        self.previewImageURL = previewImageURL
        self.isBuiltIn = isBuiltIn
        self.createdAt = createdAt
    }
}

public struct OverlayElement: Codable, Identifiable, Equatable {
    public let id: UUID
    public let type: OverlayElementType
    public var position: CGPoint // Normalized coordinates (0.0 - 1.0)
    public var size: CGSize // Normalized size (0.0 - 1.0)
    public var properties: OverlayElementProperties
    public var isVisible: Bool
    public var zIndex: Int

    public init(
        id: UUID,
        type: OverlayElementType,
        position: CGPoint,
        size: CGSize,
        properties: OverlayElementProperties,
        isVisible: Bool = true,
        zIndex: Int = 0
    ) {
        self.id = id
        self.type = type
        self.position = position
        self.size = size
        self.properties = properties
        self.isVisible = isVisible
        self.zIndex = zIndex
    }
}

public struct OverlayTemplateElement: Codable {
    public let type: OverlayElementType
    public let position: CGPoint
    public let size: CGSize
    public let properties: OverlayElementProperties
    public let isVisible: Bool
    public let zIndex: Int

    public init(
        type: OverlayElementType,
        position: CGPoint,
        size: CGSize,
        properties: OverlayElementProperties,
        isVisible: Bool = true,
        zIndex: Int = 0
    ) {
        self.type = type
        self.position = position
        self.size = size
        self.properties = properties
        self.isVisible = isVisible
        self.zIndex = zIndex
    }
}

public struct OverlayElementProperties: Codable, Equatable {
    public var fontName: String?
    public var fontSize: CGFloat?
    public var textColor: CodableColor?
    public var backgroundColor: CodableColor?
    public var borderColor: CodableColor?
    public var borderWidth: CGFloat?
    public var cornerRadius: CGFloat?
    public var opacity: Double?
    public var shadowEnabled: Bool?
    public var glowEffect: Bool?
    public var animationEnabled: Bool?
    public var customText: String?
    public var imageURL: String?

    public init(
        fontName: String? = nil,
        fontSize: CGFloat? = nil,
        textColor: CodableColor? = nil,
        backgroundColor: CodableColor? = nil,
        borderColor: CodableColor? = nil,
        borderWidth: CGFloat? = nil,
        cornerRadius: CGFloat? = nil,
        opacity: Double? = nil,
        shadowEnabled: Bool? = nil,
        glowEffect: Bool? = nil,
        animationEnabled: Bool? = nil,
        customText: String? = nil,
        imageURL: String? = nil
    ) {
        self.fontName = fontName
        self.fontSize = fontSize
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        self.cornerRadius = cornerRadius
        self.opacity = opacity
        self.shadowEnabled = shadowEnabled
        self.glowEffect = glowEffect
        self.animationEnabled = animationEnabled
        self.customText = customText
        self.imageURL = imageURL
    }
}

public struct OverlaySettings: Codable {
    public var resolution: OverlayResolution
    public var refreshRate: Int // FPS
    public var enableTransitions: Bool
    public var transitionDuration: Double
    public var enableHotkeys: Bool

    public init(
        resolution: OverlayResolution = .fullHD,
        refreshRate: Int = 30,
        enableTransitions: Bool = true,
        transitionDuration: Double = 0.3,
        enableHotkeys: Bool = true
    ) {
        self.resolution = resolution
        self.refreshRate = refreshRate
        self.enableTransitions = enableTransitions
        self.transitionDuration = transitionDuration
        self.enableHotkeys = enableHotkeys
    }
}

// MARK: - Enums

public enum OverlayCategory: String, CaseIterable, Codable {
    case minimalist = "minimalist"
    case gaming = "gaming"
    case creative = "creative"
    case professional = "professional"
    case custom = "custom"

    public var displayName: String {
        switch self {
        case .minimalist: return "Minimalist"
        case .gaming: return "Gaming"
        case .creative: return "Creative"
        case .professional: return "Professional"
        case .custom: return "Custom"
        }
    }

    public var iconName: String {
        switch self {
        case .minimalist: return "square.dashed"
        case .gaming: return "gamecontroller.fill"
        case .creative: return "paintbrush.fill"
        case .professional: return "briefcase.fill"
        case .custom: return "wrench.and.screwdriver.fill"
        }
    }
}

public enum OverlayElementType: String, CaseIterable, Codable {
    case webcam = "webcam"
    case chat = "chat"
    case streamInfo = "stream_info"
    case recentFollower = "recent_follower"
    case donation = "donation"
    case gameCapture = "game_capture"
    case image = "image"
    case text = "text"
    case timer = "timer"
    case counter = "counter"
    case socialMedia = "social_media"

    public var displayName: String {
        switch self {
        case .webcam: return "Webcam"
        case .chat: return "Chat"
        case .streamInfo: return "Stream Info"
        case .recentFollower: return "Recent Follower"
        case .donation: return "Donations"
        case .gameCapture: return "Game Capture"
        case .image: return "Image"
        case .text: return "Text"
        case .timer: return "Timer"
        case .counter: return "Counter"
        case .socialMedia: return "Social Media"
        }
    }

    public var iconName: String {
        switch self {
        case .webcam: return "video.fill"
        case .chat: return "message.fill"
        case .streamInfo: return "info.circle.fill"
        case .recentFollower: return "person.badge.plus"
        case .donation: return "dollarsign.circle.fill"
        case .gameCapture: return "gamecontroller.fill"
        case .image: return "photo.fill"
        case .text: return "textformat"
        case .timer: return "timer"
        case .counter: return "number.circle.fill"
        case .socialMedia: return "at"
        }
    }
}

public enum OverlayResolution: String, CaseIterable, Codable {
    case hd = "1280x720"
    case fullHD = "1920x1080"
    case ultraHD = "3840x2160"

    public var displayName: String {
        switch self {
        case .hd: return "HD (720p)"
        case .fullHD: return "Full HD (1080p)"
        case .ultraHD: return "4K (2160p)"
        }
    }

    public var size: CGSize {
        switch self {
        case .hd: return CGSize(width: 1280, height: 720)
        case .fullHD: return CGSize(width: 1920, height: 1080)
        case .ultraHD: return CGSize(width: 3840, height: 2160)
        }
    }
}

// MARK: - Codable Color Support

public struct CodableColor: Codable, Equatable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    public init(color: Color) {
        // Convert SwiftUI Color to RGB components
        // This is a simplified implementation
        self.red = 1.0
        self.green = 1.0
        self.blue = 1.0
        self.alpha = 1.0
    }

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public var color: Color {
        return Color(red: red, green: green, blue: blue, opacity: alpha)
    }

    // Predefined colors
    public static let clear = CodableColor(red: 0, green: 0, blue: 0, alpha: 0)
    public static let white = CodableColor(red: 1, green: 1, blue: 1, alpha: 1)
    public static let black = CodableColor(red: 0, green: 0, blue: 0, alpha: 1)
    public static let blue = CodableColor(red: 0, green: 0.5, blue: 1, alpha: 1)
    public static let green = CodableColor(red: 0, green: 0.8, blue: 0, alpha: 1)
    public static let red = CodableColor(red: 1, green: 0, blue: 0, alpha: 1)
    public static let orange = CodableColor(red: 1, green: 0.5, blue: 0, alpha: 1)
    public static let purple = CodableColor(red: 0.8, green: 0, blue: 0.8, alpha: 1)
}

extension CodableColor {
    static func opacity(_ value: Double) -> CodableColor {
        return CodableColor(red: 0, green: 0, blue: 0, alpha: value)
    }

    public func opacity(_ value: Double) -> CodableColor {
        return CodableColor(red: self.red, green: self.green, blue: self.blue, alpha: value)
    }
}

// MARK: - Storage

public class OverlayStorage {
    private let overlaysURL: URL
    private let templatesURL: URL

    public init() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.overlaysURL = documentsURL.appendingPathComponent("stream_overlays.json")
        self.templatesURL = documentsURL.appendingPathComponent("overlay_templates.json")
    }

    public func saveOverlays(_ overlays: [StreamOverlay]) async throws {
        let data = try JSONEncoder().encode(overlays)
        try data.write(to: overlaysURL)
    }

    public func loadOverlays() async throws -> [StreamOverlay] {
        guard FileManager.default.fileExists(atPath: overlaysURL.path) else {
            return []
        }
        let data = try Data(contentsOf: overlaysURL)
        return try JSONDecoder().decode([StreamOverlay].self, from: data)
    }

    public func saveTemplates(_ templates: [OverlayTemplate]) async throws {
        let data = try JSONEncoder().encode(templates)
        try data.write(to: templatesURL)
    }

    public func loadTemplates() async throws -> [OverlayTemplate] {
        guard FileManager.default.fileExists(atPath: templatesURL.path) else {
            return []
        }
        let data = try Data(contentsOf: templatesURL)
        return try JSONDecoder().decode([OverlayTemplate].self, from: data)
    }
}
