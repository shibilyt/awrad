import AwradDomain
import AwradTesting
import Foundation
import Testing

// Every case of slice 4a's goal-model fixtures (timelines, versions, the count log and the lists),
// run through the real rules. The fixtures are the spec: never edit them to match this code.

@Suite("goal-model v1 fixtures: timelines")
struct GoalTimelineFixtureTests {
    @Test(arguments: try GoalModelFixtures.goalVersionOnDay())
    func goalVersionOnDay(_ fixture: FixtureCase<VersionOnDayGiven, VersionOnDayExpect>) {
        let timeline = fixture.given.document.timeline
        let day = fixture.given.date
        let actual = VersionOnDayExpect(version: timeline.versionIndex(on: day), goal: timeline.goal(on: day))
        #expect(actual == fixture.expect, "\(fixture.id): \(fixture.summary)")
    }

    @Test(arguments: try GoalModelFixtures.goalVersionAdd())
    func goalVersionAdd(_ fixture: FixtureCase<VersionAddGiven, VersionsExpect>) {
        let given = fixture.given
        let versions = GoalTimeline.versions(given.versions, saving: given.settings, on: given.today)
        #expect(VersionsExpect(versions) == fixture.expect, "\(fixture.id): \(fixture.summary)")
    }

    @Test(arguments: try GoalModelFixtures.countAttribution())
    func countAttribution(_ fixture: FixtureCase<CountAttributionGiven, CountAttributionExpect>) {
        let given = fixture.given
        let goals = given.goals.map { goal in
            let counts = CountAttribution.entries(
                goalID: goal.id, dhikrID: goal.dhikrID, counts: goal.counts, timeline: goal.timeline, log: given.log)
            return (id: goal.id, counts: counts)
        }
        #expect(CountAttributionExpect(goals) == fixture.expect, "\(fixture.id): \(fixture.summary)")
    }

    @Test(arguments: try GoalModelFixtures.makeUp())
    func makeUp(_ fixture: FixtureCase<MakeUpGiven, MakeUpExpect>) {
        let given = fixture.given.goal
        let statuses = given.timeline.dueDayStatuses(
            through: given.date, counts: given.counts, hijriCorrections: given.hijriCorrections)
        let reported = statuses.filter { $0.day >= fixture.given.from }
        #expect(MakeUpExpect(reported) == fixture.expect, "\(fixture.id): \(fixture.summary)")
    }

    @Test(arguments: try GoalModelFixtures.excusedDays())
    func excusedDays(_ fixture: FixtureCase<ExcuseGiven, ExcuseExpect>) {
        let given = fixture.given.goal
        let day = fixture.given.day
        let refusal =
            switch fixture.given.action {
            case .excuse:
                given.timeline.excuseRefusal(
                    for: day, today: given.date, counts: given.counts, hijriCorrections: given.hijriCorrections)
            case .unexcuse:
                given.timeline.unexcuseRefusal(for: day, today: given.date)
            }
        #expect(ExcuseExpect(refusal) == fixture.expect, "\(fixture.id): \(fixture.summary)")
    }

    @Test(arguments: try GoalModelFixtures.consistency())
    func consistency(_ fixture: FixtureCase<TimelineOnDay, ConsistencyExpect>) {
        let given = fixture.given
        let consistency = given.timeline.consistency(
            on: given.date, counts: given.counts, weekStart: given.weekStart, hijriCorrections: given.hijriCorrections)
        #expect(ConsistencyExpect(consistency) == fixture.expect, "\(fixture.id): \(fixture.summary)")
    }

    @Test(arguments: try GoalModelFixtures.dailyPace())
    func dailyPace(_ fixture: FixtureCase<TimelineOnDay, DailyPaceExpect>) {
        let given = fixture.given
        let pace = given.timeline.dailyPace(
            on: given.date, counts: given.counts, hijriCorrections: given.hijriCorrections)
        #expect(DailyPaceExpect(pace) == fixture.expect, "\(fixture.id): \(fixture.summary)")
    }

    @Test(arguments: try GoalModelFixtures.todayRing())
    func todayRing(_ fixture: FixtureCase<TimelineOnDay, TodayRingExpect>) {
        let given = fixture.given
        let ring = given.timeline.todayRing(
            on: given.date, counts: given.counts, weekStart: given.weekStart, hijriCorrections: given.hijriCorrections)
        #expect(TodayRingExpect(ring) == fixture.expect, "\(fixture.id): \(fixture.summary)")
    }

    @Test(arguments: try GoalModelFixtures.goalListPlacement())
    func goalListPlacement(_ fixture: FixtureCase<PlacementGiven, PlacementExpect>) {
        let given = fixture.given
        let list = GoalList(given.goals, order: given.order, today: given.date)
        #expect(PlacementExpect(list) == fixture.expect, "\(fixture.id): \(fixture.summary)")
    }

    @Test(arguments: try GoalModelFixtures.goalOrderMerge())
    func goalOrderMerge(_ fixture: FixtureCase<OrderMergeGiven, OrderMergeExpect>) {
        let given = fixture.given
        let merge = GoalOrder.merge(base: given.base, mine: given.mine, theirs: given.theirs)
        #expect(OrderMergeExpect(merge) == fixture.expect, "\(fixture.id): \(fixture.summary)")
    }
}
