import SwiftUI
import AVFoundation
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

/// Webcam effect types
enum WebcamEffect: String, CaseIterable {
    case none = "None"
    case blur = "Blur Background"
    case virtualGreen = "Green Screen"
    case pixelate = "Pixelated"
    case comic = "Comic Book"
    case neon = "Neon Glow"
    case vintage = "Vintage Film"
    case hologram = "Hologram"
    case cartoon = "Cartoon"
    case removeBackground = "Remove Background"

    var icon: String {
        switch self {
        case .none: return "camera"
        case .blur: return "camera.aperture"
        case .virtualGreen: return "rectangle.portrait.and.arrow.right"
        case .pixelate: return "square.grid.3x3"
        case .comic: return "book.closed"
        case .neon: return "bolt.circle"
        case .vintage: return "film"
        case .hologram: return "cube.transparent"
        case .cartoon: return "paintbrush.pointed"
        case .removeBackground: return "person.crop.circle.badge.minus"
        }
    }
}

/// Webcam Effects Processor
@MainActor
public class WebcamEffectsProcessor: ObservableObject {
    @Published var currentEffect: WebcamEffect = .none
    @Published var effectIntensity: Double = 0.5
    @Published var isProcessing = false
    @Published var backgroundRemovalEnabled = false

    private let context = CIContext()
    private var personSegmentationRequest: VNGeneratePersonSegmentationRequest?

    init() {
        setupVision()
    }

    private func setupVision() {
        personSegmentationRequest = VNGeneratePersonSegmentationRequest()
        personSegmentationRequest?.qualityLevel = .balanced
    }

    /// Process frame with selected effect
    public func processFrame(_ sampleBuffer: CMSampleBuffer) -> CIImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }

        var ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        // Apply background removal first if enabled
        if backgroundRemovalEnabled || currentEffect == .removeBackground {
            ciImage = removeBackground(from: ciImage, pixelBuffer: pixelBuffer) ?? ciImage
        }

        // Apply selected effect
        switch currentEffect {
        case .none, .removeBackground:
            return ciImage
        case .blur:
            return applyBlurBackground(to: ciImage, pixelBuffer: pixelBuffer)
        case .virtualGreen:
            return applyGreenScreen(to: ciImage)
        case .pixelate:
            return applyPixelate(to: ciImage)
        case .comic:
            return applyComicEffect(to: ciImage)
        case .neon:
            return applyNeonGlow(to: ciImage)
        case .vintage:
            return applyVintageEffect(to: ciImage)
        case .hologram:
            return applyHologramEffect(to: ciImage)
        case .cartoon:
            return applyCartoonEffect(to: ciImage)
        }
    }

    /// Remove background using Vision
    private func removeBackground(from image: CIImage, pixelBuffer: CVPixelBuffer) -> CIImage? {
        guard let request = personSegmentationRequest else { return nil }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])

        do {
            try handler.perform([request])

            guard let result = request.results?.first else {
                return nil
            }

            let maskPixelBuffer = result.pixelBuffer

            let maskImage = CIImage(cvPixelBuffer: maskPixelBuffer)

            // Scale mask to match original image
            let scaleX = image.extent.width / maskImage.extent.width
            let scaleY = image.extent.height / maskImage.extent.height
            let scaledMask = maskImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

            // Create transparent background
            let backgroundImage = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 0))
                .cropped(to: image.extent)

            // Blend person with transparent background
            let blendFilter = CIFilter.blendWithMask()
            blendFilter.inputImage = image
            blendFilter.backgroundImage = backgroundImage
            blendFilter.maskImage = scaledMask

            return blendFilter.outputImage
        } catch {
            print("Background removal error: \(error)")
            return nil
        }
    }

    /// Apply blur to background
    private func applyBlurBackground(to image: CIImage, pixelBuffer: CVPixelBuffer) -> CIImage? {
        guard let request = personSegmentationRequest else { return image }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])

        do {
            try handler.perform([request])

            guard let result = request.results?.first else {
                return image
            }

            let maskPixelBuffer = result.pixelBuffer

            let maskImage = CIImage(cvPixelBuffer: maskPixelBuffer)

            // Scale mask
            let scaleX = image.extent.width / maskImage.extent.width
            let scaleY = image.extent.height / maskImage.extent.height
            let scaledMask = maskImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

            // Blur background
            let blurredImage = image.clampedToExtent()
                .applyingFilter("CIGaussianBlur", parameters: ["inputRadius": 20 * effectIntensity])
                .cropped(to: image.extent)

            // Blend
            let blendFilter = CIFilter.blendWithMask()
            blendFilter.inputImage = image
            blendFilter.backgroundImage = blurredImage
            blendFilter.maskImage = scaledMask

            return blendFilter.outputImage
        } catch {
            return image
        }
    }

    /// Apply green screen effect
    private func applyGreenScreen(to image: CIImage) -> CIImage {
        let greenScreen = CIImage(color: CIColor(red: 0, green: 1, blue: 0))
            .cropped(to: image.extent)

        return image.composited(over: greenScreen)
    }

    /// Apply pixelate effect
    private func applyPixelate(to image: CIImage) -> CIImage {
        let filter = CIFilter.pixellate()
        filter.inputImage = image
        filter.scale = Float(20 * effectIntensity)
        return filter.outputImage ?? image
    }

    /// Apply comic book effect
    private func applyComicEffect(to image: CIImage) -> CIImage {
        let filter = CIFilter.comicEffect()
        filter.inputImage = image
        return filter.outputImage ?? image
    }

    /// Apply neon glow effect
    private func applyNeonGlow(to image: CIImage) -> CIImage {
        let edgeWork = image.applyingFilter("CIEdgeWork", parameters: ["inputRadius": 2.0])
        let glowingEdges = edgeWork.applyingFilter("CIGaussianBlur", parameters: ["inputRadius": 5 * effectIntensity])

        let colorControls = CIFilter.colorControls()
        colorControls.inputImage = glowingEdges
        colorControls.saturation = 2.0
        colorControls.brightness = 0.5

        guard let coloredGlow = colorControls.outputImage else { return image }

        return coloredGlow.composited(over: image)
    }

    /// Apply vintage film effect
    private func applyVintageEffect(to image: CIImage) -> CIImage {
        let sepia = CIFilter.sepiaTone()
        sepia.inputImage = image
        sepia.intensity = Float(effectIntensity)

        guard let sepiaOutput = sepia.outputImage else { return image }

        let vignette = CIFilter.vignette()
        vignette.inputImage = sepiaOutput
        vignette.intensity = Float(effectIntensity)
        vignette.radius = 2.0

        return vignette.outputImage ?? sepiaOutput
    }

    /// Apply hologram effect
    private func applyHologramEffect(to image: CIImage) -> CIImage {
        let colorMatrix = CIFilter.colorMatrix()
        colorMatrix.inputImage = image
        colorMatrix.rVector = CIVector(x: 0, y: 1, z: 1, w: 0)
        colorMatrix.gVector = CIVector(x: 1, y: 0, z: 1, w: 0)
        colorMatrix.bVector = CIVector(x: 1, y: 1, z: 0, w: 0)

        guard let hologramColor = colorMatrix.outputImage else { return image }

        let glitch = CIFilter.gaussianBlur()
        glitch.inputImage = hologramColor
        glitch.radius = Float(2 * effectIntensity)

        return glitch.outputImage ?? hologramColor
    }

    /// Apply cartoon effect
    private func applyCartoonEffect(to image: CIImage) -> CIImage {
        let edges = image.applyingFilter("CIEdges", parameters: ["inputIntensity": 10.0])
        let posterized = image.applyingFilter("CIColorPosterize", parameters: ["inputLevels": 5])

        return edges.composited(over: posterized)
    }
}

