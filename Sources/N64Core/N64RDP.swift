import Foundation
import CoreInterface
import RenderingEngine
import Metal

public final class N64RDP {

    // MARK: - Properties

    private let memory: N64Memory
    private var commandBuffer: [UInt32] = []
    private var framebuffer: UnsafeMutableRawPointer
    private var colorBuffer: Data
    private var depthBuffer: Data

    // Framebuffer properties
    private var fbWidth: Int = 320
    private var fbHeight: Int = 240
    private var fbFormat: Int = 0
    private var fbAddress: UInt32 = 0

    // Graphics state
    private var renderMode: UInt32 = 0
    private var scissorBox = (x: 0, y: 0, width: 320, height: 240)
    private var fillColor: UInt32 = 0
    private var blendColor: UInt32 = 0
    private var fogColor: UInt32 = 0
    private var envColor: UInt32 = 0

    // Texture state
    private var textureImage: UInt32 = 0
    private var textureFormat: Int = 0
    private var textureSize: Int = 0
    private var texturePalette: Int = 0

    // Combine mode
    private var combineMode: (cycle0: UInt32, cycle1: UInt32) = (0, 0)

    // Performance
    public var needsUpdate = false
    private var commandsProcessed = 0

    // Metal integration
    private var metalDevice: MTLDevice?
    private var metalTexture: MTLTexture?

    // MARK: - Initialization

    public init(memory: N64Memory) {
        self.memory = memory

        // Allocate framebuffer (RGBA8888)
        let bufferSize = 640 * 480 * 4 // Max resolution
        framebuffer = UnsafeMutableRawPointer.allocate(byteCount: bufferSize, alignment: 16)
        colorBuffer = Data(count: bufferSize)
        depthBuffer = Data(count: 640 * 480 * 2) // 16-bit depth

        // Initialize Metal if available
        metalDevice = MTLCreateSystemDefaultDevice()

        reset()
    }

    deinit {
        framebuffer.deallocate()
    }

    public func reset() {
        commandBuffer.removeAll()
        fbWidth = 320
        fbHeight = 240
        fbFormat = 0
        fbAddress = 0
        renderMode = 0
        fillColor = 0
        blendColor = 0
        fogColor = 0
        envColor = 0
        textureImage = 0
        textureFormat = 0
        textureSize = 0
        texturePalette = 0
        combineMode = (0, 0)
        needsUpdate = false
        commandsProcessed = 0

        // Clear framebuffer to black
        clearFramebuffer(color: 0x00000000)
    }

    // MARK: - Command Processing

    public func writeCommand(_ command: UInt32) {
        commandBuffer.append(command)
        needsUpdate = true
    }

    public func processCommands() {
        while !commandBuffer.isEmpty {
            let command = commandBuffer.removeFirst()
            processCommand(command)
        }
        needsUpdate = false
    }

