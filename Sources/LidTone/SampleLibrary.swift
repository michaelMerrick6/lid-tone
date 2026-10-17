import AVFoundation
import HingeAudio

/// Decode and copy every sample before the audio callback can run.
enum SampleLibrary {
    static let names = ["wood-creaks", "saber-hum", "saber-swings", "accordion-open", "accordion-close"]
    static var bundle: Bundle {
        if let url = Bundle.main.resourceURL?.appendingPathComponent("LidTone_LidTone.bundle"), let bundle = Bundle(url: url) { return bundle }
        return Bundle.module
    }
    static func load(into voice: OpaquePointer) throws {
        for (slot, name) in names.enumerated() {
            guard let url = bundle.url(forResource: name, withExtension: "wav", subdirectory: "Audio") else {
                throw assetError("Missing audio recording: \(name)")
            }
            let file = try AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false)
            guard file.processingFormat.sampleRate == 48000, file.processingFormat.channelCount == 1,
                  file.length > 32, file.length <= 48000*60,
                  let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else {
                throw assetError("Unsupported audio format: \(name)")
            }
            try file.read(into: buffer)
            guard let channel = buffer.floatChannelData?[0], LTVoiceLoadSample(voice, Int32(slot), channel, buffer.frameLength) == 1 else {
                throw assetError("Could not preload audio recording: \(name)")
            }
        }
    }
    private static func assetError(_ message: String) -> NSError {
        NSError(domain: "LidTone.Audio", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
