import AwradDomain
import AwradTesting
import Foundation
import Testing

// Every case of contracts/goal-model/v1/fixtures/, run through the real rules. Each test is
// parameterized by case, so a failure names the case ID. The fixtures are the spec: never edit
// them to match this code.

@Suite("goal-model v1 fixtures")
struct GoalModelFixtureTests {
    @Test(arguments: try GoalModelFixtures.effectivePracticeDay())
    func effectivePracticeDay(_ fixture: FixtureCase<EffectiveDayGiven, DateExpect>) {
        let given = fixture.given
        let day = EffectivePracticeDay.resolve(
            at: given.instant, in: given.timeZone, dayReset: given.dayReset, maghrib: given.maghrib)
        #expect(DateExpect(day) == fixture.expect, "\(fixture.id): \(fixture.summary)")
    }

    @Test(arguments: try GoalModelFixtures.goalIsDue())
    func goalIsDue(_ fixture: FixtureCase<GoalOnDay, DueExpect>) {
        let given = fixture.given
        let due = given.goal.isDue(on: given.date, hijriCorrections: given.hijriCorrections)
        #expect(DueExpect(due: due) == fixture.expect, "\(fixture.id): \(fixture.summary)")
    }

    @Test(arguments: try GoalModelFixtures.requirementStanding())
    func requirementStanding(_ fixture: FixtureCase<GoalOnDay, StandingExpect>) throws {
        let given = fixture.given
        let weekStart = try #require(given.weekStart, "\(fixture.id): week_start")
        let standing = given.goal.standing(
            on: given.date, counts: given.counts, weekStart: weekStart, hijriCorrections: given.hijriCorrections)
        #expect(StandingExpect(standing) == fixture.expect, "\(fixture.id): \(fixture.summary)")
    }

    @Test(arguments: try GoalModelFixtures.daysPerPeriod())
    func daysPerPeriod(_ fixture: FixtureCase<GoalOnDay, DaysPerPeriodExpect>) throws {
        let given = fixture.given
        let weekStart = try #require(given.weekStart, "\(fixture.id): week_start")
        let standing = try #require(
            given.goal.daysPerPeriodStanding(
                on: given.date, counts: given.counts, weekStart: weekStart, hijriCorrections: given.hijriCorrections),
            "\(fixture.id): not a days-per-period goal")
        #expect(DaysPerPeriodExpect(standing) == fixture.expect, "\(fixture.id): \(fixture.summary)")
    }

    @Test(arguments: try GoalModelFixtures.goalCompletion())
    func goalCompletion(_ fixture: FixtureCase<GoalOnDay, CompletionExpect>) {
        let given = fixture.given
        let completed = given.goal.isCompleted(on: given.date, counts: given.counts)
        #expect(CompletionExpect(completed: completed) == fixture.expect, "\(fixture.id): \(fixture.summary)")
    }

    @Test(arguments: try GoalModelFixtures.goalStreak())
    func goalStreak(_ fixture: FixtureCase<GoalOnDay, StreakExpect>) throws {
        let given = fixture.given
        let weekStart = try #require(given.weekStart, "\(fixture.id): week_start")
        let current = given.goal.currentStreak(
            on: given.date, counts: given.counts, weekStart: weekStart, hijriCorrections: given.hijriCorrections)
        #expect(StreakExpect(current: current) == fixture.expect, "\(fixture.id): \(fixture.summary)")
    }

    @Test(arguments: try GoalModelFixtures.goalValidity())
    func goalValidity(_ fixture: FixtureCase<GoalValidityGiven, ValidityExpect>) {
        #expect(ValidityExpect(fixture.given.construction) == fixture.expect, "\(fixture.id): \(fixture.summary)")
    }
}

@Suite("fixture runner")
struct FixtureRunnerTests {
    /// Guards against a parameterized test silently running zero cases.
    @Test(
        arguments: GoalModelRule.allCases.map(\.rawValue) + HijriCalendarRule.allCases.map(\.rawValue)
            + AccountModelRule.allCases.map(\.rawValue)
    )
    func everyImplementedRuleHasAFixtureFileWithCases(_ rule: String) throws {
        let file = try Self.fixtureFile(rule)
        #expect(FileManager.default.fileExists(atPath: file.path()), "\(rule).json")
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: file))
        let count = ((object as? [String: Any])?["cases"] as? [Any])?.count ?? 0
        #expect(count > 0, "\(rule) has no cases")
    }

    /// Guards against a new fixture file nobody runs: every file in each directory is a rule above.
    @Test func everyFixtureFileIsAnImplementedRule() throws {
        let goalModel = try FixtureLoader.ruleFiles(model: "goal-model")
        let hijriCalendar = try FixtureLoader.ruleFiles(model: "hijri-calendar")
        let accountModel = try FixtureLoader.ruleFiles(model: "account-model")
        #expect(goalModel == GoalModelRule.allCases.map(\.rawValue).sorted())
        #expect(hijriCalendar == HijriCalendarRule.allCases.map(\.rawValue).sorted())
        #expect(accountModel == AccountModelRule.allCases.map(\.rawValue).sorted())
    }

    @Test func aMissingFileFails() throws {
        let missing = try GoalModelRule.goalStreak.fixtureFile().deletingLastPathComponent()
            .appending(path: "no_such_rule.json")
        #expect(throws: FixtureError.missingFile(missing.path())) {
            try FixtureLoader.load(missing, rule: "no_such_rule", as: (DueExpect.self, DueExpect.self))
        }
    }

    @Test func aFileWithoutCasesFails() throws {
        let file = FileManager.default.temporaryDirectory.appending(path: "empty_rule-\(UUID().uuidString).json")
        try Data(#"{"format": "awrad-fixture/1", "rule": "empty_rule", "cases": []}"#.utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        #expect(throws: FixtureError.noCases(file.path())) {
            try FixtureLoader.load(file, rule: "empty_rule", as: (DueExpect.self, DueExpect.self))
        }
    }

    @Test func aCaseTheAdapterCantDecodeFailsByID() throws {
        let file = FileManager.default.temporaryDirectory.appending(path: "bad_rule-\(UUID().uuidString).json")
        let json =
            #"{"format": "awrad-fixture/1", "rule": "bad_rule", "cases": [{"id": "odd", "given": {}, "expect": {}}]}"#
        try Data(json.utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        let error = #expect(throws: FixtureError.self) {
            try FixtureLoader.load(file, rule: "bad_rule", as: (DueExpect.self, DueExpect.self))
        }
        guard case .undecodableCase(_, let id, _) = error else {
            Issue.record("expected an undecodable case, got \(String(describing: error))")
            return
        }
        #expect(id == "odd")
    }

    private static func fixtureFile(_ rule: String) throws -> URL {
        if let goalModel = GoalModelRule(rawValue: rule) { return try goalModel.fixtureFile() }
        if let account = AccountModelRule(rawValue: rule) { return try account.fixtureFile() }
        let hijri = try #require(HijriCalendarRule(rawValue: rule), "\(rule) isn't an implemented rule")
        return try hijri.fixtureFile()
    }
}
