import AwradDomain
import AwradTesting
import Foundation
import Testing

@testable import FeatureLibrary

/// The Library with the user's own dhikrs and tags: search, the tag filter, navigation, notices and
/// conflicts.
struct LibraryPersonalTests {
    private let morning = Personal.tag("Morning")
    private let family = Personal.tag("Family")
    private let glory = Personal.custom("Glory be", translation: "Subhan Allah")
    private let thanks = Personal.custom("Thanks to Allah", arabic: "الحمد لله")

    /// Surah Ikhlas: morning and family. Tahleel: morning. Glory: both. Thanks: family.
    private func model(_ language: CatalogLanguage = .en) async throws -> (LibraryModel, FakePersonalLibrary) {
        let catalog = try DhikrCatalog.bundled()
        let ikhlas = try Personal.catalogDhikr("surah-ikhlas")
        let tahleel = try Personal.catalogDhikr("tahleel")
        let library = FakePersonalLibrary(
            customDhikrs: [glory, thanks], tags: [morning, family],
            tagsByDhikr: [
                ikhlas.id: [morning.id, family.id], tahleel.id: [morning.id], glory.id: [morning.id, family.id],
                thanks.id: [family.id],
            ])
        let model = LibraryModel(catalog: catalog, language: language, library: library)
        model.apply(.personalContentChanged(await library.content()))
        return (model, library)
    }

    @Test func customDhikrsJoinTheListAfterTheCatalog() async throws {
        let (model, _) = try await model()
        let catalog = try DhikrCatalog.bundled()
        #expect(model.state.dhikrs.count == catalog.dhikrs.count + 2)
        #expect(model.state.dhikrs.suffix(2).map(\.key) == [glory.id.description, thanks.id.description])
        #expect(model.state.personal.customDhikrs.count == 2)
    }

    @Test func searchFindsCustomDhikrs() async throws {
        let (model, _) = try await model()
        model.apply(.queryChanged("glory be"))
        #expect(model.state.results?.map(\.key) == [glory.id.description])
        model.apply(.queryChanged("الحمد لله"))
        #expect(model.state.results?.contains { $0.key == thanks.id.description } == true)
        model.apply(.queryChanged("subhan allah"))
        #expect(model.state.results?.contains { $0.key == glory.id.description } == true)
    }

    @Test func searchFollowsNewContent() async throws {
        let (model, _) = try await model()
        model.apply(.queryChanged("Glory be"))
        model.apply(.personalContentChanged(PersonalContent()))
        #expect(model.state.results?.contains { $0.key == glory.id.description } == false)
    }

    @Test func theTagFilterNeedsEveryChosenTagAcrossBuiltInAndCustom() async throws {
        let (model, _) = try await model()
        model.apply(.toggleTagFilter(morning.id))
        let ikhlas = try Personal.catalogDhikr("surah-ikhlas")
        let tahleel = try Personal.catalogDhikr("tahleel")
        #expect(model.state.dhikrs.map(\.id).contains(tahleel.id))
        #expect(Set(model.state.dhikrs.map(\.id)) == [ikhlas.id, tahleel.id, glory.id])
        model.apply(.toggleTagFilter(family.id))
        #expect(Set(model.state.dhikrs.map(\.id)) == [ikhlas.id, glory.id])
        #expect(model.state.isFiltering)
        #expect(Set(model.state.filterTags.map(\.id)) == [morning.id, family.id])
        model.apply(.toggleTagFilter(morning.id))
        #expect(Set(model.state.dhikrs.map(\.id)) == [ikhlas.id, glory.id, thanks.id])
        model.apply(.clearTagFilter)
        #expect(!model.state.isFiltering)
        #expect(model.state.dhikrs.count == (try DhikrCatalog.bundled()).dhikrs.count + 2)
    }

    @Test func theTagFilterAlsoFiltersSearchResults() async throws {
        let (model, _) = try await model()
        model.apply(.queryChanged("allah"))
        let unfiltered = try #require(model.state.results).count
        model.apply(.toggleTagFilter(family.id))
        let filtered = try #require(model.state.results)
        #expect(filtered.count < unfiltered)
        #expect(filtered.allSatisfy { (model.state.personal.tagsByDhikr[$0.id] ?? []).contains(family.id) })
    }

