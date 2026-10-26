import AwradData
import AwradDomain
import Foundation
import Testing

struct SwiftDataGoalRepositoryTests {
    @Test func addedGoalsAreStored() async throws {
        let repository = SwiftDataGoalRepository(modelContainer: try AwradStore.inMemory())
        let goal = try Goal(
            id: .random(),
            dhikrCatalogKey: "isthighfar",
            schedule: .everyDay,
            activePeriod: ActivePeriod(start: try #require(CalendarDay("2026-10-17"))),
            countPolicy: CountPolicy(target: 70, streakThreshold: .target),
            requirement: .perDueDate
        )

        try await repository.add(goal)

        #expect(try await repository.count() == 1)
    }
}

struct UserDefaultsOnboardingStatusStoreTests {
    @Test func marksAndResetsOnboarding() async {
        let store = UserDefaultsOnboardingStatusStore(suiteName: "awrad.tests.\(UUID().uuidString)")

        #expect(await !store.isOnboarded())
        await store.markOnboarded()
        #expect(await store.isOnboarded())
        await store.reset()
        #expect(await !store.isOnboarded())
    }
}

struct DeviceNameTests {
    @Test func knownModelsGetTheirMarketingName() {
        #expect(DeviceName.readable(modelIdentifier: "iPhone17,1", family: "iPhone") == "iPhone 16 Pro")
        #expect(DeviceName.readable(modelIdentifier: "iPad16,3", family: "iPad") == "iPad Pro 11-inch (M4)")
    }

    @Test func unknownModelsKeepTheirFamilyAndIdentifier() {
        #expect(DeviceName.readable(modelIdentifier: "iPhone99,9", family: "iPhone") == "iPhone (iPhone99,9)")
        #expect(DeviceName.readable(modelIdentifier: "", family: "iPad") == "iPad")
    }

    @Test @MainActor func thisDeviceHasARealName() {
        let name = DeviceName.current()
        #expect(!name.isEmpty && name.count <= DeviceName.maximumLength)
        #expect(name != "Apple device")
    }
}

struct InstallationMarkerTests {
    @Test func marksOnce() {
        let marker = UserDefaultsInstallationMarker(suiteName: "awrad.tests.\(UUID().uuidString)")
        #expect(!marker.isMarked())
        marker.mark()
        #expect(marker.isMarked())
    }
}
