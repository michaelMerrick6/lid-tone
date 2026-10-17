import Foundation

/// Hysteresis prevents sensor bounce from replaying a close. Startup/wake are silent.
public struct SaberCloseTrigger {
    public private(set) var armed = false
    public private(set) var isNearClosed = false
    public init() {}

    public mutating func observe(angle: Double, enabled: Bool, style: Int) -> Bool {
        guard angle.isFinite, (0...360).contains(angle) else { return false }
        if angle >= 20 { armed = true; isNearClosed = false }
        guard angle <= 10 else { return false }
        isNearClosed = true
        return closeEvent(enabled: enabled, style: style)
    }

    public mutating func closeEvent(enabled: Bool, style: Int) -> Bool {
        isNearClosed = true
        let play = armed && enabled && style == 1
        armed = false
        return play
    }

    public mutating func reset() { armed = false; isNearClosed = false }
}

/// Sleep completion and its independent watchdog may race; acknowledge exactly once.
public final class SleepAcknowledgement {
    private let lock = NSRecursiveLock()
    private var action: (() -> Void)?
    public static let maximumDelay: TimeInterval = 0.95
    public init(_ action: @escaping () -> Void) { self.action = action }
    public func complete() {
        lock.lock(); defer { lock.unlock() }
        let callback = action; action = nil
        // Cleanup waits until an in-flight IOKit acknowledgement returns.
        callback?()
    }
    public func armWatchdog() {
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now()+Self.maximumDelay) { self.complete() }
    }
    public static func playbackDelay(remaining: TimeInterval) -> TimeInterval {
        guard remaining.isFinite, remaining>0 else { return 0 }
        return min(remaining+0.025, maximumDelay)
    }
}
