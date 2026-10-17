import AVFoundation
import HingeAudio
import LidToneCore

final class MotionAudio {
    private let engine = AVAudioEngine()
    private let voice: Voice
    private let source: AVAudioSourceNode
    private(set) var isRunning = false

    final class Voice {
        let pointer: OpaquePointer
        init(rate: Double) { pointer = LTVoiceCreate(rate)! }
        deinit { LTVoiceDestroy(pointer) }
    }

    init() {
        let rate = 48_000.0
        let voice = Voice(rate: rate)
        self.voice = voice
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
        LTVoiceSet(voice.pointer, Float(frame.angle), Float(frame.velocity), Float(frame.intensity), Float(volume), Int32(style))
        if frame.intensity > 0 && !isRunning { try engine.start(); isRunning = true }
    }
    func silence() { LTVoiceSet(voice.pointer, 90, 0, 0, 0, 0) }
    func pause() { silence(); engine.pause(); isRunning = false }
}
