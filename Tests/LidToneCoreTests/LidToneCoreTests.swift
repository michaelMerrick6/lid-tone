import XCTest
import HingeAudio
@testable import LidToneCore

final class LidToneCoreTests: XCTestCase {
    private func fixtureVoice() -> OpaquePointer {
        let voice = LTVoiceCreate(48000)!
        let samples = (0..<48000).map { index in Float(0.7*sin(Double(index)*0.042)+0.15*sin(Double(index)*0.069)) }
        for slot in 0..<5 {
            XCTAssertEqual(LTVoiceLoadSample(voice,Int32(slot),samples,UInt32(samples.count)),1)
        }
        return voice
    }
    func testQuantizedSlowTiltDoesNotPulseToSilenceBetweenSteps() {
        var tracker = MotionTracker()
        _ = tracker.update(angle: 90,time: 1)
        var intensities: [Double] = []
        for tick in 1...100 {
            let frame = tracker.update(angle: 90+Double(tick/9), time: 1+Double(tick)/30)!
            if tick>20 { intensities.append(frame.intensity) }
        }
        XCTAssertTrue(intensities.allSatisfy { $0>0.1 })
        XCTAssertLessThan(intensities.max()!-intensities.min()!,0.1)
    }
    func testRecordedSamplePositionSurvivesControlUpdates() {
        let continuous = fixtureVoice(), updated = fixtureVoice()
        defer { LTVoiceDestroy(continuous); LTVoiceDestroy(updated) }
        var expected = [Float](repeating:0,count:4096)
        LTVoiceSet(continuous,90,20,0.7,0.65,0)
        LTVoiceRender(continuous,&expected,4096)
        var actual: [Float] = []
        for _ in 0..<16 {
            LTVoiceSet(updated,90,20,0.7,0.65,0)
            var block = [Float](repeating:0,count:256)
            LTVoiceRender(updated,&block,256)
            actual += block
        }
        XCTAssertEqual(actual,expected)
    }
    func testEmptyOrInvalidSampleDoesNotCrash() {
        let voice=LTVoiceCreate(48000)!
        defer { LTVoiceDestroy(voice) }
        XCTAssertEqual(LTVoiceLoadSample(voice,0,nil,48000),0)
        XCTAssertEqual(LTVoiceLoadSample(voice,8,[Float](repeating:0,count:32),32),0)
        LTVoiceSet(voice,90,30,0.8,1,2)
        var output=[Float](repeating:1,count:4096)
        LTVoiceRender(voice,&output,4096)
        XCTAssertTrue(output.allSatisfy { $0==0 })
    }
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
        for style in 0...2 {
            let voice = fixtureVoice()
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
        let voice = fixtureVoice()
        defer { LTVoiceDestroy(voice) }
        LTVoiceSet(voice,90,50,1,0,1)
        var samples = [Float](repeating:1,count:4800)
        LTVoiceRender(voice,&samples,UInt32(samples.count))
        XCTAssertTrue(samples.allSatisfy { $0 == 0 })
    }
    func testAudioFadesAfterMotionStops() {
        let voice = fixtureVoice()
        defer { LTVoiceDestroy(voice) }
        var samples = [Float](repeating:0,count:24000)
        LTVoiceSet(voice,90,50,1,1,0)
        LTVoiceRender(voice,&samples,UInt32(samples.count))
        LTVoiceSet(voice,90,0,0,1,0)
        LTVoiceRender(voice,&samples,UInt32(samples.count))
        XCTAssertLessThan(samples.suffix(256).map(abs).max()!,0.0003)
    }
    func testBadAudioParametersCannotProduceNaNOrClipping() {
        let voice = fixtureVoice()
        defer { LTVoiceDestroy(voice) }
        LTVoiceSet(voice,.nan,.infinity,2,-1,99)
        var samples = [Float](repeating:0,count:2048)
        LTVoiceRender(voice,&samples,UInt32(samples.count))
        XCTAssertTrue(samples.allSatisfy { $0.isFinite && abs($0) <= 0.68 })
        XCTAssertNil(LTVoiceCreate(0))
    }
}
