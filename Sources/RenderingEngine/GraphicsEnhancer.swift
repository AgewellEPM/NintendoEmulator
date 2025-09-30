import Foundation
import Metal
import MetalKit
import CoreInterface

public final class GraphicsEnhancer {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var enhancementPipelines: [Enhancement: MTLComputePipelineState] = [:]
    private var scalingPipelines: [ScalingMode: MTLComputePipelineState] = [:]

    public enum Enhancement: String, CaseIterable {
        case none = "none"
        case antiAliasing = "anti_aliasing"
        case bilinearFilter = "bilinear"
        case bicubicFilter = "bicubic"
        case xbrz2x = "xbrz_2x"
        case xbrz3x = "xbrz_3x"
        case hq2x = "hq2x"
        case hq3x = "hq3x"
        case eagle = "eagle"
        case scanlines = "scanlines"
        case crtFilter = "crt_filter"
        case sharpening = "sharpening"
        case bloomEffect = "bloom"

        public var displayName: String {
            switch self {
            case .none: return "None"
            case .antiAliasing: return "Anti-Aliasing"
            case .bilinearFilter: return "Bilinear Filtering"
            case .bicubicFilter: return "Bicubic Filtering"
            case .xbrz2x: return "xBRZ 2x"
            case .xbrz3x: return "xBRZ 3x"
            case .hq2x: return "HQ2x"
            case .hq3x: return "HQ3x"
            case .eagle: return "Eagle"
            case .scanlines: return "Scanlines"
            case .crtFilter: return "CRT Filter"
            case .sharpening: return "Sharpening"
            case .bloomEffect: return "Bloom Effect"
            }
        }

        public var scaleFactor: Int {
            switch self {
            case .xbrz2x, .hq2x, .eagle: return 2
            case .xbrz3x, .hq3x: return 3
            default: return 1
            }
        }
    }

    public enum ScalingMode: String, CaseIterable {
        case nearestNeighbor = "nearest"
        case bilinear = "bilinear"
        case bicubic = "bicubic"
        case lanczos = "lanczos"

        public var displayName: String {
            switch self {
            case .nearestNeighbor: return "Nearest Neighbor"
            case .bilinear: return "Bilinear"
            case .bicubic: return "Bicubic"
            case .lanczos: return "Lanczos"
            }
        }
    }

    public init(device: MTLDevice) throws {
        self.device = device
        guard let commandQueue = device.makeCommandQueue() else {
            throw RenderingError.initializationFailed("Failed to create command queue")
        }
        self.commandQueue = commandQueue

        try setupPipelines()
    }

    private func setupPipelines() throws {
        let library = device.makeDefaultLibrary()

        // Setup enhancement pipelines
        for enhancement in Enhancement.allCases {
            if let function = library?.makeFunction(name: enhancement.rawValue + "_compute") {
                do {
                    let pipeline = try device.makeComputePipelineState(function: function)
                    enhancementPipelines[enhancement] = pipeline
                } catch {
                    print("Warning: Failed to create pipeline for \(enhancement.displayName): \(error)")
                }
            }
        }

        // Setup scaling pipelines
        for scaling in ScalingMode.allCases {
            if let function = library?.makeFunction(name: scaling.rawValue + "_scale_compute") {
                do {
                    let pipeline = try device.makeComputePipelineState(function: function)
                    scalingPipelines[scaling] = pipeline
                } catch {
                    print("Warning: Failed to create scaling pipeline for \(scaling.displayName): \(error)")
                }
            }
        }
    }

    public func enhance(
        inputTexture: MTLTexture,
        outputTexture: MTLTexture,
        enhancement: Enhancement,
        scaling: ScalingMode = .bilinear,
        parameters: EnhancementParameters = EnhancementParameters()
    ) throws {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw RenderingError.commandCreationFailed
        }

