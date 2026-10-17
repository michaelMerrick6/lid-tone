import XCTest
@testable import LidToneCore

final class SaberCloseTests: XCTestCase {
    func testClosesOnceThenRearmsAfterOpening() {
        var trigger = SaberCloseTrigger()
        XCTAssertFalse(trigger.observe(angle: 90, enabled: true, style: 1))
        XCTAssertTrue(trigger.observe(angle: 10, enabled: true, style: 1))
        for angle in [9.0, 11, 8, 0, 15, 9] {
            XCTAssertFalse(trigger.observe(angle: angle, enabled: true, style: 1))
        }
        XCTAssertFalse(trigger.observe(angle: 20, enabled: true, style: 1))
        XCTAssertTrue(trigger.observe(angle: 8, enabled: true, style: 1))
    }
    func testStartupAndWakeAtClosedLidAreSilent() {
        var trigger = SaberCloseTrigger()
        XCTAssertFalse(trigger.observe(angle: 0, enabled: true, style: 1))
        _ = trigger.observe(angle: 90, enabled: true, style: 1)
        trigger.reset()
        XCTAssertFalse(trigger.observe(angle: 3, enabled: true, style: 1))
        XCTAssertFalse(trigger.closeEvent(enabled: true, style: 1))
    }
    func testFastCloseSleepFallbackDoesNotReplayAngleTrigger() {
        var trigger = SaberCloseTrigger()
        _ = trigger.observe(angle: 90, enabled: true, style: 1)
        XCTAssertTrue(trigger.closeEvent(enabled: true, style: 1))
        XCTAssertFalse(trigger.observe(angle: 0, enabled: true, style: 1))
        XCTAssertFalse(trigger.closeEvent(enabled: true, style: 1))
    }
    func testSleepCallbackAfterEarlyTriggerIsSilent() {
        var trigger = SaberCloseTrigger()
        _ = trigger.observe(angle: 90, enabled: true, style: 1)
        XCTAssertTrue(trigger.observe(angle: 5, enabled: true, style: 1))
        XCTAssertFalse(trigger.closeEvent(enabled: true, style: 1))
    }
    func testDisabledAndOtherModesConsumeCloseWithoutSound() {
        for (enabled,style) in [(false,1),(true,0),(true,2)] {
            var trigger = SaberCloseTrigger()
            _ = trigger.observe(angle: 90, enabled: enabled, style: style)
            XCTAssertFalse(trigger.observe(angle: 0, enabled: enabled, style: style))
            XCTAssertFalse(trigger.observe(angle: 0, enabled: true, style: 1))
        }
    }
    func testInvalidReadingsCannotArmClose() {
        var trigger = SaberCloseTrigger()
        for angle in [Double.nan, .infinity, -1, 361] {
            XCTAssertFalse(trigger.observe(angle: angle, enabled: true, style: 1))
        }
        XCTAssertFalse(trigger.observe(angle: 0, enabled: true, style: 1))
    }
    func testSleepDelayIsBoundedAndRejectsBadDurations() {
        XCTAssertEqual(SleepAcknowledgement.playbackDelay(remaining: 8),0.95)
        XCTAssertEqual(SleepAcknowledgement.playbackDelay(remaining: 0.5),0.525,accuracy:0.0001)
        for value in [Double.nan, .infinity, 0, -1] {
            XCTAssertEqual(SleepAcknowledgement.playbackDelay(remaining: value),0)
        }
    }
    func testAcknowledgementIsExactlyOnceUnderRace() {
        let lock = NSLock()
        var count = 0
        let acknowledgement = SleepAcknowledgement { lock.lock(); count += 1; lock.unlock() }
        DispatchQueue.concurrentPerform(iterations: 100) { _ in acknowledgement.complete() }
        XCTAssertEqual(count,1)
    }
    func testWatchdogAllowsSleepWithoutNormalCompletion() {
        let finished = expectation(description: "watchdog acknowledges")
        let acknowledgement = SleepAcknowledgement { finished.fulfill() }
        acknowledgement.armWatchdog()
        wait(for:[finished],timeout:2)
        acknowledgement.complete()
    }
    func testCleanupWaitsForAnInFlightAcknowledgement() {
        let entered = DispatchSemaphore(value:0), release = DispatchSemaphore(value:0), cleanup = DispatchSemaphore(value:0)
        let acknowledgement = SleepAcknowledgement { entered.signal(); _ = release.wait(timeout:.now()+2) }
        DispatchQueue.global().async { acknowledgement.complete() }
        XCTAssertEqual(entered.wait(timeout:.now()+1),.success)
        DispatchQueue.global().async { acknowledgement.complete(); cleanup.signal() }
        XCTAssertEqual(cleanup.wait(timeout:.now()+0.03),.timedOut)
        release.signal()
        XCTAssertEqual(cleanup.wait(timeout:.now()+1),.success)
    }
}
