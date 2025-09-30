import SwiftUI
import Foundation
import UniformTypeIdentifiers
import AppKit
import CoreInterface

/// NN/g Compliant Modern Media Gallery - Redesigned for better usability and visual hierarchy
public struct ModernMediaGallery: View {
    let metadata: GameMetadataFetcher.GameMetadata?
    let game: ROMMetadata

    @StateObject private var storageManager = ImageStorageManager.shared
    @State private var selectedImageCategory: ImageCategory = .boxArt
    @State private var showingImagePicker = false
    @State private var dragOver = false
    @State private var uploadStatus: UploadStatus = .idle
    @State private var currentImages: [ImageCategory: NSImage] = [:]
    @State private var screenshots: [NSImage] = []
    @State private var showingImageViewer = false
    @State private var selectedImageForViewing: NSImage?

    public init(metadata: GameMetadataFetcher.GameMetadata?, game: ROMMetadata) {
        self.metadata = metadata
        self.game = game
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
                // NN/g: Clear page header with context
                headerSection

                Divider()

                // NN/g: Primary action area - Box Art
                boxArtSection

                Divider()

                // NN/g: Secondary content - Thumbnail
                thumbnailSection

                Divider()

                // NN/g: Gallery section - Screenshots
                screenshotsSection

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
        }
        .background(Color(.windowBackgroundColor))
        .fileImporter(
            isPresented: $showingImagePicker,
            allowedContentTypes: [.image],
            allowsMultipleSelection: selectedImageCategory == .screenshots,
            onCompletion: handleImageSelection
        )
        .sheet(isPresented: $showingImageViewer) {
            ImageViewerModal(
                image: selectedImageForViewing,
                isPresented: $showingImageViewer
            )
        }
        .onAppear {
            loadExistingImages()
        }
        .animation(.easeInOut(duration: 0.25), value: uploadStatus)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                // NN/g: Clear title with context
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Media Gallery")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Manage images for \(game.title)")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // NN/g: Status indicator for user feedback
                MediaStatusIndicator(status: uploadStatus)
            }

            // NN/g: Clear instructions for user guidance
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)

                Text("Upload custom box art, thumbnails, and screenshots. Supported formats: JPG, PNG, GIF")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(DesignSystem.Radius.lg)
        }
    }

    // MARK: - Box Art Section

    private var boxArtSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            MediaSectionHeader(
                title: "Box Art",
                subtitle: "Main cover image displayed in game library",
                icon: "photo.artframe"
            )

            HStack(spacing: DesignSystem.Spacing.xxl) {
                // Current box art display
                BoxArtDisplay(
                    image: currentImages[.boxArt] ?? metadata?.boxArtImage,
                    gameTitle: game.title,
                    onTap: { image in
                        selectedImageForViewing = image
                        showingImageViewer = true
                    }
                )

                // Upload controls
                UploadControls(
                    category: .boxArt,
                    hasImage: currentImages[.boxArt] != nil || metadata?.boxArtImage != nil,
                    onUpload: {
                        selectedImageCategory = .boxArt
                        showingImagePicker = true
                    },
                    onRemove: {
                        removeImage(.boxArt)
                    }
                )
            }
        }
    }

    // MARK: - Thumbnail Section

    private var thumbnailSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            MediaSectionHeader(
                title: "Library Thumbnail",
                subtitle: "Square thumbnail for grid view and quick selection",
                icon: "square.grid.3x3"
            )

            HStack(spacing: DesignSystem.Spacing.xxl) {
                // Current thumbnail display
                ThumbnailDisplay(
                    image: currentImages[.thumbnail],
                    gameTitle: game.title,
                    onTap: { image in
                        selectedImageForViewing = image
                        showingImageViewer = true
                    }
                )

                // Upload controls
                UploadControls(
                    category: .thumbnail,
                    hasImage: currentImages[.thumbnail] != nil,
                    onUpload: {
                        selectedImageCategory = .thumbnail
                        showingImagePicker = true
                    },
                    onRemove: {
                        removeImage(.thumbnail)
                    }
                )
            }
        }
    }

    // MARK: - Screenshots Section

    private var screenshotsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            MediaSectionHeader(
                title: "Screenshots",
                subtitle: "In-game screenshots and promotional images (up to 6)",
                icon: "camera.viewfinder"
            )

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DesignSystem.Spacing.lg), count: 3), spacing: DesignSystem.Spacing.lg) {
                ForEach(0..<6, id: \.self) { index in
                    ScreenshotSlot(
                        index: index,
                        image: index < screenshots.count ? screenshots[index] : nil,
                        onTap: { image in
                            selectedImageForViewing = image
                            showingImageViewer = true
                        },
                        onUpload: {
                            selectedImageCategory = .screenshots
                            showingImagePicker = true
                        },
                        onRemove: {
                            removeScreenshot(at: index)
                        }
                    )
                }
            }

            // Bulk upload button
            if screenshots.count < 6 {
                Button(action: {
                    selectedImageCategory = .screenshots
                    showingImagePicker = true
                }) {
                    HStack {
                        Image(systemName: "plus.rectangle.stack")
                        Text("Add Multiple Screenshots")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(DesignSystem.Radius.lg)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helper Functions

    private func loadExistingImages() {
        // Load box art
        currentImages[.boxArt] = storageManager.loadImage(gameTitle: game.title, imageType: .boxArt)

        // Load thumbnail
        currentImages[.thumbnail] = storageManager.loadImage(gameTitle: game.title, imageType: .libraryThumbnail)

        // Load screenshots
        screenshots = storageManager.loadScreenshots(gameTitle: game.title)
    }

    private func handleImageSelection(_ result: Result<[URL], Error>) {
        uploadStatus = .uploading

        switch result {
        case .success(let urls):
            Task {
                await processImageUploads(urls)
            }
        case .failure(let error):
            uploadStatus = .failed(error.localizedDescription)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                uploadStatus = .idle
            }
        }
    }

    @MainActor
    private func processImageUploads(_ urls: [URL]) async {
        var successCount = 0

        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let imageData = try Data(contentsOf: url)
                guard let image = NSImage(data: imageData) else { continue }

                switch selectedImageCategory {
                case .boxArt:
                    currentImages[.boxArt] = image
                    storageManager.saveImage(image, gameTitle: game.title, imageType: .boxArt)
                    successCount += 1

                case .thumbnail:
                    currentImages[.thumbnail] = image
                    storageManager.saveImage(image, gameTitle: game.title, imageType: .libraryThumbnail)
                    successCount += 1

                case .screenshots:
                    if screenshots.count < 6 {
                        let index = screenshots.count
                        screenshots.append(image)
                        storageManager.saveImage(image, gameTitle: game.title, imageType: .screenshot(index: index))
                        successCount += 1
                    }
                }
            } catch {
                print("Failed to process image: \(error)")
            }
        }

        if successCount > 0 {
            uploadStatus = .success("\(successCount) image\(successCount == 1 ? "" : "s") uploaded successfully")
        } else {
            uploadStatus = .failed("Failed to upload images")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            uploadStatus = .idle
        }
    }

    private func removeImage(_ category: ImageCategory) {
        switch category {
        case .boxArt:
            currentImages[.boxArt] = nil
            // Note: We don't delete from disk in case user wants to restore
        case .thumbnail:
            currentImages[.thumbnail] = nil
        case .screenshots:
            break // Handled by removeScreenshot
        }
    }

    private func removeScreenshot(at index: Int) {
        guard index < screenshots.count else { return }
        screenshots.remove(at: index)

        // Re-save all screenshots with new indices
        for (newIndex, screenshot) in screenshots.enumerated() {
            storageManager.saveImage(screenshot, gameTitle: game.title, imageType: .screenshot(index: newIndex))
        }
    }
}

