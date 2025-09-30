import Metal
import MetalKit
import CoreInterface
import simd
import os.log

/// Metal-based renderer for emulator frames
public final class MetalRenderer: NSObject {

    // MARK: - Properties

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var pipelineState: MTLRenderPipelineState?
    private var vertexBuffer: MTLBuffer?
    private var samplerState: MTLSamplerState?

    // Textures
    private var sourceTexture: MTLTexture?
    private var upscaledTexture: MTLTexture?
    private var framebufferTexture: MTLTexture?

    // Shader library
    private var defaultLibrary: MTLLibrary?
    private var vertexFunction: MTLFunction?
    private var fragmentFunction: MTLFunction?

    // Post-processing
    private var activeEffects: [PostProcessEffect] = []
    private var effectPipelines: [PostProcessEffect: MTLRenderPipelineState] = [:]

    // Frame properties
    private var frameSize = CGSize(width: 320, height: 240)
    private var renderScale: Float = 1.0

    private let logger = Logger(subsystem: "com.emulator", category: "MetalRenderer")

    // MARK: - Initialization

    public init(device: MTLDevice) throws {
        self.device = device

        guard let commandQueue = device.makeCommandQueue() else {
            throw RendererError.failedToCreateCommandQueue
        }
        self.commandQueue = commandQueue

        super.init()

        try setupMetal()
        logger.info("Metal renderer initialized")
    }

    // MARK: - Setup

    private func setupMetal() throws {
        // Create shader library
        try createShaderLibrary()

        // Create render pipeline
        try createRenderPipeline()

        // Create vertex buffer
        try createVertexBuffer()

        // Create sampler state
        try createSamplerState()
    }

    private func createShaderLibrary() throws {
        // Create default library from metallib or source
        if let url = Bundle.main.url(forResource: "default", withExtension: "metallib") {
            do {
                defaultLibrary = try device.makeLibrary(URL: url)
            } catch {
                // Fallback to source if loading metallib fails
                let source = getShaderSource()
                defaultLibrary = try device.makeLibrary(source: source, options: nil)
            }
        } else {
            // Compile from source
            let source = getShaderSource()
            defaultLibrary = try device.makeLibrary(source: source, options: nil)
        }

        guard let library = defaultLibrary else {
            throw RendererError.failedToCreateLibrary
        }

        vertexFunction = library.makeFunction(name: "vertexShader")
        fragmentFunction = library.makeFunction(name: "fragmentShader")

        guard vertexFunction != nil, fragmentFunction != nil else {
            throw RendererError.failedToCreateShaderFunctions
        }
    }

    private func createRenderPipeline() throws {
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        // Enable blending for post-processing
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = false
        pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .one
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .zero
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .zero

        pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }

    private func createVertexBuffer() throws {
        // Create vertex data for a full-screen quad
        let vertices: [Float] = [
            // Position (x, y)    Texture Coords (u, v)
            -1.0, -1.0,          0.0, 1.0,  // Bottom left
             1.0, -1.0,          1.0, 1.0,  // Bottom right
            -1.0,  1.0,          0.0, 0.0,  // Top left
             1.0,  1.0,          1.0, 0.0   // Top right
        ]

        vertexBuffer = device.makeBuffer(
            bytes: vertices,
            length: vertices.count * MemoryLayout<Float>.size,
            options: [.storageModeShared]
        )

        guard vertexBuffer != nil else {
            throw RendererError.failedToCreateBuffer
        }
    }

    private func createSamplerState() throws {
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.mipFilter = .notMipmapped
        samplerDescriptor.sAddressMode = .clampToEdge
        samplerDescriptor.tAddressMode = .clampToEdge

        samplerState = device.makeSamplerState(descriptor: samplerDescriptor)

        guard samplerState != nil else {
            throw RendererError.failedToCreateSampler
        }
    }

    // MARK: - Rendering

