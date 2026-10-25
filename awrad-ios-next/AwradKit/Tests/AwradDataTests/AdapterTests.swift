import AwradData
import AwradDomain
import Foundation
import Testing

struct SwiftDataGoalRepositoryTests {
    @Test func addedGoalsAreStored() async throws {
        let repository = SwiftDataGoalRepository(modelContainer: try AwradStore.inMemory())
        let goal = Goal(
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
