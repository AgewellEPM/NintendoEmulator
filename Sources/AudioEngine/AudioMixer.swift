import AVFoundation
import Accelerate
import CoreInterface
import Combine
import os.log

/// Main audio mixer for emulator audio output
public final class AudioMixer {

    // MARK: - Properties

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let mixer: AVAudioMixerNode
    private let format: AVAudioFormat

    // Audio buffers
    private let bufferQueue = CircularBuffer<AVAudioPCMBuffer>()
    private let resampler: AudioResampler

    // Configuration
    private let sampleRate: Double
    private let channels: Int
    private let bufferSize: Int

    // State
    private var isRunning = false
    private let logger = Logger(subsystem: "com.emulator", category: "AudioMixer")

    // Volume control
    private var masterVolume: Float = 0.7 {
        didSet {
            mixer.volume = masterVolume
        }
    }

    // MARK: - Initialization

    public init(sampleRate: Double = 48000, channels: Int = 2) throws {
        self.sampleRate = sampleRate
        self.channels = channels
        self.bufferSize = 512 // Frames per buffer

        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: AVAudioChannelCount(channels)
        ) else {
            throw AudioError.invalidFormat
        }

        self.format = format
        self.mixer = engine.mainMixerNode
        self.resampler = AudioResampler(targetRate: sampleRate)

        try setupAudioEngine()
        logger.info("Audio mixer initialized: \(sampleRate)Hz, \(channels) channels")
    }

    // MARK: - Setup

    private func setupAudioEngine() throws {
        // Attach player node
        engine.attach(playerNode)

        // Connect nodes
        engine.connect(playerNode, to: mixer, format: format)

        // Configure mixer
        mixer.volume = masterVolume

        // Start engine
        try engine.start()
        isRunning = true

        logger.info("Audio engine started")
    }

    // MARK: - Public Methods

    /// Submit audio buffer from emulator
    public func submitAudioBuffer(
        samples: UnsafeMutablePointer<Float>,
        frameCount: Int,
        sourceSampleRate: Double
    ) {
        guard isRunning else { return }

        // Create PCM buffer
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(frameCount)
        ) else {
            logger.error("Failed to create audio buffer")
            return
        }

        buffer.frameLength = AVAudioFrameCount(frameCount)

        // Resample if necessary
        let resampledSamples: UnsafeMutablePointer<Float>
        let resampledFrameCount: Int
        var shouldFreeResampled = false

        if abs(sourceSampleRate - sampleRate) > 0.01 {
            (resampledSamples, resampledFrameCount) = resampler.resample(
                samples,
                frameCount: frameCount,
                from: sourceSampleRate
            )
            shouldFreeResampled = true
        } else {
            resampledSamples = samples
            resampledFrameCount = frameCount
        }

        // Copy to buffer channels
        if let channelData = buffer.floatChannelData {
            for channel in 0..<Int(format.channelCount) {
                // Copy or duplicate mono to stereo
                if channels == 1 || channel == 0 {
                    vDSP_mmov(
                        resampledSamples,
                        channelData[channel],
                        vDSP_Length(resampledFrameCount),
                        1, 1, 1
                    )
                } else {
                    // Duplicate first channel for stereo
                    vDSP_mmov(
                        resampledSamples,
                        channelData[channel],
                        vDSP_Length(resampledFrameCount),
                        1, 1, 1
                    )
                }
            }
        }

        // Free temporary resampled buffer
        if shouldFreeResampled {
            resampledSamples.deallocate()
        }

        // Schedule buffer for playback
        scheduleBuffer(buffer)
    }

    /// Process audio buffer from emulator
    public func processAudioBuffer(_ audioBuffer: CoreInterface.AudioBuffer) {
        submitAudioBuffer(
            samples: audioBuffer.samples,
            frameCount: audioBuffer.frameCount,
            sourceSampleRate: audioBuffer.sampleRate
        )
    }

    /// Start audio playback
    public func start() {
        guard !playerNode.isPlaying else { return }
        playerNode.play()
        logger.info("Audio playback started")
    }

    /// Stop audio playback
    public func stop() {
        playerNode.stop()
        logger.info("Audio playback stopped")
    }

    /// Pause audio playback
    public func pause() {
        playerNode.pause()
        logger.info("Audio playback paused")
    }

    /// Set master volume (0.0 to 1.0)
    public func setVolume(_ volume: Float) {
        masterVolume = max(0, min(1, volume))
    }

    /// Mute/unmute
    public func setMuted(_ muted: Bool) {
        mixer.volume = muted ? 0 : masterVolume
    }

    // MARK: - Private Methods

    private func scheduleBuffer(_ buffer: AVAudioPCMBuffer) {
        // Add to queue
        bufferQueue.enqueue(buffer)

        // Schedule if not playing
        if !playerNode.isPlaying {
            playerNode.play()
        }

        // Schedule buffer with completion handler
        playerNode.scheduleBuffer(buffer) { [weak self] in
            // Buffer finished playing
            _ = self?.bufferQueue.dequeue()
        }
    }
}