// MARK: - Supporting Types

enum ImageCategory {
    case boxArt
    case thumbnail
    case screenshots
}

enum UploadStatus: Equatable {
    case idle
    case uploading
    case success(String)
    case failed(String)
}

// MARK: - Supporting Views

struct MediaSectionHeader: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

struct MediaStatusIndicator: View {
    let status: UploadStatus

    var body: some View {
        Group {
            switch status {
            case .idle:
                EmptyView()
            case .uploading:
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Uploading...")
                        .font(.subheadline)
                }
                .foregroundColor(.blue)
            case .success(let message):
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(message)
                        .font(.subheadline)
                }
                .foregroundColor(.green)
            case .failed(let message):
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                    Text(message)
                        .font(.subheadline)
                }
                .foregroundColor(.red)
            }
        }
    }
}

struct BoxArtDisplay: View {
    let image: NSImage?
    let gameTitle: String
    let onTap: (NSImage) -> Void

    var body: some View {
        ZStack {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 200, height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    .onTapGesture {
                        onTap(image)
                    }
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(
                        colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 200, height: 280)
                    .overlay(
                        VStack {
                            Image(systemName: "gamecontroller.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white.opacity(0.7))
                            Text("N64")
                                .font(.title.bold())
                                .foregroundColor(.white)
                        }
                    )
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            }
        }
    }
}

struct ThumbnailDisplay: View {
    let image: NSImage?
    let gameTitle: String
    let onTap: (NSImage) -> Void

    var body: some View {
        ZStack {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 160, height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    .onTapGesture {
                        onTap(image)
                    }
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 160, height: 160)
                    .overlay(
                        VStack {
                            Image(systemName: "square.grid.3x3")
                                .font(.system(size: 32))
                                .foregroundColor(.gray)
                            Text("Thumbnail")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    )
            }
        }
    }
}

struct ScreenshotSlot: View {
    let index: Int
    let image: NSImage?
    let onTap: (NSImage) -> Void
    let onUpload: () -> Void
    let onRemove: () -> Void

    var body: some View {
        ZStack {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    .onTapGesture {
                        onTap(image)
                    }
                    .contextMenu {
                        Button("Remove", action: onRemove)
                    }
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.1))
                    .aspectRatio(16/9, contentMode: .fit)
                    .overlay(
                        Button(action: onUpload) {
                            VStack {
                                Image(systemName: "photo.badge.plus")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                Text("Add Screenshot")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    )
            }
        }
    }
}

struct UploadControls: View {
    let category: ImageCategory
    let hasImage: Bool
    let onUpload: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Button(action: onUpload) {
                HStack {
                    Image(systemName: hasImage ? "arrow.triangle.2.circlepath" : "square.and.arrow.up")
                    Text(hasImage ? "Replace" : "Upload")
                }
                .frame(width: 120)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(DesignSystem.Radius.md)
            }
            .buttonStyle(.plain)

            if hasImage {
                Button(action: onRemove) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Remove")
                    }
                    .frame(width: 120)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(DesignSystem.Radius.md)
                }
                .buttonStyle(.plain)
            }

            // Format info
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Supported formats:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("JPG, PNG, GIF")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fontWeight(.medium)
            }
            .padding(.top, 8)
        }
    }
}

struct ImageViewerModal: View {
    let image: NSImage?
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.9)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }

            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(40)
            }

            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    .padding()
                }
                Spacer()
            }
        }
    }
}