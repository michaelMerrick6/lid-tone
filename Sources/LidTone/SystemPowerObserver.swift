import Foundation
import HingeAudio
import IOKit.pwr_mgt
import LidToneCore

private let systemPowerCallback: IOServiceInterestCallback = { context, _, message, argument in
    guard let context else { return }
    Unmanaged<SystemPowerObserver>.fromOpaque(context).takeUnretainedValue().handle(message, argument: argument)
}

/// All operations/callbacks run on the controller queue, except the one-shot watchdog.
final class SystemPowerObserver {
    private var port: IONotificationPortRef?
    private var notifier: io_object_t = 0
    private var connection: io_connect_t = 0
    private var root: io_service_t = 0
    private var queue: DispatchQueue?
    private var pending: SleepAcknowledgement?
    var onSleep: ((Bool) -> TimeInterval)?
    var onWake: (() -> Void)?
    var isRegistered: Bool { connection != 0 }

    func start(on queue: DispatchQueue) -> Bool {
        self.queue = queue
        root = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        connection = IORegisterForSystemPower(Unmanaged.passUnretained(self).toOpaque(), &port, systemPowerCallback, &notifier)
        guard connection != 0, let port else { stop(); return false }
        IONotificationPortSetDispatchQueue(port, queue)
        return true
    }
    private var lidClosed: Bool {
        guard root != 0, let property = IORegistryEntryCreateCFProperty(root, kAppleClamshellStateKey as CFString, kCFAllocatorDefault, 0) else { return false }
        return (property.takeRetainedValue() as? NSNumber)?.boolValue ?? false
    }
    fileprivate func handle(_ message: natural_t, argument: UnsafeMutableRawPointer?) {
        switch message {
        case UInt32(LTPowerCanSleep):
            IOAllowPowerChange(connection, Int(bitPattern: argument))
        case UInt32(LTPowerWillSleep):
            pending?.complete()
            let connection = connection, token = Int(bitPattern: argument)
            let acknowledgement = SleepAcknowledgement { IOAllowPowerChange(connection, token) }
            pending = acknowledgement
            acknowledgement.armWatchdog()
            let remaining = onSleep?(lidClosed) ?? 0
            let delay = SleepAcknowledgement.playbackDelay(remaining: remaining)
            if delay == 0 { acknowledgement.complete() }
            else { queue?.asyncAfter(deadline: .now()+delay) { acknowledgement.complete() } }
        case UInt32(LTPowerDidWake):
            pending?.complete(); pending = nil
            onWake?()
        default: break
        }
    }
    func stop() {
        pending?.complete(); pending = nil
        if notifier != 0 { IODeregisterForSystemPower(&notifier); notifier = 0 }
        if let port { IONotificationPortDestroy(port); self.port = nil }
        if connection != 0 { IOServiceClose(connection); connection = 0 }
        if root != 0 { IOObjectRelease(root); root = 0 }
        queue = nil
    }
}
