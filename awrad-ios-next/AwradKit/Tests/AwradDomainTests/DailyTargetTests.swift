import AwradDomain
import Testing

struct DailyTargetTests {
    @Test func clampsBelowTheMinimumAndAboveTheMaximum() {
        #expect(DailyTarget(0).count == DailyTarget.minimum)
        #expect(DailyTarget(-50).count == DailyTarget.minimum)
        #expect(DailyTarget(DailyTarget.maximum + 1).count == DailyTarget.maximum)
    }

    @Test func steppingStaysInsideTheRange() {
        #expect((DailyTarget(DailyTarget.minimum) + -1).count == DailyTarget.minimum)
        #expect((DailyTarget(70) + 1).count == 71)
    }

    @Test func stepperAffordancesFollowTheBounds() {
        #expect(!DailyTarget(DailyTarget.minimum).canDecrease)
        #expect(!DailyTarget(DailyTarget.maximum).canIncrease)
        #expect(DailyTarget(70).canDecrease && DailyTarget(70).canIncrease)
    }

    @Test func idsPrintLowercaseLikeTheWireFormat() throws {
        let id = try #require(AwradID("3285E014-551B-46A4-AEDC-8B6664B59BC7"))
        #expect(id.description == "3285e014-551b-46a4-aedc-8b6664b59bc7")
    }
}
