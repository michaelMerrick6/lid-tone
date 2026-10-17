import Foundation

public struct MotionFrame: Equatable {
    public var angle: Double
    public var velocity: Double
    public var intensity: Double
    public init(angle: Double, velocity: Double, intensity: Double) {
        self.angle = angle; self.velocity = velocity; self.intensity = intensity
    }
}

public enum HingeReport {
    /// Apple sensor-page orientation device, report 1: ID + little-endian degrees.
    public static func decode(_ bytes: [UInt8]) -> Double? {
        guard bytes.count >= 3, bytes[0] == 1 else { return nil }
        let degrees = Int(bytes[1]) | Int(bytes[2]) << 8
        return degrees <= 360 ? Double(degrees) : nil
    }
}

public struct MotionTracker {
    private var previous: (angle: Double, time: TimeInterval)?
    private var lastMovement: TimeInterval = 0
    private var velocity: Double = 0
    private var stepInterval: TimeInterval = 0.08
    private var hasMoved = false
    public init() {}
    public mutating func reset() { previous = nil; velocity = 0; lastMovement = 0; stepInterval = 0.08; hasMoved = false }

    public mutating func update(angle: Double, time: TimeInterval, sensitivity: Double = 1) -> MotionFrame? {
        guard angle.isFinite, (0...360).contains(angle), time.isFinite else { reset(); return nil }
        defer { previous = (angle, time) }
        guard let previous, time > previous.time, time-previous.time < 0.5 else {
            velocity = 0; lastMovement = time; hasMoved = false
            return MotionFrame(angle: angle, velocity: 0, intensity: 0)
        }
        let dt = time-previous.time
        let delta = angle-previous.angle
        // Discontinuous readings are re-baselined, never turned into loud swings.
        guard abs(delta) <= 35 else {
            velocity = 0; lastMovement = time; hasMoved = false
            return MotionFrame(angle: angle, velocity: 0, intensity: 0)
        }
        if abs(delta) >= 0.35 {
            // Whole-degree sensors repeat values while still moving. Estimate speed
            // over the time between angle steps, instead of treating each as a burst.
            let elapsed = hasMoved ? max(dt, time-lastMovement) : max(dt, 0.08)
            if hasMoved { stepInterval = min(0.35, max(0.033, elapsed)) }
            let instantaneous = max(-300, min(300, delta / elapsed))
            velocity = !hasMoved || velocity*instantaneous < 0 ? instantaneous : velocity * 0.35 + instantaneous * 0.65
            lastMovement = time
            hasMoved = true
        } else {
            let hold = min(0.42, max(0.12, stepInterval * 1.5))
            if time-lastMovement > hold { velocity *= exp(-dt / 0.055) }
            if time-lastMovement > hold + 0.16 { velocity = 0 }
        }
        let gain = sensitivity.isFinite ? min(2,max(0.4,sensitivity)) : 1
        let speed = abs(velocity)*gain
        let intensity = speed < 0.8 ? 0 : min(1, sqrt(speed / 85))
        return MotionFrame(angle: angle, velocity: velocity, intensity: intensity)
    }
}
