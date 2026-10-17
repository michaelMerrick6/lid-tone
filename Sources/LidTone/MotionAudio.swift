import AVFoundation
import HingeAudio
import LidToneCore

final class MotionAudio {
    private let engine = AVAudioEngine()
    private let voice: Voice
    private let source: AVAudioSourceNode
    private(set) var isRunning = false
    private var loadError: Error?
    private var shutdownLoadError: Error?
    private var shutdownPlayer: AVAudioPlayer?

    final class Voice {
        let pointer: OpaquePointer
        init(rate: Double) { pointer = LTVoiceCreate(rate)! }
        deinit { LTVoiceDestroy(pointer) }
    }

    init() {
        let rate = 48_000.0
        let voice = Voice(rate: rate)
        self.voice = voice
        do { try SampleLibrary.load(into: voice.pointer) } catch { loadError = error }
        do { shutdownPlayer = try SampleLibrary.shutdownPlayer() } catch { shutdownLoadError = error }
        source = AVAudioSourceNode { _, _, count, list in
            // No allocation, locks, file access, or SwiftUI work on the render thread.
            for buffer in UnsafeMutableAudioBufferListPointer(list) {
                if let data = buffer.mData { LTVoiceRender(voice.pointer, data.assumingMemoryBound(to: Float.self), count) }
            }
            return noErr
        }
        engine.attach(source)
        engine.connect(source, to: engine.mainMixerNode, format: AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)!)
        engine.prepare()
    }
    func set(_ frame: MotionFrame, volume: Double, style: Int) throws {
        if let loadError { throw loadError }
        LTVoiceSet(voice.pointer, Float(frame.angle), Float(frame.velocity), Float(frame.intensity), Float(volume), Int32(style))
        if frame.intensity > 0 && !isRunning { try engine.start(); isRunning = true }
    }
    func silence() { LTVoiceSet(voice.pointer, 90, 0, 0, 0, 0) }
    func playShutdown(volume: Double) throws {
        if let shutdownLoadError { throw shutdownLoadError }
        guard let shutdownPlayer else { return }
        silence()
        shutdownPlayer.stop(); shutdownPlayer.currentTime = 0
        shutdownPlayer.volume = Float(min(1, max(0, volume)))
        guard shutdownPlayer.play() else {
            throw NSError(domain: "LidTone.Audio", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not start the power-down sound"])
        }
    }
    var remainingShutdown: TimeInterval {
        guard let shutdownPlayer, shutdownPlayer.isPlaying else { return 0 }
        return max(0, shutdownPlayer.duration-shutdownPlayer.currentTime)
    }
    func stopShutdown() { shutdownPlayer?.stop() }
    func pauseMotion() { silence(); engine.pause(); isRunning = false }
    func pause() { pauseMotion(); stopShutdown() }
}
