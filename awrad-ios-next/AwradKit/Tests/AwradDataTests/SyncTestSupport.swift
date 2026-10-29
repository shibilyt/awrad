import AwradDomain
import AwradTesting
import Foundation

@testable import AwradData

/// A `LocalProfileStore` in a temporary directory, with the fake account service and a fake server
/// for one account. Timers never fire on their own (`sleep` waits forever), so a test syncs with
/// `syncNow()` and `settle()`.
struct StoreHarness {
    static let email = "amina@example.com"

    let directory: URL
    let account: FakeAccountService
    let accountID: AwradID
    let server: FakeSyncServer
    /// Private audio (slice 3c): the four operations and storage.
    let audio: FakeAudioServer
    let objects: FakeObjectStore
    let store: LocalProfileStore

    /// `signedIn`: whether the account is signed in when the store opens.
    init(signedIn: Bool, serverAccount: AwradID? = nil) async throws {
        directory = FileManager.default.temporaryDirectory.appending(path: "awrad-profiles-\(AwradID.random())")
        account = FakeAccountService()
        accountID = try await account.signIn(email: Self.email, password: "password").id
        if !signedIn { await account.signOut() }
        server = FakeSyncServer(account: serverAccount ?? accountID)
        objects = FakeObjectStore()
        audio = FakeAudioServer(account: serverAccount ?? accountID, objects: objects, sync: server)
        store = try LocalProfileStore(
            directory: directory, account: account, server: server,
            audio: AudioServices(server: audio, objects: objects), deletions: nil,
            now: { Date(timeIntervalSince1970: 1_793_000_000) },
            sleep: { _ in try await Task.sleep(for: .seconds(1_000_000)) })
    }

    /// A recording file outside the profile (as the file picker hands one over), `bytes` long.
    func recordingFile(_ name: String = "recording.mp3", bytes: Int = 4096) throws -> URL {
        let file = directory.deletingLastPathComponent().appending(path: "pick-\(AwradID.random())-\(name)")
        try Data((0..<bytes).map { UInt8(truncatingIfNeeded: $0 &* 31) }).write(to: file)
        return file
    }

    /// Saves a new custom dhikr with a picked recording.
    func saveDhikrWithRecording(_ title: String = "Tasbih", bytes: Int = 4096) async throws -> AwradID {
        let staged = try await store.stageAudio(from: try recordingFile(bytes: bytes))
        return try await store.saveCustomDhikr(id: nil, document: Sample.dhikr(title), audio: .replace(staged))
    }

    /// The custom dhikr's document on the phone.
    func document(_ id: AwradID) async -> CustomDhikrDocument? {
        await store.content().customDhikr(id)?.document
    }

    /// Signs in on the account service and reports it, answering the first-sign-in question.
    func signIn(email: String = StoreHarness.email, choice: ProfileChoice? = nil) async throws -> AwradID {
        let account = try await self.account.signIn(email: email, password: "password")
        let event = ProfileEvent.signIn(accountID: account.id, email: email)
        let prompt = await store.prompt(for: event)
        await store.handle(event, choice: prompt == nil ? nil : choice)
        await store.settle()
        return account.id
    }

    func signOut() async {
        await account.signOut()
        await store.handle(.signOut, choice: nil)
    }

    func sync() async {
        await store.syncNow()
        await store.settle()
    }

    func removeDirectory() {
        try? FileManager.default.removeItem(at: directory)
    }
}

enum Sample {
    static func dhikr(_ title: String, arabic: String = "سُبْحَانَ ٱللَّهِ") -> CustomDhikrDocument {
        CustomDhikrDocument(kind: .dhikr, arabic: arabic, title: LanguageTexts(en: title))
    }

    /// A built-in dhikr's ID (Ayat al-Kursi's, any fixed catalog UUID works).
    static let builtIn = AwradID("6f04f77e-dcb6-4a29-9dc5-fcd3649c2961") ?? .random()
}
