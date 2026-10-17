import XCTest
import HingeAudio
@testable import LidToneCore

final class LidToneCoreTests: XCTestCase {
    func testReportDecodesDegreesAndRejectsBadData() {
        XCTAssertEqual(HingeReport.decode([1, 91, 0]), 91)
        XCTAssertEqual(HingeReport.decode([1, 104, 1]), 360)
        XCTAssertNil(HingeReport.decode([1, 255, 255]))
        XCTAssertNil(HingeReport.decode([2, 90, 0]))
        XCTAssertNil(HingeReport.decode([1, 90]))
    }
    func testFirstReadingIsSilent() {
        var tracker = MotionTracker()
        XCTAssertEqual(tracker.update(angle: 91,time: 1)?.intensity, 0)
    }
    func testOpeningAndClosingHaveSignedVelocity() {
        var tracker = MotionTracker()
        _ = tracker.update(angle: 90,time: 1)
        let opening = tracker.update(angle: 92,time: 1.033)!
        XCTAssertGreaterThan(opening.velocity, 0)
        XCTAssertGreaterThan(opening.intensity, 0)
        let closing = tracker.update(angle: 89,time: 1.066)!
        XCTAssertLessThan(closing.velocity, 0)
        XCTAssertGreaterThan(closing.intensity, 0)
    }
    func testHoldingStillGoesSilent() {
        var tracker = MotionTracker()
        _ = tracker.update(angle: 90,time: 1)
        _ = tracker.update(angle: 92,time: 1.033)
        var frame: MotionFrame?
        for index in 2...10 { frame = tracker.update(angle: 92,time: 1+Double(index)/30) }
        XCTAssertEqual(frame?.velocity, 0)
        XCTAssertEqual(frame?.intensity, 0)
    }
    func testSmallSensorNoiseStaysSilent() {
        var tracker = MotionTracker()
        _ = tracker.update(angle: 90,time: 1)
        for index in 1...30 {
            XCTAssertEqual(tracker.update(angle: index.isMultiple(of:2) ? 90.1 : 89.9,time: 1+Double(index)/30)?.intensity, 0)
        }
    }
    func testWakeGapRebaselinesInsteadOfMakingSound() {
        var tracker = MotionTracker()
        _ = tracker.update(angle: 90,time: 1)
        XCTAssertEqual(tracker.update(angle: 120,time: 100)?.intensity, 0)
    }
    func testInvalidReadingClearsMotion() {
        var tracker = MotionTracker()
        _ = tracker.update(angle: 90,time: 1)
        XCTAssertNil(tracker.update(angle: .nan,time: 1.033))
        XCTAssertNil(tracker.update(angle: 361,time: 1.066))
        XCTAssertNil(tracker.update(angle: 90,time: .infinity))
        XCTAssertEqual(tracker.update(angle: 120,time: 2)?.intensity, 0)
    }
    func testSensorJumpAndNonmonotonicClockDoNotProduceAudio() {
        var tracker = MotionTracker()
        _ = tracker.update(angle: 90,time: 1)
        XCTAssertEqual(tracker.update(angle: 170,time: 1.033)?.intensity, 0)
        XCTAssertEqual(tracker.update(angle: 171,time: 1.01)?.intensity, 0)
    }
    func testFasterMovementIncreasesIntensityAndSensitivityScalesIt() {
        func sample(delta: Double, sensitivity: Double = 1) -> Double {
            var tracker = MotionTracker()
            _ = tracker.update(angle: 90,time: 1)
            return tracker.update(angle: 90+delta,time: 1.033,sensitivity: sensitivity)!.intensity
        }
        XCTAssertGreaterThan(sample(delta:3),sample(delta:1))
        XCTAssertGreaterThan(sample(delta:1,sensitivity:2),sample(delta:1,sensitivity:0.4))
    }
    func testResetDiscardsPreviousMotion() {
        var tracker = MotionTracker()
        _ = tracker.update(angle: 90,time: 1)
        _ = tracker.update(angle: 92,time: 1.033)
        tracker.reset()
        XCTAssertEqual(tracker.update(angle: 130,time: 1.066)?.intensity, 0)
    }
    func testBothSynthesizersAreAudibleAndBounded() {
        for style in 0...1 {
            let voice = LTVoiceCreate(48000)!
            defer { LTVoiceDestroy(voice) }
            LTVoiceSet(voice,90,40,0.7,0.65,Int32(style))
            var samples = [Float](repeating:0,count:4800)
            LTVoiceRender(voice,&samples,UInt32(samples.count))
            XCTAssertTrue(samples.allSatisfy { $0.isFinite && abs($0) <= 0.68 })
            let rms = sqrt(samples.reduce(0.0) { $0 + Double($1*$1) } / Double(samples.count))
            XCTAssertGreaterThan(rms,0.02)
        }
    }
    func testZeroVolumeIsSilent() {
        let voice = LTVoiceCreate(48000)!
        defer { LTVoiceDestroy(voice) }
        LTVoiceSet(voice,90,50,1,0,1)
        var samples = [Float](repeating:1,count:4800)
        LTVoiceRender(voice,&samples,UInt32(samples.count))
        XCTAssertTrue(samples.allSatisfy { $0 == 0 })
    }
    func testAudioFadesAfterMotionStops() {
        let voice = LTVoiceCreate(48000)!
        defer { LTVoiceDestroy(voice) }
        var samples = [Float](repeating:0,count:12000)
        LTVoiceSet(voice,90,50,1,1,0)
        LTVoiceRender(voice,&samples,UInt32(samples.count))
        LTVoiceSet(voice,90,0,0,1,0)
        LTVoiceRender(voice,&samples,UInt32(samples.count))
        XCTAssertLessThan(samples.suffix(256).map(abs).max()!,0.0003)
    }
    func testBadAudioParametersCannotProduceNaNOrClipping() {
        let voice = LTVoiceCreate(48000)!
        defer { LTVoiceDestroy(voice) }
        LTVoiceSet(voice,.nan,.infinity,2,-1,99)
        var samples = [Float](repeating:0,count:2048)
        LTVoiceRender(voice,&samples,UInt32(samples.count))
        XCTAssertTrue(samples.allSatisfy { $0.isFinite && abs($0) <= 0.68 })
        XCTAssertNil(LTVoiceCreate(0))
    }
}
