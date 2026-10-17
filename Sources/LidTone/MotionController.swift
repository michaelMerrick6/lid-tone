import Foundation
import LidToneCore

final class MotionController {
    private let queue = DispatchQueue(label: "com.michaelmerrick.LidTone.hinge", qos: .userInitiated)
    private let sensor = HingeSensor()
    private let audio = MotionAudio()
    private let power = SystemPowerObserver()
    private var closeTrigger = SaberCloseTrigger()
    private var shutdownClosing = false
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
            self.power.onSleep = { [weak self] closed in self?.prepareForSleep(lidClosed: closed) ?? 0 }
            self.power.onWake = { [weak self] in self?.resumeWork() }
            if !self.power.start(on: self.queue) {
                self.onError?("Sleep notifications unavailable; the lid-close effect may be cut short.")
            }
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
                self.tracker.reset(); self.closeTrigger.reset(); self.connected = false; self.sensor.close(); self.retryAt = 0
            }
            if self.style != style { self.audio.stopShutdown(); self.shutdownClosing = false }
            self.enabled = enabled; self.volume = volume; self.style = style; self.sensitivity = sensitivity
            if !enabled { self.audio.pause(); self.shutdownClosing = false }
        }
    }
    func preview() {
        queue.async { self.previewTracker.reset(); self.previewStarted = ProcessInfo.processInfo.systemUptime }
    }
    func previewShutdown() {
        queue.async {
            self.previewStarted = nil
            do { try self.audio.playShutdown(volume: self.volume) }
            catch { self.onError?(error.localizedDescription) }
        }
    }
    // NSWorkspace provides a fallback when IOKit registration is unavailable.
    func suspend() {
        queue.async { if !self.power.isRegistered { _ = self.prepareForSleep(lidClosed: false) } }
    }
    func resume() {
        queue.async { if !self.power.isRegistered { self.resumeWork() } }
    }
    private func resumeWork() {
        suspended = false; tracker.reset(); closeTrigger.reset()
        shutdownClosing = false; audio.pause(); retryAt = 0
    }
    private func beginShutdown() {
        guard volume > 0 else { shutdownClosing = false; return }
        do { try audio.playShutdown(volume: volume); shutdownClosing = true }
        catch { onError?(error.localizedDescription) }
    }
    private func prepareForSleep(lidClosed: Bool) -> TimeInterval {
        if lidClosed && closeTrigger.closeEvent(enabled: enabled, style: style) { beginShutdown() }
        suspended = true; previewStarted = nil; tracker.reset()
        sensor.close(); connected = false
        audio.pauseMotion()
        if shutdownClosing { return audio.remainingShutdown }
        audio.stopShutdown()
        return 0
    }
    func stop() {
        queue.sync {
            timer?.cancel(); timer = nil; power.stop()
            audio.pause(); sensor.close(); connected = false
        }
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
        if let actual {
            if actual.angle >= 20 { shutdownClosing = false }
            if closeTrigger.observe(angle: actual.angle, enabled: enabled, style: style) { beginShutdown() }
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
        if style == 1 && closeTrigger.isNearClosed { frame.intensity = 0 }
        do {
            try audio.set(frame, volume: volume, style: style)
            if frame.intensity > 0 { lastAudible = now }
            else if audio.isRunning && now-lastAudible > 0.25 { audio.pauseMotion() }
        } catch { audio.pause(); onError?("Audio output failed: \(error.localizedDescription)") }
        tickCount += 1
        if tickCount % 3 == 0 { onReading?(actual, status, previewing) }
    }
}
