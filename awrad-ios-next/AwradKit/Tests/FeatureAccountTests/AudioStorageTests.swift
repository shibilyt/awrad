import AwradDomain
import AwradTesting
import Foundation
import Testing

@testable import FeatureAccount

/// Slice 3c: the Sync card's "Audio storage: 120 MB of 500 MB", from the usage the profiles report.
@MainActor
struct AudioStorageTests {
    @Test func theStorageIsInDecimalMegabytes() {
        let usage = AudioUsage(usedBytes: 120_482_733, limitBytes: 500_000_000)
        let english = Locale(identifier: "en_US")
        #expect(ProfileStrings.audioStorage(usage, locale: english).key == "account.sync.audio_storage %@ %@")
        #expect(AudioUsage.megabytes(usage.usedBytes, locale: english) == "120 MB")
        #expect(AudioUsage.megabytes(usage.limitBytes, locale: english) == "500 MB")
        #expect(AudioUsage.megabytes(499_999_999, locale: english) == "499 MB", "never reads full before it is")
    }

    @Test func theSettingsFollowTheStorage() async {
        let profiles = FakeLocalProfiles()
        let model = AccountModel(service: FakeAccountService(), profiles: profiles, now: { .now })
        let observing = Task { await model.observeProfiles() }
        await eventually { model.state.profiles != nil }
        #expect(model.state.profiles?.audioUsage == nil, "nothing shown until the server says")

        let usage = AudioUsage(usedBytes: 120_482_733, limitBytes: 500_000_000)
        await profiles.set(ProfilesState(registry: .fresh(), syncStatus: .syncing, audioUsage: usage))
        await eventually { model.state.profiles?.audioUsage == usage }
        #expect(model.state.profiles?.audioUsage == usage)
        observing.cancel()
    }

    /// Waits for something the profiles' stream delivers.
    private func eventually(_ condition: () -> Bool) async {
        for _ in 0..<400 where !condition() { try? await Task.sleep(for: .milliseconds(5)) }
    }
}
