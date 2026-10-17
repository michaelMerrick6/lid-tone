import Foundation
import LidToneCore

final class MotionController {
    private let queue = DispatchQueue(label: "com.michaelmerrick.LidTone.hinge", qos: .userInitiated)
    private let sensor = HingeSensor()
    private let audio = MotionAudio()
    private var tracker = MotionTracker()
    private var previewTracker = MotionTracker()
    private var timer: DispatchSourceTimer?
    private var connected = false
    private var enabled = true
    private var suspended = false
    private var volume = 0.65
    private var sensitivity = 1.0
    private var style = 0
    private var retryAt: TimeInterval = 0
    private var previewStarted: TimeInterval?
    private var lastAudible: TimeInterval = 0
    private var tickCount = 0
    private var sensorStatus = "Connecting to hinge sensor…"
    var onReading: ((MotionFrame?, String, Bool) -> Void)?
    var onError: ((String) -> Void)?

    func start() {
        queue.async {
            guard self.timer == nil else { return }
            let timer = DispatchSource.makeTimerSource(queue: self.queue)
            timer.schedule(deadline: .now(), repeating: 1.0/30.0, leeway: .milliseconds(2))
            timer.setEventHandler { [weak self] in self?.tick() }
            self.timer = timer
            timer.resume()
        }
    }
    func configure(enabled: Bool, volume: Double, sensitivity: Double, style: Int) {
        queue.async {
            if self.enabled != enabled {
                self.tracker.reset(); self.connected = false; self.sensor.close(); self.retryAt = 0
            }
            self.enabled = enabled; self.volume = volume; self.style = style; self.sensitivity = sensitivity
            if !enabled { self.audio.silence() }
        }
    }
    func preview() {
        queue.async { self.previewTracker.reset(); self.previewStarted = ProcessInfo.processInfo.systemUptime }
    }
    func suspend() {
        queue.async {
            self.suspended = true; self.previewStarted = nil
            self.tracker.reset(); self.audio.pause(); self.sensor.close(); self.connected = false
        }
    }
    func resume() {
        queue.async { self.suspended = false; self.tracker.reset(); self.retryAt = 0 }
    }
    func stop() {
        queue.sync { timer?.cancel(); timer = nil; audio.pause(); sensor.close(); connected = false }
    }
    private func tick() {
        guard !suspended else { return }
        let now = ProcessInfo.processInfo.systemUptime
        var actual: MotionFrame?
        var status = enabled ? sensorStatus : "Motion sounds are paused."
        if enabled {
            do {
                if !connected && now >= retryAt {
                    try sensor.connect(); connected = true; tracker.reset()
                }
                if connected {
                    actual = tracker.update(angle: try sensor.read(), time: now, sensitivity: sensitivity)
                    sensorStatus = "Live hinge sensor · 30 readings/sec"
                    status = sensorStatus
                }
            } catch {
                connected = false; sensor.close(); tracker.reset(); retryAt = now + 3
                sensorStatus = error.localizedDescription
                status = sensorStatus
            }
        }
        var frame = actual ?? MotionFrame(angle: 90, velocity: 0, intensity: 0)
        var previewing = false
        if let began = previewStarted {
            let elapsed = now - began
            if elapsed < 1.8 {
                previewing = true
                frame = previewTracker.update(angle: 90 + 30*sin(elapsed*Double.pi*1.8), time: now) ?? frame
            } else { previewStarted = nil; tracker.reset(); frame.intensity = 0 }
        }
        do {
            try audio.set(frame, volume: volume, style: style)
            if frame.intensity > 0 { lastAudible = now }
            else if audio.isRunning && now-lastAudible > 0.25 { audio.pause() }
        } catch { audio.pause(); onError?("Audio output failed: \(error.localizedDescription)") }
        tickCount += 1
        if tickCount % 3 == 0 { onReading?(actual, status, previewing) }
    }
}
