import AwradDomain
import Foundation
import Testing

/// contracts/practice-settings/v1 "Syncing the policy": a rejected policy is never removed from the
/// phone.
@Suite("practice policy rejection")
struct PracticePolicyRejectionTests {
    private let account = AwradID.random()
    private let mine = PracticePolicy(
        dayReset: .maghrib, calculationMethod: .dubai, madhab: .shafi, weekStart: .monday, hijriCorrections: .none)
    private let theirs = PracticePolicy(
        dayReset: .midnight, calculationMethod: .muslimWorldLeague, madhab: .hanafi, weekStart: .sunday,
        hijriCorrections: .none)

    private func rejected(current: ServerCopy?) -> (InMemorySyncState, SyncEntityKey) {
        let key = SyncEntityKey(.practicePolicy, account)
        let command = OutboxCommand(
            commandID: .random(), key: key, op: .put, baseVersion: 2, document: .practicePolicy(mine), sent: true)
        var state = InMemorySyncState(
            documents: [key: .practicePolicy(mine)], knownVersions: [key: 2],
            baseDocuments: [key: .practicePolicy(theirs)], outbox: [command])
        let receipt = SyncReceipt.rejected(
            commandID: command.commandID, code: .documentInvalid, fields: [], current: current)
        SyncRules.apply([receipt], to: &state)
        return (state, key)
    }

    @Test func aRejectionWithTheServersCopyTakesIt() {
        let copy = ServerCopy(version: 5, state: .active, document: .practicePolicy(theirs))
        let (state, key) = rejected(current: copy)
        #expect(state.document(key) == .practicePolicy(theirs))
        #expect(state.knownVersion(key) == 5)
        #expect(state.baseDocument(key) == .practicePolicy(theirs))
    }

    @Test func aRejectionWithoutACopyKeepsTheDocumentAtVersionZeroOnTheDefaultBase() {
        let (state, key) = rejected(current: nil)
        #expect(state.document(key) == .practicePolicy(mine))
        #expect(state.knownVersion(key) == 0)
        #expect(state.baseDocument(key) == nil, "no base means the default policy")
        #expect(state.outbox.isEmpty)
    }
}
