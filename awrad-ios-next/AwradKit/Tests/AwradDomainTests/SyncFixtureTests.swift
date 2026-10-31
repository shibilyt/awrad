import AwradDomain
import AwradTesting
import Foundation
import Testing

/// contracts/sync/v1: every case of the five phone rules, unedited, through the real domain code.
@Suite("sync fixtures")
struct SyncFixtureTests {
    @Test(arguments: try SyncFixtures.tagNameNormalization())
    func tagNameNormalization(_ fixture: FixtureCase<TagNameGiven, TagNameExpect>) {
        let result: TagNameExpect
        do {
            let names = try TagName.normalize(fixture.given.input)
            result = TagNameExpect(accepted: true, name: names.name, normalizedName: names.normalizedName, reason: nil)
        } catch {
            result = TagNameExpect(accepted: false, name: nil, normalizedName: nil, reason: error.rawValue)
        }
        #expect(result == fixture.expect, "\(fixture.id): \(fixture.summary)")
    }

    @Test(arguments: try SyncFixtures.customDhikrValidity())
    func customDhikrValidity(_ fixture: FixtureCase<CustomDhikrValidityGiven, ValidityShape>) {
        let errors = CustomDhikrValidation.errors(in: fixture.given.document)
        let result = ValidityShape(
            valid: errors.isEmpty, errors: errors.map { FieldErrorShape(field: $0.field, code: $0.code) })
        #expect(result == fixture.expect, "\(fixture.id): \(fixture.summary)")
        // A valid document builds the typed document, which writes the same JSON back.
        if errors.isEmpty {
            #expect((try? CustomDhikrDocument(json: fixture.given.document))?.json == fixture.given.document)
        }
    }

    @Test(arguments: try SyncFixtures.goalDocumentValidity())
    func goalDocumentValidity(_ fixture: FixtureCase<CustomDhikrValidityGiven, ValidityShape>) {
        let errors = GoalDocumentValidation.errors(in: fixture.given.document)
        let result = ValidityShape(
            valid: errors.isEmpty, errors: errors.map { FieldErrorShape(field: $0.field, code: $0.code) })
        #expect(result == fixture.expect, "\(fixture.id): \(fixture.summary)")
        // A valid document builds the typed document, which writes the same JSON back.
        if errors.isEmpty {
            #expect((try? GoalDocument(json: fixture.given.document))?.json == fixture.given.document)
        }
    }

    @Test(arguments: try SyncFixtures.outboxEnqueue())
    func outboxEnqueue(_ fixture: FixtureCase<OutboxEnqueueGiven, OutboxShape>) throws {
        var state = try fixture.given.state()
        SyncRules.enqueue(try fixture.given.edit.edit(), in: &state)
        #expect(OutboxShape(outbox: state.outbox.map(CommandShape.init)) == fixture.expect, "\(fixture.id)")
    }

    @Test(arguments: try SyncFixtures.applyChanges())
    func applyChanges(_ fixture: FixtureCase<ApplyChangesGiven, ApplyChangesExpect>) throws {
        var state = try fixture.given.local.state()
        let (notices, uploads) = try fixture.given.run(on: &state)
        let result = ApplyChangesExpect(local: LocalShape(state), notices: notices, uploadsQueued: uploads)
        #expect(result.local.entities == fixture.expect.local.entities, "\(fixture.id): entities")
        #expect(result.local.outbox == fixture.expect.local.outbox, "\(fixture.id): outbox")
        #expect(result.local.conflicts == fixture.expect.local.conflicts, "\(fixture.id): conflicts")
        #expect(result.uploadsQueued == fixture.expect.uploadsQueued, "\(fixture.id): uploads_queued")
        #expect(result == fixture.expect, "\(fixture.id): \(fixture.summary)")
    }

    @Test(arguments: try SyncFixtures.profileSwitch())
    func profileSwitch(_ fixture: FixtureCase<ProfileSwitchGiven, ProfileSwitchExpect>) throws {
        let given = fixture.given
        let choice = try given.choice.map { try #require(ProfileChoice(rawValue: $0)) }
        let outcome = ProfileSwitch.apply(
            try given.event.event(), choice: choice, to: try given.registry.registry(),
            newProfileID: try #require(AwradID(given.newProfileID)))
        // A merge runs over the two profiles' data when the case gives it.
        var mergedData: MergedDataShape?
        if let data = given.mergeData, outcome.merge != nil {
            var account = try data.account.state()
            SyncRules.merge(try data.anonymous.state(), into: &account)
            mergedData = try MergedDataShape(account, given: data)
        }
        #expect(
            ProfileSwitchExpect(outcome, mergedData: mergedData) == fixture.expect, "\(fixture.id): \(fixture.summary)")
    }
}

/// The sync directory is covered: every file is a rule iOS runs, or one only the server runs.
@Suite("sync fixture coverage")
struct SyncFixtureCoverageTests {
    @Test func everyFileIsRunOrServerOnly() throws {
        let files = try FixtureLoader.ruleFiles(model: "sync")
        #expect(files == (SyncRule.allCases.map(\.rawValue) + SyncRule.serverOnly).sorted())
    }

    @Test(arguments: SyncRule.allCases)
    func everyRuleHasCases(_ rule: SyncRule) throws {
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: rule.fixtureFile()))
        let count = ((object as? [String: Any])?["cases"] as? [Any])?.count ?? 0
        #expect(count > 0, "\(rule.rawValue) has no cases")
    }
}
