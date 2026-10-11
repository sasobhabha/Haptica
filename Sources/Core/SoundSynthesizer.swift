import AVFoundation
import Foundation
import Combine

public enum SoundEffect: Sendable {
    case bubblePop(pitch: Float = 1.0)
    case ratchetTick(pitch: Float = 1.0)
    case heavyClunk
    case kalimbaNote(index: Int)
    case drumKick
    case drumSnare
    case drumHiHat
    case drumClap
    case marbleBounce(speed: Float = 1.0)
    case sandGrain
    case catPurr
    case heartLub
    case heartDub
}

public final class SoundSynthesizer: ObservableObject {
    public static let shared = SoundSynthesizer()

    @Published public var volume: Float = 0.8
    @Published public var isMuted: Bool = false

    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let sampleRate: Double = 44100.0
    private let audioFormat: AVAudioFormat

    // Cache of procedurally generated PCM buffers
    private var bufferCache: [String: AVAudioPCMBuffer] = [:]
    private let cacheQueue = DispatchQueue(label: "com.antigravity.haptica.soundcache")

    private init() {
        self.audioFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        setupEngine()
        pregenerateBuffers()
    }

    private func setupEngine() {
        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: audioFormat)

        do {
            try audioEngine.start()
            playerNode.play()
        } catch {
            print("[SoundSynthesizer] Failed to start AVAudioEngine: \(error)")
        }
    }

    public func play(_ effect: SoundEffect) {
        guard !isMuted && volume > 0.01 else { return }

        // Fetch or create buffer
        let key = cacheKey(for: effect)
        let buffer: AVAudioPCMBuffer?

        if let cached = bufferCache[key] {
            buffer = cached
        } else {
            buffer = generateBuffer(for: effect)
            if let b = buffer {
                bufferCache[key] = b
            }
        }

        guard let validBuffer = buffer else { return }

        if !audioEngine.isRunning {
            try? audioEngine.start()
        }
        if !playerNode.isPlaying {
            playerNode.play()
        }

        playerNode.scheduleBuffer(validBuffer, at: nil, options: [], completionHandler: nil)
        playerNode.volume = volume
    }

    private func cacheKey(for effect: SoundEffect) -> String {
        switch effect {
        case .bubblePop(let pitch): return "pop_\(Int(pitch * 10))"
        case .ratchetTick(let pitch): return "tick_\(Int(pitch * 10))"
        case .heavyClunk: return "clunk"
        case .kalimbaNote(let idx): return "kalimba_\(idx)"
        case .drumKick: return "kick"
        case .drumSnare: return "snare"
        case .drumHiHat: return "hihat"
        case .drumClap: return "clap"
        case .marbleBounce(let spd): return "bounce_\(min(5, max(1, Int(spd * 2))))"
        case .sandGrain: return "sand_\(Int.random(in: 0...2))"
        case .catPurr: return "purr"
        case .heartLub: return "heart_lub"
        case .heartDub: return "heart_dub"
        }
    }

    private func pregenerateBuffers() {
        // Pre-warm common sounds for zero-latency instant triggering
        _ = generateBuffer(for: .bubblePop(pitch: 1.0))
        _ = generateBuffer(for: .bubblePop(pitch: 1.2))
        _ = generateBuffer(for: .bubblePop(pitch: 0.8))
        _ = generateBuffer(for: .ratchetTick(pitch: 1.0))
        _ = generateBuffer(for: .heavyClunk)
        _ = generateBuffer(for: .drumKick)
        _ = generateBuffer(for: .drumSnare)
        _ = generateBuffer(for: .drumHiHat)
        _ = generateBuffer(for: .drumClap)
        for i in 0..<8 {
            _ = generateBuffer(for: .kalimbaNote(index: i))
        }
        _ = generateBuffer(for: .catPurr)
        _ = generateBuffer(for: .heartLub)
        _ = generateBuffer(for: .heartDub)
    }

    private func createEmptyBuffer(duration: Double) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        return AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount)
    }

    private func generateBuffer(for effect: SoundEffect) -> AVAudioPCMBuffer? {
        let key = cacheKey(for: effect)
        if let existing = bufferCache[key] { return existing }

        switch effect {
        case .bubblePop(let pitch):
            let duration = 0.08
            guard let buffer = createEmptyBuffer(duration: duration) else { return nil }
            buffer.frameLength = buffer.frameCapacity
            let left = buffer.floatChannelData![0]
            let right = buffer.floatChannelData![1]
            let frames = Int(buffer.frameLength)

            let baseFreq: Double = 350.0 * Double(pitch)
            let endFreq: Double = 1100.0 * Double(pitch)

            for i in 0..<frames {
                let t = Double(i) / sampleRate
                let progress = t / duration
                // Exponential pitch sweep up and rapid decay
                let freq = baseFreq + (endFreq - baseFreq) * pow(progress, 0.4)
                let phase = 2.0 * .pi * freq * t
                let env = pow(1.0 - progress, 2.5)
                let sample = Float(sin(phase) * env * 0.75)
                left[i] = sample
                right[i] = sample
            }
            bufferCache[key] = buffer
            return buffer

        case .ratchetTick(let pitch):
            let duration = 0.03
            guard let buffer = createEmptyBuffer(duration: duration) else { return nil }
            buffer.frameLength = buffer.frameCapacity
            let left = buffer.floatChannelData![0]
            let right = buffer.floatChannelData![1]
            let frames = Int(buffer.frameLength)
            let freq: Double = 2200.0 * Double(pitch)

            for i in 0..<frames {
                let t = Double(i) / sampleRate
                let progress = t / duration
                let env = pow(1.0 - progress, 4.0)
                // Crisp click transient + filtered noise
                let tone = sin(2.0 * .pi * freq * t)
                let noise = Double.random(in: -0.5...0.5)
                let sample = Float((tone * 0.6 + noise * 0.4) * env * 0.7)
                left[i] = sample
                right[i] = sample
            }
            bufferCache[key] = buffer
            return buffer

        case .heavyClunk:
            let duration = 0.16
            guard let buffer = createEmptyBuffer(duration: duration) else { return nil }
            buffer.frameLength = buffer.frameCapacity
            let left = buffer.floatChannelData![0]
            let right = buffer.floatChannelData![1]
            let frames = Int(buffer.frameLength)

            for i in 0..<frames {
                let t = Double(i) / sampleRate
                let progress = t / duration
                let env = pow(1.0 - progress, 2.0)
                let thud = sin(2.0 * .pi * 85.0 * t) * 0.8
                let ring = sin(2.0 * .pi * 420.0 * t) * 0.25 * pow(1.0 - progress, 4.0)
                let sample = Float((thud + ring) * env * 0.85)
                left[i] = sample
                right[i] = sample
            }
            bufferCache[key] = buffer
            return buffer

        case .kalimbaNote(let index):
            // Pentatonic scale: C4, D4, E4, G4, A4, C5, D5, E5
            let frequencies: [Double] = [261.63, 293.66, 329.63, 392.00, 440.00, 523.25, 587.33, 659.25]
            let freq = frequencies[min(index, frequencies.count - 1)]
            let duration = 0.55
            guard let buffer = createEmptyBuffer(duration: duration) else { return nil }
            buffer.frameLength = buffer.frameCapacity
            let left = buffer.floatChannelData![0]
            let right = buffer.floatChannelData![1]
            let frames = Int(buffer.frameLength)

            for i in 0..<frames {
                let t = Double(i) / sampleRate
                let progress = t / duration
                let env = exp(-progress * 5.5) // Exponential decay
                // Fundamental + harmonic overtone (struck metal tine)
                let fundamental = sin(2.0 * .pi * freq * t)
                let harmonic = sin(2.0 * .pi * (freq * 2.76) * t) * 0.3 * exp(-progress * 12.0)
                let sample = Float((fundamental + harmonic) * env * 0.7)
                left[i] = sample
                right[i] = sample
            }
            bufferCache[key] = buffer
            return buffer

        case .drumKick:
            let duration = 0.22
            guard let buffer = createEmptyBuffer(duration: duration) else { return nil }
            buffer.frameLength = buffer.frameCapacity
            let left = buffer.floatChannelData![0]
            let right = buffer.floatChannelData![1]
            let frames = Int(buffer.frameLength)

            for i in 0..<frames {
                let t = Double(i) / sampleRate
                let progress = t / duration
                let freq = 140.0 * exp(-progress * 15.0) + 42.0 // Pitch drop
                let env = pow(1.0 - progress, 1.8)
                let sample = Float(sin(2.0 * .pi * freq * t) * env * 0.95)
                left[i] = sample
                right[i] = sample
            }
            bufferCache[key] = buffer
            return buffer

        case .drumSnare:
            let duration = 0.18
            guard let buffer = createEmptyBuffer(duration: duration) else { return nil }
            buffer.frameLength = buffer.frameCapacity
            let left = buffer.floatChannelData![0]
            let right = buffer.floatChannelData![1]
            let frames = Int(buffer.frameLength)

            for i in 0..<frames {
                let t = Double(i) / sampleRate
                let progress = t / duration
                let bodyEnv = pow(1.0 - progress, 3.5)
                let noiseEnv = pow(1.0 - progress, 2.2)
                let body = sin(2.0 * .pi * 180.0 * t) * bodyEnv * 0.5
                let noise = Double.random(in: -0.5...0.5) * noiseEnv * 0.65
                let sample = Float((body + noise) * 0.8)
                left[i] = sample
                right[i] = sample
            }
            bufferCache[key] = buffer
            return buffer

        case .drumHiHat:
            let duration = 0.05
            guard let buffer = createEmptyBuffer(duration: duration) else { return nil }
            buffer.frameLength = buffer.frameCapacity
            let left = buffer.floatChannelData![0]
            let right = buffer.floatChannelData![1]
            let frames = Int(buffer.frameLength)

            for i in 0..<frames {
                let t = Double(i) / sampleRate
                let progress = t / duration
                let env = pow(1.0 - progress, 6.0)
                let noise = Double.random(in: -0.6...0.6)
                let sample = Float(noise * env * 0.65)
                left[i] = sample
                right[i] = sample
            }
            bufferCache[key] = buffer
            return buffer

        case .drumClap:
            let duration = 0.16
            guard let buffer = createEmptyBuffer(duration: duration) else { return nil }
            buffer.frameLength = buffer.frameCapacity
            let left = buffer.floatChannelData![0]
            let right = buffer.floatChannelData![1]
            let frames = Int(buffer.frameLength)

            for i in 0..<frames {
                let t = Double(i) / sampleRate
                let progress = t / duration
                // Multi-burst clapping envelope
                let burst = (sin(progress * 45.0) > 0.0 ? 1.0 : 0.4) * pow(1.0 - progress, 2.8)
                let noise = Double.random(in: -0.6...0.6)
                let sample = Float(noise * burst * 0.75)
                left[i] = sample
                right[i] = sample
            }
            bufferCache[key] = buffer
            return buffer

        case .marbleBounce(let speed):
            let duration = 0.08
            guard let buffer = createEmptyBuffer(duration: duration) else { return nil }
            buffer.frameLength = buffer.frameCapacity
            let left = buffer.floatChannelData![0]
            let right = buffer.floatChannelData![1]
            let frames = Int(buffer.frameLength)
            let baseFreq = 480.0 * min(2.0, max(0.6, Double(speed)))

            for i in 0..<frames {
                let t = Double(i) / sampleRate
                let progress = t / duration
                let env = pow(1.0 - progress, 3.0)
                let impact = sin(2.0 * .pi * baseFreq * t) * env * 0.7
                left[i] = Float(impact)
                right[i] = Float(impact)
            }
            bufferCache[key] = buffer
            return buffer

        case .sandGrain:
            let duration = 0.02
            guard let buffer = createEmptyBuffer(duration: duration) else { return nil }
            buffer.frameLength = buffer.frameCapacity
            let left = buffer.floatChannelData![0]
            let right = buffer.floatChannelData![1]
            let frames = Int(buffer.frameLength)

            for i in 0..<frames {
                let progress = Double(i) / Double(frames)
                let env = pow(1.0 - progress, 4.0)
                let sample = Float(Double.random(in: -0.4...0.4) * env * 0.4)
                left[i] = sample
                right[i] = sample
            }
            bufferCache[key] = buffer
            return buffer

        case .catPurr:
            let duration = 0.28
            guard let buffer = createEmptyBuffer(duration: duration) else { return nil }
            buffer.frameLength = buffer.frameCapacity
            let left = buffer.floatChannelData![0]
            let right = buffer.floatChannelData![1]
            let frames = Int(buffer.frameLength)

            for i in 0..<frames {
                let t = Double(i) / sampleRate
                // Low modulation 26Hz purring flutter
                let carrier = sin(2.0 * .pi * 80.0 * t)
                let mod = 0.5 + 0.5 * sin(2.0 * .pi * 26.0 * t)
                let sample = Float(carrier * mod * 0.45)
                left[i] = sample
                right[i] = sample
            }
            bufferCache[key] = buffer
            return buffer

        case .heartLub:
            let duration = 0.12
            guard let buffer = createEmptyBuffer(duration: duration) else { return nil }
            buffer.frameLength = buffer.frameCapacity
            let left = buffer.floatChannelData![0]
            let right = buffer.floatChannelData![1]
            let frames = Int(buffer.frameLength)

            for i in 0..<frames {
                let t = Double(i) / sampleRate
                let progress = t / duration
                let env = pow(1.0 - progress, 2.2)
                let sample = Float(sin(2.0 * .pi * 55.0 * t) * env * 0.75)
                left[i] = sample
                right[i] = sample
            }
            bufferCache[key] = buffer
            return buffer

        case .heartDub:
            let duration = 0.10
            guard let buffer = createEmptyBuffer(duration: duration) else { return nil }
            buffer.frameLength = buffer.frameCapacity
            let left = buffer.floatChannelData![0]
            let right = buffer.floatChannelData![1]
            let frames = Int(buffer.frameLength)

            for i in 0..<frames {
                let t = Double(i) / sampleRate
                let progress = t / duration
                let env = pow(1.0 - progress, 2.5)
                let sample = Float(sin(2.0 * .pi * 70.0 * t) * env * 0.6)
                left[i] = sample
                right[i] = sample
            }
            bufferCache[key] = buffer
            return buffer
        }
    }
}
