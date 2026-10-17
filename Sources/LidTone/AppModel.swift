import AppKit
import AVFoundation
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

final class AppModel: ObservableObject {
    @Published var enabled: Bool { didSet { persist() } }
    @Published var selectedSound: String { didSet { persist() } }
    @Published var volume: Double { didSet { persist() } }
    @Published var shuffle: Bool { didSet { persist() } }
    @Published var customPath: String? { didSet { persist() } }
    @Published var status = "Connecting to your Mac…"
    @Published var loginEnabled = SMAppService.mainApp.status == .enabled
    private let defaults = UserDefaults.standard
    let monitor = PowerMonitor()

    init() {
        enabled = defaults.object(forKey: "enabled") as? Bool ?? true
        selectedSound = defaults.string(forKey: "sound") ?? "wooden-door"
        volume = defaults.object(forKey: "volume") as? Double ?? 0.65
        shuffle = defaults.bool(forKey: "shuffle")
        customPath = defaults.string(forKey: "customPath")
        if !SoundChoice.builtIns.contains(where: { $0.id == selectedSound }) && !(selectedSound == "custom" && customPath != nil) {
            selectedSound = "wooden-door"
        }
        monitor.onStatus = { [weak self] text in DispatchQueue.main.async { self?.status = text } }
        status = monitor.start()
        configure()
    }

    var selectedTitle: String {
        selectedSound == "custom" ? "Your sound" : SoundChoice.builtIns.first(where: { $0.id == selectedSound })?.title ?? "Wooden door"
    }

    private func configure() {
        monitor.configure(enabled: enabled, sound: selectedSound, volume: volume, random: shuffle,
                          customURL: customPath.map { URL(fileURLWithPath: $0) })
    }

    private func persist() {
        defaults.set(enabled, forKey: "enabled")
        defaults.set(selectedSound, forKey: "sound")
        defaults.set(volume, forKey: "volume")
        defaults.set(shuffle, forKey: "shuffle")
        defaults.set(customPath, forKey: "customPath")
        configure()
    }

    func preview(_ id: String? = nil) { monitor.preview(id ?? selectedSound) }

    func setLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            loginEnabled = SMAppService.mainApp.status == .enabled
            if SMAppService.mainApp.status == .requiresApproval {
                status = "Allow LidTone in System Settings → General → Login Items."
                SMAppService.openSystemSettingsLoginItems()
            }
        } catch { status = "Login item: \(error.localizedDescription)" }
    }

    func importSound() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.wav, .aiff, .mpeg4Audio, .mp3]
        panel.allowsMultipleSelection = false
        panel.message = "Choose a sound up to 0.85 seconds long (maximum 2 MB)."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= 2_000_000 else { throw ImportError.tooLarge }
            let player = try AVAudioPlayer(contentsOf: url)
            guard player.duration > 0, player.duration <= 0.85 else { throw ImportError.tooLong }
            let folder = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("LidTone/CustomSounds", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let destination = folder.appendingPathComponent(UUID().uuidString).appendingPathExtension(url.pathExtension)
            try FileManager.default.copyItem(at: url, to: destination)
            let old = customPath
            customPath = destination.path
            selectedSound = "custom"
            shuffle = false
            if let old, URL(fileURLWithPath: old).deletingLastPathComponent().standardizedFileURL == folder.standardizedFileURL {
                try? FileManager.default.removeItem(atPath: old)
            }
            status = "Custom sound ready. Give it a preview."
        } catch { status = error.localizedDescription }
    }
}

private enum ImportError: LocalizedError {
    case tooLarge, tooLong
    var errorDescription: String? {
        switch self {
        case .tooLarge: return "That file is larger than 2 MB. Choose a smaller clip."
        case .tooLong: return "Choose a clip shorter than 0.85 seconds so your Mac can sleep promptly."
        }
    }
}
