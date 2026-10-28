import AwradDomain
import AwradTesting
import Foundation
import Testing

@testable import FeatureLibrary

/// A custom dhikr's screen: its recording on the device, its tags, delete and conflicts.
struct CustomDhikrDetailTests {
    private let player = FakeDhikrAudioPlayer()
    private let morning = Personal.tag("Morning")

    private func model(
        _ custom: CustomDhikr, library: FakePersonalLibrary, personal: PersonalContent
    ) -> DhikrDetailModel {
        let player = self.player
        return DhikrDetailModel(dhikr: custom.dhikr, library: library, personal: personal) { player }
    }

    private struct Recorded {
        let library: FakePersonalLibrary
        let custom: CustomDhikr
        let personal: PersonalContent
    }

    private func recorded() async throws -> Recorded {
        let library = FakePersonalLibrary(customDhikrs: [])
        let id = try await library.saveCustomDhikr(
            id: nil, document: Personal.document(), audio: .replace(StagedAudio(url: Personal.recording)))
        let personal = await library.content()
        return Recorded(library: library, custom: try #require(personal.customDhikr(id)), personal: personal)
    }

    @Test func aCustomDhikrShowsItsOwnTextAndTags() async {
        let custom = Personal.custom("Glory be", translation: "Subhan Allah")
        let library = FakePersonalLibrary(
            customDhikrs: [custom], tags: [morning], tagsByDhikr: [custom.id: [morning.id]])
        let model = model(custom, library: library, personal: await library.content())
        #expect(model.state.custom == custom)
        #expect(model.state.dhikr.arabic == "سبحان الله")
        #expect(model.state.userTags.map(\.name) == ["Morning"])
        #expect(model.state.audio == .unavailable)
        #expect(model.state.conflicts.isEmpty)
    }

    @Test func theRecordingOnTheDeviceIsFoundAndPlays() async throws {
        let recorded = try await recorded()
        let (library, custom) = (recorded.library, recorded.custom)
        let model = model(custom, library: library, personal: recorded.personal)
        #expect(model.state.audio == .unavailable)
        await model.refreshLocalAudio()
        #expect(model.state.audio == .stopped)
        model.apply(.playPauseTapped)
        #expect(player.calls == [.play(Personal.recording)])
        #expect(model.state.audio == .loading)
        player.emit(.playing(PlaybackPosition(elapsed: .seconds(1))))
        model.apply(.disappeared)
        #expect(player.calls.last == .stop)
    }

    @Test func aRecordingRemovedMeanwhileTakesTheBarAway() async throws {
        let recorded = try await recorded()
        let (library, custom) = (recorded.library, recorded.custom)
        let model = model(custom, library: library, personal: recorded.personal)
        await model.refreshLocalAudio()
        _ = try await library.saveCustomDhikr(id: custom.id, document: Personal.document(), audio: .remove)
        await model.refreshLocalAudio()
        #expect(model.state.audio == .unavailable)
    }

    @Test func editsFromTheLibraryUpdateTheScreen() async throws {
        let custom = Personal.custom("Old")
        let library = FakePersonalLibrary(customDhikrs: [custom])
        let model = model(custom, library: library, personal: await library.content())
        var document = custom.document
        document.title.en = "New"
        _ = try await library.saveCustomDhikr(id: custom.id, document: document)
        model.apply(.personalChanged(await library.content()))
        #expect(model.state.dhikr.title.en == "New")
        #expect(!model.state.isRemoved)
    }

    @Test func deletingAsksFirstThenRemovesTheDhikr() async {
        let custom = Personal.custom()
        let library = FakePersonalLibrary(customDhikrs: [custom])
        let model = model(custom, library: library, personal: await library.content())
        model.apply(.deleteTapped)
        #expect(model.state.isConfirmingDelete)
        model.apply(.deleteDismissed)
        #expect(await library.calls.isEmpty)
        model.apply(.deleteTapped)
        #expect(!model.apply(.deleteConfirmed))
        await model.send(.deleteConfirmed)
        #expect(await library.calls == [.deleteDhikr(custom.id)])
        #expect(model.state.isRemoved)
        #expect(!model.state.isConfirmingDelete)
    }

    @Test func aDhikrDeletedOnAnotherDeviceLeavesTheScreen() async {
        let custom = Personal.custom()
        let library = FakePersonalLibrary(customDhikrs: [custom])
        let model = model(custom, library: library, personal: await library.content())
        model.apply(.personalChanged(PersonalContent()))
        #expect(model.state.isRemoved)
    }

    @Test func aFailedDeleteShowsWhy() async {
        let custom = Personal.custom()
        let library = FakePersonalLibrary(customDhikrs: [custom])
        let model = model(custom, library: library, personal: await library.content())
        await library.fail(with: .storage)
        await model.send(.deleteConfirmed)
        #expect(model.state.failure == .storage)
        #expect(!model.state.isRemoved)
        model.apply(.failureDismissed)
        #expect(model.state.failure == nil)
    }

    @Test func aConflictIsResolvedEitherWay() async {
        let custom = Personal.custom()
        let library = FakePersonalLibrary(customDhikrs: [custom])
        let conflict = Personal.conflict(.customDhikr, custom.id)
        await library.setConflict(conflict)
        let model = model(custom, library: library, personal: await library.content())
        #expect(model.state.conflicts.map(\.key) == [conflict.key])
        await model.send(.resolveConflicts(.keepMine))
        #expect(await library.calls == [.resolve(conflict.key, .keepMine)])
        model.apply(.personalChanged(await library.content()))
        #expect(model.state.conflicts.isEmpty)
    }

    @Test func aBuiltInDhikrHasTagsButNoEditing() async throws {
        let ikhlas = try Personal.catalogDhikr("asma-ul-husna-as-sabur")
        let library = FakePersonalLibrary(
            customDhikrs: [], tags: [morning], tagsByDhikr: [ikhlas.id: [morning.id]])
        let player = self.player
        let model = DhikrDetailModel(dhikr: ikhlas, library: library, personal: await library.content()) { player }
        #expect(model.state.custom == nil)
        #expect(model.state.userTags.map(\.name) == ["Morning"])
        await model.refreshLocalAudio()
        #expect(model.state.audio == .unavailable)
        model.apply(.personalChanged(PersonalContent()))
        #expect(!model.state.isRemoved)
    }
}