    private func processCommand(_ command: UInt32) {
        let opcode = (command >> 24) & 0x3F

        switch opcode {
        case 0x08: // SET_FILL_COLOR
            fillColor = command & 0xFFFFFF

        case 0x09: // SET_BLEND_COLOR
            blendColor = command & 0xFFFFFF

        case 0x0A: // SET_FOG_COLOR
            fogColor = command & 0xFFFFFF

        case 0x0B: // SET_ENV_COLOR
            envColor = command & 0xFFFFFF

        case 0x0C: // SET_COMBINE_MODE
            if commandBuffer.count >= 1 {
                let cycle0 = command
                let cycle1 = commandBuffer.removeFirst()
                combineMode = (cycle0, cycle1)
            }

        case 0x0D: // SET_TEXTURE_IMAGE
            textureImage = command & 0xFFFFFF
            textureFormat = Int((command >> 21) & 0x7)
            textureSize = Int((command >> 19) & 0x3)

        case 0x0E: // SET_Z_IMAGE
            // Set depth buffer address
            break

        case 0x0F: // SET_COLOR_IMAGE
            fbAddress = command & 0xFFFFFF
            fbFormat = Int((command >> 21) & 0x7)
            fbWidth = Int((command >> 12) & 0x3FF) + 1

        case 0x10: // SET_SCISSOR
            if commandBuffer.count >= 1 {
                let params = commandBuffer.removeFirst()
                let x0 = Int(params >> 24) & 0xFF
                let y0 = Int(params >> 16) & 0xFF
                let x1 = Int(params >> 8) & 0xFF
                let y1 = Int(params) & 0xFF
                scissorBox = (x0, y0, x1 - x0, y1 - y0)
            }

        case 0x2D: // SET_RENDER_MODE
            renderMode = command

        case 0x36: // FILL_RECTANGLE
            if commandBuffer.count >= 1 {
                let coords = commandBuffer.removeFirst()
                let x0 = Int(coords >> 24) & 0xFF
                let y0 = Int(coords >> 16) & 0xFF
                let x1 = Int(coords >> 8) & 0xFF
                let y1 = Int(coords) & 0xFF
                fillRectangle(x0: x0, y0: y0, x1: x1, y1: y1)
            }

        case 0x3C: // TEXTURE_RECTANGLE
            if commandBuffer.count >= 3 {
                let coords = commandBuffer.removeFirst()
                let texCoords = commandBuffer.removeFirst()
                let texParams = commandBuffer.removeFirst()

                let x0 = Int(coords >> 24) & 0xFF
                let y0 = Int(coords >> 16) & 0xFF
                let x1 = Int(coords >> 8) & 0xFF
                let y1 = Int(coords) & 0xFF

                drawTextureRectangle(x0: x0, y0: y0, x1: x1, y1: y1,
                                   texCoords: texCoords, texParams: texParams)
            }

        case 0x3D: // TEXTURE_RECTANGLE_FLIP
            // Similar to texture rectangle but with flipped coordinates
            if commandBuffer.count >= 3 {
                _ = commandBuffer.removeFirst()
                _ = commandBuffer.removeFirst()
                _ = commandBuffer.removeFirst()
                // TODO: Implement flipped texture rectangle
            }

        case 0x3E: // SYNC_LOAD
            // Synchronize texture loading
            break

        case 0x3F: // SYNC_FULL
            // Full synchronization - framebuffer complete
            updateFramebuffer()

        default:
            // Unknown command - skip any additional words
            let additionalWords = getCommandLength(opcode) - 1
            for _ in 0..<additionalWords {
                if !commandBuffer.isEmpty {
                    _ = commandBuffer.removeFirst()
                }
            }
        }

        commandsProcessed += 1
    }

    // MARK: - Drawing Operations

    private func fillRectangle(x0: Int, y0: Int, x1: Int, y1: Int) {
        let color = convertFillColor()

        for y in y0..<y1 {
            for x in x0..<x1 {
                if x >= 0 && x < fbWidth && y >= 0 && y < fbHeight {
                    setPixel(x: x, y: y, color: color)
                }
            }
        }
    }

    private func drawTextureRectangle(x0: Int, y0: Int, x1: Int, y1: Int,
                                    texCoords: UInt32, texParams: UInt32) {
        // Simplified texture rendering
        let s0 = Float(texCoords >> 16) / 1024.0
        let t0 = Float(texCoords & 0xFFFF) / 1024.0
        let ds = Float(texParams >> 16) / 1024.0
        let dt = Float(texParams & 0xFFFF) / 1024.0

        for y in y0..<y1 {
            for x in x0..<x1 {
                if x >= 0 && x < fbWidth && y >= 0 && y < fbHeight {
                    let s = s0 + Float(x - x0) * ds
                    let t = t0 + Float(y - y0) * dt
                    let texColor = sampleTexture(s: s, t: t)
                    setPixel(x: x, y: y, color: texColor)
                }
            }
        }
    }

    private func sampleTexture(s: Float, t: Float) -> UInt32 {
        // Simplified texture sampling
        // In a real implementation, this would read from RDRAM texture data
        return 0xFFFFFFFF // White for now
    }

    private func setPixel(x: Int, y: Int, color: UInt32) {
        guard x >= 0 && x < fbWidth && y >= 0 && y < fbHeight else { return }

        let offset = (y * fbWidth + x) * 4
        let bytes = framebuffer.advanced(by: offset).assumingMemoryBound(to: UInt8.self)

        bytes[0] = UInt8((color >> 24) & 0xFF) // R
        bytes[1] = UInt8((color >> 16) & 0xFF) // G
        bytes[2] = UInt8((color >> 8) & 0xFF)  // B
        bytes[3] = UInt8(color & 0xFF)         // A
    }