// MARK: - Audio Resampler

/// Handles audio resampling between different sample rates
public final class AudioResampler {

    private let targetRate: Double

    public init(targetRate: Double) {
        self.targetRate = targetRate
    }

    // Simple linear resampler (mono)
    public func resample(
        _ samples: UnsafeMutablePointer<Float>,
        frameCount: Int,
        from sourceRate: Double
    ) -> (UnsafeMutablePointer<Float>, Int) {
        // Compute target frame count
        let outCountDouble = Double(frameCount) * targetRate / sourceRate
        let outputFrameCount = max(1, Int(outCountDouble.rounded()))

        // Allocate output buffer
        let outputSamples = UnsafeMutablePointer<Float>.allocate(capacity: outputFrameCount)

        // If nearly equal rates or trivial input, copy/pad
        if frameCount <= 1 || abs(sourceRate - targetRate) < 0.01 {
            let copyCount = min(frameCount, outputFrameCount)
            for i in 0..<copyCount { outputSamples[i] = samples[i] }
            if outputFrameCount > copyCount {
                let last = samples[frameCount - 1]
                for i in copyCount..<outputFrameCount { outputSamples[i] = last }
            }
            return (outputSamples, outputFrameCount)
        }

        // Linear interpolation
        let rateRatio = sourceRate / targetRate
        for i in 0..<outputFrameCount {
            let t = Double(i) * rateRatio
            let idx = Int(t)
            if idx + 1 < frameCount {
                let frac = Float(t - Double(idx))
                let a = samples[idx]
                let b = samples[idx + 1]
                outputSamples[i] = a + (b - a) * frac
            } else {
                outputSamples[i] = samples[min(idx, frameCount - 1)]
            }
        }

        return (outputSamples, outputFrameCount)
    }
}

// MARK: - Circular Buffer

/// Thread-safe circular buffer for audio buffers
final class CircularBuffer<T> {
    private var buffer: [T?]
    private var readIndex = 0
    private var writeIndex = 0
    private var count = 0
    private let capacity: Int
    private let queue = DispatchQueue(label: "com.emulator.audio.buffer", attributes: .concurrent)

    init(capacity: Int = 8) {
        self.capacity = capacity
        self.buffer = Array(repeating: nil, count: capacity)
    }

    func enqueue(_ element: T) {
        queue.async(flags: .barrier) {
            self.buffer[self.writeIndex] = element
            self.writeIndex = (self.writeIndex + 1) % self.capacity

            if self.count < self.capacity {
                self.count += 1
            } else {
                // Overwrite oldest
                self.readIndex = (self.readIndex + 1) % self.capacity
            }
        }
    }

    func dequeue() -> T? {
        queue.sync(flags: .barrier) {
            guard count > 0 else { return nil }

            let element = buffer[readIndex]
            buffer[readIndex] = nil
            readIndex = (readIndex + 1) % capacity
            count -= 1

            return element
        }
    }

    var isEmpty: Bool {
        queue.sync { count == 0 }
    }

    var isFull: Bool {
        queue.sync { count == capacity }
    }
}

// MARK: - Audio Effects Processor

public final class AudioEffectsProcessor {

