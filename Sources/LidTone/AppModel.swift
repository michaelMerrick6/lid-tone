import AppKit
import ServiceManagement
import SwiftUI
import LidToneCore

struct MotionStyle: Identifiable {
    let id: Int
    let title: String
    let detail: String
    let symbol: String
    static let all: [Self] = [
        .init(id: 0, title: "Creaking hinge", detail: "Real wooden-door creaks, stretched across your tilt.", symbol: "door.left.hand.open"),
        .init(id: 1, title: "Lightsaber", detail: "Recorded saber hum and a sweeping energy blade.", symbol: "bolt.fill"),
        .init(id: 2, title: "Accordion", detail: "Sampled Hohner reeds. Your screen is the bellows.", symbol: "pianokeys")
    ]
}

final class AppModel: ObservableObject {
    @Published var enabled: Bool { didSet { persist() } }
    @Published var selectedStyle: Int { didSet { persist() } }
    @Published var volume: Double { didSet { persist() } }
    @Published var sensitivity: Double { didSet { persist() } }
    @Published var angle: Double?
    @Published var velocity: Double = 0
    @Published var intensity: Double = 0
    @Published var previewing = false
    @Published var status = "Connecting to your hinge sensor…"
    @Published var error: String?
    @Published var loginEnabled = SMAppService.mainApp.status == .enabled
    private let defaults = UserDefaults.standard
    let motion = MotionController()
    private var observers: [NSObjectProtocol] = []

    init() {
        enabled = defaults.object(forKey: "enabled") as? Bool ?? true
        let savedStyle = defaults.integer(forKey: "motionStyle")
        selectedStyle = (0...2).contains(savedStyle) ? savedStyle : 0
        volume = defaults.object(forKey: "volume") as? Double ?? 0.65
        sensitivity = defaults.object(forKey: "sensitivity") as? Double ?? 1
        motion.onReading = { [weak self] frame, text, preview in
            DispatchQueue.main.async {
                self?.angle = frame?.angle
                self?.velocity = frame?.velocity ?? 0
                self?.intensity = frame?.intensity ?? 0
                self?.status = text; self?.previewing = preview
            }
        }
        motion.onError = { [weak self] text in DispatchQueue.main.async { self?.error = text } }
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in self?.motion.suspend() })
        observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in self?.motion.resume() })
        configure(); motion.start()
    }
    deinit { for observer in observers { NSWorkspace.shared.notificationCenter.removeObserver(observer) } }
    var selectedTitle: String { MotionStyle.all[min(2, max(0, selectedStyle))].title }
    var motionLabel: String {
        if previewing { return "Previewing a simulated tilt" }
        if !enabled { return "Paused" }
        if angle == nil { return "No live reading" }
        if intensity == 0 { return "Still · silent" }
        return velocity > 0 ? "Opening" : "Closing"
    }
    private func configure() { motion.configure(enabled: enabled, volume: volume, sensitivity: sensitivity, style: selectedStyle) }
    private func persist() {
        defaults.set(enabled, forKey: "enabled"); defaults.set(selectedStyle, forKey: "motionStyle")
        defaults.set(volume, forKey: "volume"); defaults.set(sensitivity, forKey: "sensitivity")
        error = nil; configure()
    }
    func preview(_ style: Int? = nil) {
        if let style { selectedStyle = style }
        error = nil; motion.preview()
    }
    func setLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            loginEnabled = SMAppService.mainApp.status == .enabled
            if SMAppService.mainApp.status == .requiresApproval {
                error = "Allow LidTone in System Settings → General → Login Items."
                SMAppService.openSystemSettingsLoginItems()
            }
        } catch { self.error = "Login item: \(error.localizedDescription)" }
    }
}
