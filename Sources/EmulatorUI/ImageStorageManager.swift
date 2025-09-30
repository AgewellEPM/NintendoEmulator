import Foundation
import SwiftUI
import AppKit

/// Manages persistent storage of game images
@MainActor
public class ImageStorageManager: ObservableObject {
    static let shared = ImageStorageManager()

    private let fileManager = FileManager.default
    private var storageDirectory: URL?

    init() {
        setupStorageDirectory()
    }

    private func setupStorageDirectory() {
        // Get Application Support directory
        if let appSupport = fileManager.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask).first {
            let emulatorDir = appSupport.appendingPathComponent("NintendoEmulator")
            let imagesDir = emulatorDir.appendingPathComponent("GameImages")

            // Create directories if they don't exist
            try? fileManager.createDirectory(at: imagesDir,
                                            withIntermediateDirectories: true,
                                            attributes: nil)
            storageDirectory = imagesDir
        }
    }

    /// Save an image for a specific game
    public func saveImage(_ image: NSImage, gameTitle: String, imageType: ImageType) {
        print("🖼️ ImageStorageManager: saveImage called for '\(gameTitle)', type: \(imageType)")

        guard let storageDir = storageDirectory else {
            print("❌ No storage directory available")
            return
        }

        // Clean game title for filename
        let cleanTitle = gameTitle.replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")

        let filename: String
        switch imageType {
        case .boxArt:
            filename = "\(cleanTitle)_boxart.jpg"
        case .libraryThumbnail:
            filename = "\(cleanTitle)_thumbnail.jpg"
        case .screenshot(let index):
            filename = "\(cleanTitle)_screenshot_\(index).jpg"
        }

        let fileURL = storageDir.appendingPathComponent(filename)
        print("🖼️ Will save to: \(fileURL.path)")

        // Convert image to JPEG data
        if let tiffData = image.tiffRepresentation,
           let bitmapRep = NSBitmapImageRep(data: tiffData),
           let jpegData = bitmapRep.representation(using: .jpeg,
                                                  properties: [.compressionFactor: 0.8]) {
            do {
                try jpegData.write(to: fileURL)
                print("✅ Successfully saved image to: \(fileURL.path)")
            } catch {
                print("❌ Failed to save image: \(error)")
            }
        } else {
            print("❌ Failed to convert image to JPEG data")
        }
    }

    /// Load an image for a specific game
    public func loadImage(gameTitle: String, imageType: ImageType) -> NSImage? {
        guard let storageDir = storageDirectory else { return nil }

        let cleanTitle = gameTitle.replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")

        let filename: String
        switch imageType {
        case .boxArt:
            filename = "\(cleanTitle)_boxart.jpg"
        case .libraryThumbnail:
            filename = "\(cleanTitle)_thumbnail.jpg"
        case .screenshot(let index):
            filename = "\(cleanTitle)_screenshot_\(index).jpg"
        }

        let fileURL = storageDir.appendingPathComponent(filename)

        if fileManager.fileExists(atPath: fileURL.path),
           let imageData = try? Data(contentsOf: fileURL),
           let image = NSImage(data: imageData) {
            return image
        }

        return nil
    }

    /// Load all screenshots for a game
    public func loadScreenshots(gameTitle: String) -> [NSImage] {
        var screenshots: [NSImage] = []

        for index in 0..<6 {
            if let screenshot = loadImage(gameTitle: gameTitle,
                                         imageType: .screenshot(index: index)) {
                screenshots.append(screenshot)
            }
        }

        return screenshots
    }

    /// Check if a game has custom images
    public func hasCustomImages(gameTitle: String) -> Bool {
        return loadImage(gameTitle: gameTitle, imageType: .boxArt) != nil ||
               loadImage(gameTitle: gameTitle, imageType: .libraryThumbnail) != nil
    }

    /// Delete all images for a game
    public func deleteAllImages(gameTitle: String) {
        guard let storageDir = storageDirectory else { return }

        let cleanTitle = gameTitle.replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")

        // Delete box art
        let boxArtURL = storageDir.appendingPathComponent("\(cleanTitle)_boxart.jpg")
        try? fileManager.removeItem(at: boxArtURL)

        // Delete thumbnail
        let thumbnailURL = storageDir.appendingPathComponent("\(cleanTitle)_thumbnail.jpg")
        try? fileManager.removeItem(at: thumbnailURL)

        // Delete screenshots
        for index in 0..<6 {
            let screenshotURL = storageDir.appendingPathComponent("\(cleanTitle)_screenshot_\(index).jpg")
            try? fileManager.removeItem(at: screenshotURL)
        }
    }
}

/// Image type enumeration
public enum ImageType: Equatable {
    case boxArt
    case libraryThumbnail
    case screenshot(index: Int)
}