    private var effects: [AudioEffect] = []

    public func setEffects(_ effects: [AudioEffect]) {
        self.effects = effects
    }

    public func process(
        _ samples: UnsafeMutablePointer<Float>,
        frameCount: Int,
        sampleRate: Double
    ) {
        for effect in effects {
            switch effect {
            case .reverb:
                applyReverb(samples, frameCount: frameCount, sampleRate: sampleRate)
            case .echo:
                applyEcho(samples, frameCount: frameCount, sampleRate: sampleRate)
            case .lowpass:
                applyLowpass(samples, frameCount: frameCount, sampleRate: sampleRate)
            case .highpass:
                applyHighpass(samples, frameCount: frameCount, sampleRate: sampleRate)
            case .distortion:
                applyDistortion(samples, frameCount: frameCount)
            case .none:
                break
            }
        }
    }

    private func applyReverb(
        _ samples: UnsafeMutablePointer<Float>,
        frameCount: Int,
        sampleRate: Double
    ) {
        // Simple reverb using delay and feedback
        let delayTime = 0.05 // 50ms delay
        let delaySamples = Int(delayTime * sampleRate)
        let feedback: Float = 0.3
        let wetMix: Float = 0.2

        guard delaySamples < frameCount else { return }

        for i in delaySamples..<frameCount {
            let delayed = samples[i - delaySamples]
            samples[i] = samples[i] * (1 - wetMix) + (delayed * feedback * wetMix)
        }
    }

    private func applyEcho(
        _ samples: UnsafeMutablePointer<Float>,
        frameCount: Int,
        sampleRate: Double
    ) {
        // Echo effect with longer delay
        let delayTime = 0.25 // 250ms delay
        let delaySamples = Int(delayTime * sampleRate)
        let feedback: Float = 0.5

        guard delaySamples < frameCount else { return }

        for i in delaySamples..<frameCount {
            samples[i] += samples[i - delaySamples] * feedback
        }
    }

    private func applyLowpass(
        _ samples: UnsafeMutablePointer<Float>,
        frameCount: Int,
        sampleRate: Double
    ) {
        // Simple one-pole lowpass filter
        let cutoff = 5000.0 // 5kHz cutoff
        let rc = 1.0 / (cutoff * 2.0 * .pi)
        let dt = 1.0 / sampleRate
        let alpha = Float(dt / (rc + dt))

        var previousSample: Float = 0

        for i in 0..<frameCount {
            samples[i] = previousSample + alpha * (samples[i] - previousSample)
            previousSample = samples[i]
        }
    }

    private func applyHighpass(
        _ samples: UnsafeMutablePointer<Float>,
        frameCount: Int,
        sampleRate: Double
    ) {
        // Simple one-pole highpass filter
        let cutoff = 100.0 // 100Hz cutoff
        let rc = 1.0 / (cutoff * 2.0 * .pi)
        let dt = 1.0 / sampleRate
        let alpha = Float(rc / (rc + dt))

        var previousSample: Float = 0
        var previousFiltered: Float = 0

        for i in 0..<frameCount {
            let currentSample = samples[i]
            samples[i] = alpha * (previousFiltered + currentSample - previousSample)
            previousSample = currentSample
            previousFiltered = samples[i]
        }
    }

    private func applyDistortion(
        _ samples: UnsafeMutablePointer<Float>,
        frameCount: Int
    ) {
        // Soft clipping distortion
        let gain: Float = 2.0
        let threshold: Float = 0.7

        for i in 0..<frameCount {
            var sample = samples[i] * gain

            // Soft clipping
            if abs(sample) > threshold {
                sample = threshold * tanh(sample / threshold)
            }

            samples[i] = sample / gain
        }
    }
}

// MARK: - Audio Error

public enum AudioError: LocalizedError {
    case invalidFormat
    case engineStartFailed
    case bufferCreationFailed

    public var errorDescription: String? {
        switch self {
        case .invalidFormat: return "Invalid audio format"
        case .engineStartFailed: return "Failed to start audio engine"
        case .bufferCreationFailed: return "Failed to create audio buffer"
        }
    }
}
