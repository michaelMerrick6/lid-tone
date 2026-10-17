import AppKit
import AVFoundation
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
        statusItem.button?.toolTip = "LidTone — sounds for your lid"
        let menu = NSMenu()
        menu.addItem(withTitle: "LidTone…", action: #selector(showSettings), keyEquivalent: ",").target = self
        menu.addItem(withTitle: "Preview sound", action: #selector(preview), keyEquivalent: "").target = self
        menu.addItem(.separator())
        enabledItem = menu.addItem(withTitle: "Enable lid sounds", action: #selector(toggleEnabled), keyEquivalent: "")
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
        if !UserDefaults.standard.bool(forKey: "hasOpened") {
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
    func applicationWillTerminate(_ notification: Notification) { model.monitor.stop() }
}
extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) { enabledItem.state = model.enabled ? .on : .off }
}

if CommandLine.arguments.contains("--check") {
    // Exercises the same bundled audio decoder without a GUI or changing preferences.
    var failures = 0
    for sound in SoundChoice.builtIns {
        do {
            guard let url = SoundResources.bundle.url(forResource: sound.id, withExtension: "wav", subdirectory: "Sounds") else {
                throw NSError(domain: "LidTone", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing resource"])
            }
            let player = try AVAudioPlayer(contentsOf: url)
            guard player.duration > 0 && player.duration <= 0.85, player.prepareToPlay() else {
                throw NSError(domain: "LidTone", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid sound duration or decoder"])
            }
            print("OK \(sound.id): \(String(format: "%.3f", player.duration)) s")
        } catch { failures += 1; print("FAIL \(sound.id): \(error)") }
    }
    exit(failures == 0 ? 0 : 1)
}
let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.run()
