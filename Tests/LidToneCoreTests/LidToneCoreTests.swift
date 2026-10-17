import XCTest
@testable import LidToneCore

final class LidToneCoreTests: XCTestCase {
    func testClosePlaysOnceAndOpenRearms() {
        var lid = LidTransition(initialState: false)
        XCTAssertTrue(lid.observe(true, enabled: true))
        XCTAssertFalse(lid.observe(true, enabled: true))
        XCTAssertFalse(lid.observe(false, enabled: true))
        XCTAssertTrue(lid.observe(true, enabled: true))
    }

    func testStartupWithClosedLidDoesNotPlay() {
        var lid = LidTransition(initialState: true)
        XCTAssertFalse(lid.observe(true, enabled: true))
    }

    func testDisabledCloseStillUpdatesState() {
        var lid = LidTransition(initialState: false)
        XCTAssertFalse(lid.observe(true, enabled: false))
        XCTAssertFalse(lid.observe(true, enabled: true))
        XCTAssertFalse(lid.observe(false, enabled: true))
        XCTAssertTrue(lid.observe(true, enabled: true))
    }

    func testUnknownHardwareDoesNotInventTransition() {
        var lid = LidTransition(initialState: nil)
        XCTAssertFalse(lid.observe(true, enabled: true))
        lid.synchronize(nil)
        XCTAssertFalse(lid.observe(false, enabled: true))
        XCTAssertTrue(lid.observe(true, enabled: true))
    }

    func testWakeSynchronizesWithoutReplaying() {
        var lid = LidTransition(initialState: false)
        XCTAssertTrue(lid.observe(true, enabled: true))
        lid.synchronize(true)
        XCTAssertFalse(lid.observe(true, enabled: true))
        lid.synchronize(false)
        XCTAssertTrue(lid.observe(true, enabled: true))
    }

    func testOpenLidAtIdleSleepIsSilent() {
        var lid = LidTransition(initialState: false)
        XCTAssertFalse(lid.observe(false, enabled: true))
    }

    func testAcknowledgementIsExactlyOnceUnderRace() {
        let lock = NSLock()
        var count = 0
        let acknowledgement = SleepAcknowledgement { lock.lock(); count += 1; lock.unlock() }
        DispatchQueue.concurrentPerform(iterations: 100) { _ in acknowledgement.complete() }
        XCTAssertEqual(count, 1)
    }

    func testCleanupWaitsForInFlightAcknowledgement() {
        let entered = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        let cleanupDone = DispatchSemaphore(value: 0)
        let acknowledgement = SleepAcknowledgement {
            entered.signal()
            _ = release.wait(timeout: .now() + 2)
        }
        DispatchQueue.global().async { acknowledgement.complete() }
        XCTAssertEqual(entered.wait(timeout: .now() + 1), .success)
        DispatchQueue.global().async { acknowledgement.complete(); cleanupDone.signal() }
        XCTAssertEqual(cleanupDone.wait(timeout: .now() + 0.03), .timedOut)
        release.signal()
        XCTAssertEqual(cleanupDone.wait(timeout: .now() + 1), .success)
    }

    func testWatchdogReleasesWithoutPlaybackCompletion() {
        let finished = expectation(description: "acknowledged by watchdog")
        let start = Date()
        let acknowledgement = SleepAcknowledgement { finished.fulfill() }
        acknowledgement.armWatchdog()
        wait(for: [finished], timeout: 2)
        XCTAssertLessThan(Date().timeIntervalSince(start), 1.5)
        acknowledgement.complete() // No duplicate fulfillment after the timer wins.
    }

    func testPlaybackDelayIsBoundedAndRejectsInvalidDurations() {
        XCTAssertEqual(SleepAcknowledgement.playbackDelay(remaining: 8), 0.95)
        XCTAssertEqual(SleepAcknowledgement.playbackDelay(remaining: 0), 0)
        XCTAssertEqual(SleepAcknowledgement.playbackDelay(remaining: -1), 0)
        XCTAssertEqual(SleepAcknowledgement.playbackDelay(remaining: .nan), 0)
        XCTAssertEqual(SleepAcknowledgement.playbackDelay(remaining: .infinity), 0)
        XCTAssertEqual(SleepAcknowledgement.playbackDelay(remaining: 0.2), 0.225, accuracy: 0.0001)
    }
}