        // Apply enhancement if available
        if enhancement != .none, let pipeline = enhancementPipelines[enhancement] {
            encoder.setComputePipelineState(pipeline)
            encoder.setTexture(inputTexture, index: 0)
            encoder.setTexture(outputTexture, index: 1)

            // Set enhancement parameters
            var params = parameters
            encoder.setBytes(&params, length: MemoryLayout<EnhancementParameters>.size, index: 0)

            let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
            let threadgroups = MTLSize(
                width: (outputTexture.width + threadgroupSize.width - 1) / threadgroupSize.width,
                height: (outputTexture.height + threadgroupSize.height - 1) / threadgroupSize.height,
                depth: 1
            )

            encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupSize)
        }
        // Apply scaling if different from input size
        else if inputTexture.width != outputTexture.width || inputTexture.height != outputTexture.height {
            if let pipeline = scalingPipelines[scaling] {
                encoder.setComputePipelineState(pipeline)
            } else {
                // Fallback to bilinear
                if let pipeline = scalingPipelines[.bilinear] {
                    encoder.setComputePipelineState(pipeline)
                }
            }

            encoder.setTexture(inputTexture, index: 0)
            encoder.setTexture(outputTexture, index: 1)

            let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
            let threadgroups = MTLSize(
                width: (outputTexture.width + threadgroupSize.width - 1) / threadgroupSize.width,
                height: (outputTexture.height + threadgroupSize.height - 1) / threadgroupSize.height,
                depth: 1
            )

            encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupSize)
        }
        // Direct copy if no enhancement
        else {
            performDirectCopy(from: inputTexture, to: outputTexture, encoder: encoder)
        }

        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }

    private func performDirectCopy(from input: MTLTexture, to output: MTLTexture, encoder: MTLComputeCommandEncoder) {
        // Simple texture copy - could be optimized with a blit encoder
        if let library = device.makeDefaultLibrary(),
           let function = library.makeFunction(name: "texture_copy_compute"),
           let pipeline = try? device.makeComputePipelineState(function: function) {

            encoder.setComputePipelineState(pipeline)
            encoder.setTexture(input, index: 0)
            encoder.setTexture(output, index: 1)

            let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
            let threadgroups = MTLSize(
                width: (output.width + threadgroupSize.width - 1) / threadgroupSize.width,
                height: (output.height + threadgroupSize.height - 1) / threadgroupSize.height,
                depth: 1
            )

            encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupSize)
        }
    }

    public func createEnhancedTexture(
        from originalTexture: MTLTexture,
        enhancement: Enhancement,
        scaleFactor: Float = 1.0
    ) throws -> MTLTexture {
        let enhancementScale = Float(enhancement.scaleFactor)
        let totalScale = scaleFactor * enhancementScale

        let newWidth = Int(Float(originalTexture.width) * totalScale)
        let newHeight = Int(Float(originalTexture.height) * totalScale)

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: originalTexture.pixelFormat,
            width: newWidth,
            height: newHeight,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]

        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw RenderingError.textureCreationFailed
        }

        return texture
    }

    public func createOptimalSettings(for system: EmulatorSystem) -> GraphicsSettings {
        switch system {
        case .nes:
            var settings = GraphicsSettings(
                enhancement: .hq2x,
                scaling: .nearestNeighbor,
                scaleFactor: 4.0
            )
            settings.enableScanlines = true
            settings.scanlineIntensity = 0.3
            return settings
        case .snes:
            var settings = GraphicsSettings(
                enhancement: .xbrz2x,
                scaling: .bilinear,
                scaleFactor: 3.0
            )
            settings.enableScanlines = true
            settings.scanlineIntensity = 0.2
            return settings
        case .n64:
            var settings = GraphicsSettings(
                enhancement: .antiAliasing,
                scaling: .bicubic,
                scaleFactor: 2.0
            )
            settings.enableSharpening = true
            return settings
        case .gamecube, .wii:
            var settings = GraphicsSettings(
                enhancement: .antiAliasing,
                scaling: .lanczos,
                scaleFactor: 1.5
            )
            settings.enableBloom = true
            return settings
        default:
            return GraphicsSettings(
                enhancement: .bilinearFilter,
                scaling: .bilinear,
                scaleFactor: 2.0
            )
        }
    }
}

// MARK: - Supporting Types

public struct EnhancementParameters {
    public var intensity: Float = 1.0
    public var threshold: Float = 0.5
    public var radius: Float = 1.0
    public var sharpness: Float = 0.5
    public var contrast: Float = 1.0
    public var brightness: Float = 0.0
    public var saturation: Float = 1.0
    public var gamma: Float = 1.0

    // CRT-specific parameters
    public var crtCurvature: Float = 0.1
    public var crtScanlineIntensity: Float = 0.5
    public var crtPhosphorDecay: Float = 0.95

    // Bloom parameters
    public var bloomThreshold: Float = 0.8
    public var bloomIntensity: Float = 0.3
    public var bloomRadius: Float = 4.0

    public init() {}
}

public struct GraphicsSettings {
    public var enhancement: GraphicsEnhancer.Enhancement
    public var scaling: GraphicsEnhancer.ScalingMode
    public var scaleFactor: Float
    public var enableScanlines: Bool = false
    public var scanlineIntensity: Float = 0.5
    public var enableSharpening: Bool = false
    public var sharpeningIntensity: Float = 0.5
    public var enableBloom: Bool = false
    public var bloomIntensity: Float = 0.3
    public var enableCRT: Bool = false
    public var crtIntensity: Float = 0.5

    public init(
        enhancement: GraphicsEnhancer.Enhancement = .none,
        scaling: GraphicsEnhancer.ScalingMode = .bilinear,
        scaleFactor: Float = 1.0
    ) {
        self.enhancement = enhancement
        self.scaling = scaling
        self.scaleFactor = scaleFactor
    }
}

public enum RenderingError: LocalizedError {
    case initializationFailed(String)
    case commandCreationFailed
    case textureCreationFailed
    case shaderCompilationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .initializationFailed(let msg): return "Rendering initialization failed: \(msg)"
        case .commandCreationFailed: return "Failed to create Metal command buffer"
        case .textureCreationFailed: return "Failed to create Metal texture"
        case .shaderCompilationFailed(let msg): return "Shader compilation failed: \(msg)"
        }
    }
}