/// Webcam Effects Control View
public struct WebcamEffectsControl: View {
    @StateObject private var effectsProcessor = WebcamEffectsProcessor()
    @State private var showEffectsPicker = false

    public init() {}

    public var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Header
            HStack {
                Image(systemName: "camera.filters")
                    .foregroundColor(.blue)
                Text("Webcam Effects")
                    .font(.headline)
                Spacer()
                Toggle("", isOn: $effectsProcessor.backgroundRemovalEnabled)
                    .labelsHidden()
                    .scaleEffect(0.8)
            }

            // Current Effect
            HStack {
                Text("Effect:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button(action: { showEffectsPicker.toggle() }) {
                    HStack {
                        Image(systemName: effectsProcessor.currentEffect.icon)
                        Text(effectsProcessor.currentEffect.rawValue)
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(DesignSystem.Radius.md)
                }
                .buttonStyle(.plain)

                Spacer()
            }

            // Effects Grid
            if showEffectsPicker {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: DesignSystem.Spacing.sm) {
                    ForEach(WebcamEffect.allCases, id: \.self) { effect in
                        EffectButton(
                            effect: effect,
                            isSelected: effectsProcessor.currentEffect == effect
                        ) {
                            effectsProcessor.currentEffect = effect
                            showEffectsPicker = false
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            // Intensity Slider
            if effectsProcessor.currentEffect != .none {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Intensity: \(Int(effectsProcessor.effectIntensity * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Slider(value: $effectsProcessor.effectIntensity, in: 0...1)
                        .controlSize(.small)
                }
            }

            // Background Removal Toggle
            Toggle("Remove Background", isOn: $effectsProcessor.backgroundRemovalEnabled)
                .font(.caption)
                .toggleStyle(.checkbox)
                .controlSize(.small)

            Divider()

            // Performance indicator
            HStack {
                Circle()
                    .fill(effectsProcessor.isProcessing ? Color.orange : Color.green)
                    .frame(width: 6, height: 6)
                Text(effectsProcessor.isProcessing ? "Processing..." : "Ready")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(DesignSystem.Radius.lg)
        .frame(width: 250)
    }
}

/// Effect selection button
struct EffectButton: View {
    let effect: WebcamEffect
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: effect.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .blue)

                Text(effect.rawValue)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(width: 80, height: 60)
            .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
            .cornerRadius(DesignSystem.Radius.lg)
        }
        .buttonStyle(.plain)
    }
}