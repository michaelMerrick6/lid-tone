import Foundation
import IOKit
import IOKit.pwr_mgt
import LidToneCore
import PowerBridge

private let powerCallback: IOServiceInterestCallback = { context, _, message, argument in
    guard let context else { return }
    Unmanaged<PowerMonitor>.fromOpaque(context).takeUnretainedValue().handle(message, argument: argument)
}

final class PowerMonitor {
    let queue = DispatchQueue(label: "com.michaelmerrick.LidTone.power", qos: .userInitiated)
    private var powerPort: IONotificationPortRef?
    private var lidPort: IONotificationPortRef?
    private var powerNotifier: io_object_t = 0
    private var lidNotifier: io_object_t = 0
    private var connection: io_connect_t = 0
    private var root: io_service_t = 0
    private var transition = LidTransition(initialState: nil)
    private var pending: SleepAcknowledgement?
    private var enabled = true
    private let audio = SoundEngine()
    var onStatus: ((String) -> Void)?

    static func readLid(_ root: io_registry_entry_t) -> Bool? {
        guard root != 0, let property = IORegistryEntryCreateCFProperty(root, kAppleClamshellStateKey as CFString, kCFAllocatorDefault, 0) else { return nil }
        return (property.takeRetainedValue() as? NSNumber)?.boolValue
    }

    func start() -> String {
        queue.sync {
            root = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
            transition.synchronize(Self.readLid(root))
            let context = Unmanaged.passUnretained(self).toOpaque()
            connection = IORegisterForSystemPower(context, &powerPort, powerCallback, &powerNotifier)
            lidPort = IONotificationPortCreate(kIOMainPortDefault)
            guard root != 0, connection != 0, let powerPort, let lidPort else {
                cleanup(); return "Could not connect to macOS power notifications. Relaunch LidTone."
            }
            let result = IOServiceAddInterestNotification(lidPort, root, kIOGeneralInterest, powerCallback, context, &lidNotifier)
            guard result == KERN_SUCCESS else {
                cleanup(); return "Could not subscribe to lid notifications. Relaunch LidTone."
            }
            IONotificationPortSetDispatchQueue(powerPort, queue)
            IONotificationPortSetDispatchQueue(lidPort, queue)
            if let error = audio.loadError { return error }
            return transition.isClosed == nil ? "No laptop lid detected. Sound previews still work." : "Listening for your next lid close."
        }
    }

    func configure(enabled: Bool, sound: String, volume: Double, random: Bool, customURL: URL?) {
        queue.async {
            self.enabled = enabled
            self.audio.configure(selection: sound, volume: volume, random: random, customURL: customURL)
            if !enabled { self.audio.stop(); self.pending?.complete() }
            if let error = self.audio.loadError { self.onStatus?(error) }
        }
    }

    func preview(_ id: String) {
        queue.async {
            if let error = self.audio.play(isLid: false, previewID: id) { self.onStatus?(error) }
            else { self.onStatus?("Preview played. Close your lid to try the real thing.") }
        }
    }

    private func observe(_ closed: Bool) {
        if transition.observe(closed, enabled: enabled) {
            if let error = audio.play(isLid: true) { onStatus?(error) }
            else { onStatus?("Lid closed · sound played at \(Date().formatted(date: .omitted, time: .shortened))") }
        }
    }

    fileprivate func handle(_ message: natural_t, argument: UnsafeMutableRawPointer?) {
        switch message {
        case UInt32(LTMessageClamshellChanged):
            // The notification carries state directly; no polling or sensor permissions.
            let bits = UInt(bitPattern: argument)
            observe(bits & UInt(kClamshellStateBit) != 0)
        case UInt32(LTMessageCanSleep):
            IOAllowPowerChange(connection, Int(bitPattern: argument))
        case UInt32(LTMessageWillSleep):
            pending?.complete()
            let port = connection
            let token = Int(bitPattern: argument)
            let acknowledgement = SleepAcknowledgement { IOAllowPowerChange(port, token) }
            pending = acknowledgement
            // Runs on a separate queue even if audio or the monitor queue stalls.
            acknowledgement.armWatchdog()
            if let closed = Self.readLid(root) { observe(closed) }
            let delay = SleepAcknowledgement.playbackDelay(remaining: audio.remainingLidAudio)
            if delay == 0 { acknowledgement.complete() }
            else { queue.asyncAfter(deadline: .now() + delay) { acknowledgement.complete() } }
        case UInt32(LTMessageDidWake):
            pending?.complete(); pending = nil
            audio.stop()
            transition.synchronize(Self.readLid(root))
        default: break
        }
    }

    func stop() { queue.sync { cleanup() } }

    private func cleanup() {
        pending?.complete(); pending = nil
        audio.stop()
        if lidNotifier != 0 { IOObjectRelease(lidNotifier); lidNotifier = 0 }
        if powerNotifier != 0 { IODeregisterForSystemPower(&powerNotifier); powerNotifier = 0 }
        if let lidPort { IONotificationPortDestroy(lidPort); self.lidPort = nil }
        if let powerPort { IONotificationPortDestroy(powerPort); self.powerPort = nil }
        if connection != 0 { IOServiceClose(connection); connection = 0 }
        if root != 0 { IOObjectRelease(root); root = 0 }
    }
}
