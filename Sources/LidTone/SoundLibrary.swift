import AVFoundation
import Foundation

struct SoundChoice: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    static let builtIns: [Self] = [
        .init(id: "wooden-door", title: "Wooden door", detail: "A little creak. A warm, solid thud.", symbol: "door.left.hand.closed"),
        .init(id: "soft-latch", title: "Soft latch", detail: "A quiet click for a clean exit.", symbol: "lock"),
        .init(id: "book-close", title: "Book close", detail: "Paper, a soft flap, and a final chapter.", symbol: "book.closed"),
        .init(id: "sci-fi-hatch", title: "Space hatch", detail: "A short air seal from another world.", symbol: "sparkles")
    ]
}

/// Confined to the power monitor's serial queue. Sounds are decoded before lid close.
final class SoundEngine {
    private var players: [String: AVAudioPlayer] = [:]
    private var active: AVAudioPlayer?
    private var activeIsLidSound = false
    private var selection = "wooden-door"
    private var volume: Float = 0.65
    private var random = false
    private(set) var loadError: String?

    init() {
        for choice in SoundChoice.builtIns {
            guard let url = SoundResources.bundle.url(forResource: choice.id, withExtension: "wav", subdirectory: "Sounds") else {
                loadError = "Missing bundled sound: \(choice.title)"; continue
            }
            do { try load(url, id: choice.id) }
            catch { loadError = "Could not load \(choice.title): \(error.localizedDescription)" }
        }
    }

    private func load(_ url: URL, id: String) throws {
        let player = try AVAudioPlayer(contentsOf: url)
        guard player.duration > 0, player.duration <= 0.85 else {
            throw NSError(domain: "LidTone", code: 1, userInfo: [NSLocalizedDescriptionKey: "Choose audio between 0 and 0.85 seconds long."])
        }
        player.prepareToPlay()
        players[id] = player
    }

    func configure(selection: String, volume: Double, random: Bool, customURL: URL?) {
        self.selection = selection
        self.volume = Float(min(max(volume, 0), 1))
        self.random = random
        if let url = customURL {
            do { try load(url, id: "custom"); loadError = nil }
            catch { players["custom"] = nil; loadError = error.localizedDescription }
        } else { players["custom"] = nil }
    }

    @discardableResult
    func play(isLid: Bool, previewID: String? = nil) -> String? {
        let id = previewID ?? (random ? SoundChoice.builtIns.randomElement()!.id : selection)
        guard let player = players[id] else { return "Sound unavailable. Choose a built-in sound or import the file again." }
        active?.stop()
        player.currentTime = 0
        player.volume = volume
        active = player
        activeIsLidSound = isLid
        return player.play() ? nil : "The audio output could not start playback."
    }

    var remainingLidAudio: TimeInterval {
        guard activeIsLidSound, let player = active, player.isPlaying else { return 0 }
        return max(0, player.duration - player.currentTime)
    }

    func stop() { active?.stop(); activeIsLidSound = false }
}

/// SwiftPM's CLI accessor uses bundleURL; packaged apps keep resources in Contents/Resources.
enum SoundResources {
    static let bundle: Bundle = {
        if let url = Bundle.main.resourceURL?.appendingPathComponent("LidTone_LidTone.bundle"),
           let bundle = Bundle(url: url) { return bundle }
        return Bundle.module
    }()
}