    /// Main render function
    public func render(
        framebuffer: UnsafeMutableRawPointer,
        size: CGSize,
        format: FrameData.PixelFormat,
        to drawable: CAMetalDrawable
    ) {
        autoreleasepool {
            guard let commandBuffer = commandQueue.makeCommandBuffer() else {
                logger.error("Failed to create command buffer")
                return
            }

            commandBuffer.label = "Emulator Frame"

            // Update source texture from framebuffer
            updateSourceTexture(framebuffer: framebuffer, size: size, format: format)

            guard let sourceTexture = sourceTexture else {
                logger.error("No source texture available")
                return
            }

            // Apply post-processing if needed
            let finalTexture = applyPostProcessing(source: sourceTexture, commandBuffer: commandBuffer)

            // Final render pass
            renderToDrawable(texture: finalTexture, drawable: drawable, commandBuffer: commandBuffer)

            // Present and commit
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }

    /// Update source texture from framebuffer data
    private func updateSourceTexture(
        framebuffer: UnsafeMutableRawPointer,
        size: CGSize,
        format: FrameData.PixelFormat
    ) {
        let width = Int(size.width)
        let height = Int(size.height)

        // Check if texture needs to be recreated
        if sourceTexture == nil ||
           sourceTexture!.width != width ||
           sourceTexture!.height != height {
            sourceTexture = createTexture(width: width, height: height, format: format)
        }

        guard let texture = sourceTexture else { return }

        // Update texture data
        let bytesPerRow = width * 4 // Assuming RGBA
        let region = MTLRegionMake2D(0, 0, width, height)

        texture.replace(
            region: region,
            mipmapLevel: 0,
            withBytes: framebuffer,
            bytesPerRow: bytesPerRow
        )
    }

    /// Create a texture with specified dimensions
    private func createTexture(
        width: Int,
        height: Int,
        format: FrameData.PixelFormat
    ) -> MTLTexture? {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: convertPixelFormat(format),
            width: width,
            height: height,
            mipmapped: false
        )

        textureDescriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        textureDescriptor.storageMode = .private

        return device.makeTexture(descriptor: textureDescriptor)
    }

    /// Convert emulator pixel format to Metal pixel format
    private func convertPixelFormat(_ format: FrameData.PixelFormat) -> MTLPixelFormat {
        switch format {
        case .rgba8888:
            return .rgba8Unorm
        case .bgra8888:
            return .bgra8Unorm
        case .rgb565:
            return .b5g6r5Unorm
        }
    }

    /// Apply post-processing effects
    private func applyPostProcessing(
        source: MTLTexture,
        commandBuffer: MTLCommandBuffer
    ) -> MTLTexture {
        if activeEffects.isEmpty {
            return source
        }

        var currentTexture = source

        for effect in activeEffects {
            if let processedTexture = applyEffect(
                effect,
                to: currentTexture,
                commandBuffer: commandBuffer
            ) {
                currentTexture = processedTexture
            }
        }

        return currentTexture
    }

    /// Apply a single post-processing effect
    private func applyEffect(
        _ effect: PostProcessEffect,
        to texture: MTLTexture,
        commandBuffer: MTLCommandBuffer
    ) -> MTLTexture? {
        // This would implement various post-processing effects
        // For now, return the original texture
        return texture
    }

    /// Render final texture to drawable
    private func renderToDrawable(
        texture: MTLTexture,
        drawable: CAMetalDrawable,
        commandBuffer: MTLCommandBuffer
    ) {
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(
            red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0
        )
        renderPassDescriptor.colorAttachments[0].storeAction = .store

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(
            descriptor: renderPassDescriptor
        ) else {
            logger.error("Failed to create render encoder")
            return
        }

        renderEncoder.label = "Final Render"

        if let pipeline = pipelineState,
           let vertexBuffer = vertexBuffer,
           let sampler = samplerState {
            renderEncoder.setRenderPipelineState(pipeline)
            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            renderEncoder.setFragmentTexture(texture, index: 0)
            renderEncoder.setFragmentSamplerState(sampler, index: 0)

            // Draw quad
            renderEncoder.drawPrimitives(
                type: .triangleStrip,
                vertexStart: 0,
                vertexCount: 4
            )
        }

        renderEncoder.endEncoding()
    }

