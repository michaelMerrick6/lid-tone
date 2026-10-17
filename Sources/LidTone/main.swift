import AppKit
import HingeAudio
import LidToneCore
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel!
    private var statusItem: NSStatusItem!
    private var window: NSWindow?
    private var enabledItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        model = AppModel()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "laptopcomputer", accessibilityDescription: "LidTone")
        statusItem.button?.toolTip = "LidTone — sounds that follow your screen"
        let menu = NSMenu()
        menu.addItem(withTitle: "LidTone…", action: #selector(showSettings), keyEquivalent: ",").target = self
        menu.addItem(withTitle: "Preview motion", action: #selector(preview), keyEquivalent: "").target = self
        menu.addItem(.separator())
        enabledItem = menu.addItem(withTitle: "Enable motion sounds", action: #selector(toggleEnabled), keyEquivalent: "")
        enabledItem.target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit LidTone", action: #selector(quit), keyEquivalent: "q").target = self
        menu.delegate = self
        statusItem.menu = menu
        let mainMenu = NSMenu()
        let appMenu = NSMenu()
        let appItem = NSMenuItem()
        appItem.submenu = appMenu
        appMenu.addItem(withTitle: "LidTone Settings…", action: #selector(showSettings), keyEquivalent: ",").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit LidTone", action: #selector(quit), keyEquivalent: "q").target = self
        mainMenu.addItem(appItem)
        NSApp.mainMenu = mainMenu
        if !UserDefaults.standard.bool(forKey: "hasOpened") || !model.loginEnabled {
            showSettings()
            UserDefaults.standard.set(true, forKey: "hasOpened")
        }
    }

    @objc func showSettings() {
        if window == nil {
            let controller = NSHostingController(rootView: SettingsView(model: model))
            let window = NSWindow(contentViewController: controller)
            window.title = "LidTone"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
    @objc private func preview() { model.preview() }
    @objc private func toggleEnabled() { model.enabled.toggle() }
    @objc private func quit() { NSApp.terminate(nil) }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool { showSettings(); return true }
    func applicationWillTerminate(_ notification: Notification) { model.motion.stop() }
}
extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) { enabledItem.state = model.enabled ? .on : .off }
}

if CommandLine.arguments.contains("--sensor-check") {
    do {
        let sensor = HingeSensor(); try sensor.connect()
        print("Live hinge sensor: \(try sensor.read())°")
        sensor.close(); exit(0)
    } catch { print(error.localizedDescription); exit(1) }
}
if CommandLine.arguments.contains("--check") {
    guard let voice = LTVoiceCreate(48000) else { exit(1) }
    defer { LTVoiceDestroy(voice) }
    do { try SampleLibrary.load(into: voice) }
    catch { print("Audio assets: \(error.localizedDescription)"); exit(1) }
    for style in 0...2 {
        LTVoiceSet(voice, 90, 50, 0.8, 0.65, Int32(style))
        var samples = [Float](repeating: 0, count: 4800)
        LTVoiceRender(voice, &samples, UInt32(samples.count))
        guard samples.allSatisfy({ $0.isFinite && abs($0) <= 0.68 }), samples.contains(where: { abs($0) > 0.01 }) else { exit(1) }
        print("OK \(["recorded wood", "recorded lightsaber", "sampled accordion"][style]): loaded samples render a bounded signal")
    }
    do {
        let player = try SampleLibrary.shutdownPlayer(prepare: false)
        print("OK lightsaber power-down: \(String(format: "%.3f", player.duration)) seconds")
    } catch { print("Power-down asset: \(error.localizedDescription)"); exit(1) }
    exit(0)
}
let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.run()