    private func convertFillColor() -> UInt32 {
        // Convert N64 fill color format to RGBA8888
        switch fbFormat {
        case 0: // RGBA 5/5/5/1
            let r = (fillColor >> 11) & 0x1F
            let g = (fillColor >> 6) & 0x1F
            let b = (fillColor >> 1) & 0x1F
            let a = fillColor & 0x1

            return (UInt32(r << 3) << 24) |
                   (UInt32(g << 3) << 16) |
                   (UInt32(b << 3) << 8) |
                   (a != 0 ? 0xFF : 0x00)

        case 2: // RGBA 8/8/8/8
            return fillColor | 0xFF000000

        default:
            return fillColor | 0xFF000000
        }
    }

    private func clearFramebuffer(color: UInt32) {
        for y in 0..<fbHeight {
            for x in 0..<fbWidth {
                setPixel(x: x, y: y, color: color)
            }
        }
    }

    private func updateFramebuffer() {
        // Copy framebuffer to RDRAM if needed
        if fbAddress != 0 {
            let pixelSize = fbFormat == 2 ? 4 : 2
            let totalBytes = fbWidth * fbHeight * pixelSize

            for i in 0..<totalBytes {
                let srcByte = framebuffer.advanced(by: i).assumingMemoryBound(to: UInt8.self).pointee
                memory.write8(fbAddress + UInt32(i), value: srcByte)
            }
        }
    }

    // MARK: - Metal Integration

    private func createMetalTexture() -> MTLTexture? {
        guard let device = metalDevice else { return nil }

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: fbWidth,
            height: fbHeight,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]

        return device.makeTexture(descriptor: descriptor)
    }

    private func updateMetalTexture() {
        guard let texture = metalTexture ?? createMetalTexture() else { return }

        let region = MTLRegionMake2D(0, 0, fbWidth, fbHeight)
        texture.replace(
            region: region,
            mipmapLevel: 0,
            withBytes: framebuffer,
            bytesPerRow: fbWidth * 4
        )

        metalTexture = texture
    }

    // MARK: - Public Interface

    public func getFramebuffer() -> UnsafeMutableRawPointer {
        updateMetalTexture()
        return framebuffer
    }

    public func getFrameSize() -> (width: Int, height: Int) {
        return (fbWidth, fbHeight)
    }

    public func getMetalTexture() -> MTLTexture? {
        updateMetalTexture()
        return metalTexture
    }

    public func getAudioBuffer() -> AudioBuffer? {
        // RDP doesn't generate audio, but we can return silence
        return nil
    }

    // MARK: - State Management

    public func getState() -> RDPState {
        return RDPState(
            commands: commandBuffer,
            colorBuffer: colorBuffer,
            depthBuffer: depthBuffer
        )
    }

    public func setState(_ state: RDPState) {
        commandBuffer = state.commands
        colorBuffer = state.colorBuffer
        depthBuffer = state.depthBuffer
    }

    // MARK: - Helper Methods

    private func getCommandLength(_ opcode: UInt32) -> Int {
        switch opcode {
        case 0x08...0x0B: return 1 // SET_*_COLOR
        case 0x0C: return 2        // SET_COMBINE_MODE
        case 0x0D...0x0F: return 1 // SET_*_IMAGE
        case 0x10: return 2        // SET_SCISSOR
        case 0x2D: return 1        // SET_RENDER_MODE
        case 0x36: return 2        // FILL_RECTANGLE
        case 0x3C, 0x3D: return 4  // TEXTURE_RECTANGLE
        case 0x3E, 0x3F: return 1  // SYNC_*
        default: return 1
        }
    }

    public func setFrameSize(width: Int, height: Int) {
        fbWidth = min(width, 640)
        fbHeight = min(height, 480)
        metalTexture = nil // Force recreation
    }

    public func enhanceGraphics(with enhancer: GraphicsEnhancer, settings: GraphicsSettings) {
        guard let _ = metalDevice,
              let sourceTexture = getMetalTexture() else { return }

        do {
            let enhancedTexture = try enhancer.createEnhancedTexture(
                from: sourceTexture,
                enhancement: settings.enhancement,
                scaleFactor: settings.scaleFactor
            )

            try enhancer.enhance(
                inputTexture: sourceTexture,
                outputTexture: enhancedTexture,
                enhancement: settings.enhancement,
                scaling: settings.scaling
            )

            metalTexture = enhancedTexture
        } catch {
            // Fall back to original rendering
            print("Graphics enhancement failed: \(error)")
        }
    }
}
