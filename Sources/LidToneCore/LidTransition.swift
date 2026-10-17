import Foundation

/// Receives hardware state, never infers a lid event from sleep alone.
public struct LidTransition {
    public private(set) var isClosed: Bool?

    public init(initialState: Bool?) { isClosed = initialState }

    /// Repeated notifications and changes to docked mode must not replay a sound.
    public mutating func observe(_ closed: Bool, enabled: Bool) -> Bool {
        let shouldPlay = isClosed == false && closed && enabled
        isClosed = closed
        return shouldPlay
    }

    /// Wake/startup synchronizes state silently, including closed-lid docked wake.
    public mutating func synchronize(_ closed: Bool?) { isClosed = closed }
}

/// The watchdog and normal completion can race. Exactly one acknowledges sleep.
public final class SleepAcknowledgement {
    private let lock = NSRecursiveLock()
    private var action: (() -> Void)?
    public static let maximumDelay: TimeInterval = 0.95

    public init(_ action: @escaping () -> Void) { self.action = action }

    public func complete() {
        lock.lock()
        defer { lock.unlock() }
        let callback = action
        action = nil
        // Cleanup must not close the power connection while another caller is acknowledging it.
        callback?()
    }

    public func armWatchdog(on queue: DispatchQueue = .global(qos: .userInitiated)) {
        queue.asyncAfter(deadline: .now() + Self.maximumDelay) { self.complete() }
    }

    public static func playbackDelay(remaining: TimeInterval) -> TimeInterval {
        guard remaining.isFinite, remaining > 0 else { return 0 }
        return min(remaining + 0.025, maximumDelay)
    }
}