    @Test func aFilterTagThatIsDeletedLeavesTheFilter() async throws {
        let (model, _) = try await model()
        model.apply(.toggleTagFilter(morning.id))
        model.apply(.toggleTagFilter(family.id))
        model.apply(.personalContentChanged(PersonalContent(tags: [family])))
        #expect(model.state.tagFilter == [family.id])
    }

    @Test func aFilterThatMatchesNothingListsNothing() async throws {
        let (model, _) = try await model()
        model.apply(.personalContentChanged(PersonalContent(tags: [morning, family])))
        model.apply(.toggleTagFilter(morning.id))
        #expect(model.state.dhikrs.isEmpty)
    }

    @Test func customKeysResolveLikeCatalogKeys() async throws {
        let (model, _) = try await model()
        let found = model.content.dhikr(glory.id.description, in: model.state.personal)
        #expect(found == glory.dhikr)
        #expect(model.content.dhikr("surah-ikhlas", in: model.state.personal)?.key == "surah-ikhlas")
        #expect(model.content.dhikr(AwradID.random().description, in: model.state.personal) == nil)
        #expect(model.content.dhikr("not-a-dhikr", in: model.state.personal) == nil)
    }

    @Test func newDestinationsPushOntoTheStack() async throws {
        let (model, _) = try await model()
        model.apply(.openYourDhikrs)
        model.apply(.openEditor(nil))
        model.apply(.openEditor(glory.id))
        model.apply(.openManageTags(dhikr: glory.id))
        #expect(
            model.state.path == [.yourDhikrs, .editor(nil), .editor(glory.id), .manageTags(dhikr: glory.id)])
        model.apply(.popToRoot)
        #expect(model.state.path.isEmpty)
    }

    @Test func savingANewDhikrOpensItAndSavingAnEditGoesBack() async throws {
        let (model, _) = try await model()
        model.apply(.openDhikr(key: "tahleel"))
        model.apply(.openEditor(nil))
        model.apply(.editorSaved(glory.id, isNew: true))
        #expect(model.state.path == [.dhikr(key: "tahleel"), .dhikr(key: glory.id.description)])
        model.apply(.openEditor(glory.id))
        model.apply(.editorSaved(glory.id, isNew: false))
        #expect(model.state.path == [.dhikr(key: "tahleel"), .dhikr(key: glory.id.description)])
    }

    @Test func dismissingANoticeAsksTheLibrary() async throws {
        let (model, library) = try await model()
        let notice = SyncNotice(code: .tagNameTaken, key: SyncEntityKey(.userTag, morning.id))
        await library.addNotice(notice)
        model.apply(.personalContentChanged(await library.content()))
        #expect(model.state.personal.notices == [notice])
        #expect(!model.apply(.dismissNotice(notice)))
        await model.send(.dismissNotice(notice))
        #expect(await library.calls.last == .dismiss(notice))
        model.apply(.personalContentChanged(await library.content()))
        #expect(model.state.personal.notices.isEmpty)
    }

    @Test func resolvingAConflictAsksTheLibrary() async throws {
        let (model, library) = try await model()
        let conflict = Personal.conflict(.customDhikr, glory.id)
        await library.setConflict(conflict)
        model.apply(.personalContentChanged(await library.content()))
        #expect(model.state.personal.conflicts(about: glory.id).count == 1)
        await model.send(.resolveConflict(conflict.key, .useTheirs))
        #expect(await library.calls.last == .resolve(conflict.key, .useTheirs))
        model.apply(.personalContentChanged(await library.content()))
        #expect(model.state.personal.conflicts.isEmpty)
    }

    @Test func followingTheLibraryKeepsTheContentCurrent() async throws {
        let (model, library) = try await model()
        let task = Task { await model.observePersonalLibrary() }
        defer { task.cancel() }
        let created = try await library.createTag(named: "Evening")
        for _ in 0..<1000 where model.state.personal.tag(created.id) == nil { await Task.yield() }
        #expect(model.state.personal.tag(created.id)?.name == "Evening")
    }
}