    // MARK: - Configuration

    /// Set render scale
    public func setRenderScale(_ scale: Float) {
        renderScale = max(0.5, min(scale, 4.0))
        logger.info("Render scale set to \(self.renderScale)")
    }

    /// Enable post-processing effects
    public func setPostProcessingEffects(_ effects: [PostProcessEffect]) {
        activeEffects = effects
        logger.info("Post-processing effects updated: \(effects.map { $0.rawValue }.joined(separator: ", "))")
    }

    /// Set frame size
    public func setFrameSize(_ size: CGSize) {
        frameSize = size
        sourceTexture = nil // Force recreation on next frame
    }

    // MARK: - Shader Source

    private func getShaderSource() -> String {
        """
        #include <metal_stdlib>
        using namespace metal;

        struct VertexIn {
            float2 position [[attribute(0)]];
            float2 texCoord [[attribute(1)]];
        };

        struct VertexOut {
            float4 position [[position]];
            float2 texCoord;
        };

        vertex VertexOut vertexShader(uint vertexID [[vertex_id]],
                                      constant float4 *vertices [[buffer(0)]]) {
            VertexOut out;
            out.position = vertices[vertexID];

            // Calculate texture coordinates
            float2 texCoord = float2((vertices[vertexID].x + 1.0) * 0.5,
                                     1.0 - (vertices[vertexID].y + 1.0) * 0.5);
            out.texCoord = texCoord;

            return out;
        }

        fragment float4 fragmentShader(VertexOut in [[stage_in]],
                                       texture2d<float> texture [[texture(0)]],
                                       sampler sampler [[sampler(0)]]) {
            return texture.sample(sampler, in.texCoord);
        }
        """
    }
}

// MARK: - Renderer Errors

public enum RendererError: LocalizedError {
    case failedToCreateCommandQueue
    case failedToCreateLibrary
    case failedToCreateShaderFunctions
    case failedToCreatePipelineState
    case failedToCreateBuffer
    case failedToCreateSampler
    case failedToCreateTexture

    public var errorDescription: String? {
        switch self {
        case .failedToCreateCommandQueue: return "Failed to create Metal command queue"
        case .failedToCreateLibrary: return "Failed to create Metal shader library"
        case .failedToCreateShaderFunctions: return "Failed to create shader functions"
        case .failedToCreatePipelineState: return "Failed to create render pipeline state"
        case .failedToCreateBuffer: return "Failed to create vertex buffer"
        case .failedToCreateSampler: return "Failed to create sampler state"
        case .failedToCreateTexture: return "Failed to create texture"
        }
    }
}

// MARK: - MetalKit View

/// Custom MTKView for emulator rendering
public class EmulatorMetalView: MTKView {

    private var renderer: MetalRenderer?
    private var frameData: FrameData?

    public override init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: device)
        setupView()
    }

    public required init(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }

        self.device = device
        self.colorPixelFormat = .bgra8Unorm
        self.framebufferOnly = false
        self.preferredFramesPerSecond = 60

        do {
            renderer = try MetalRenderer(device: device)
        } catch {
            fatalError("Failed to create renderer: \(error)")
        }
    }

    /// Update with new frame data
    public func updateFrame(_ frame: FrameData) {
        frameData = frame
        setNeedsDisplay(bounds)
    }

    public override func draw(_ rect: CGRect) {
        guard let drawable = currentDrawable,
              let renderer = renderer,
              let frame = frameData else {
            return
        }

        let size = CGSize(width: frame.width, height: frame.height)
        renderer.render(
            framebuffer: frame.pixelData,
            size: size,
            format: frame.pixelFormat,
            to: drawable
        )
    }
}
