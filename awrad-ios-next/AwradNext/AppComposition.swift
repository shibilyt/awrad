import AwradData
import AwradDomain
import SwiftData

/// Composition root: builds the production adapters for every domain port.
/// Features receive ports, never adapters.
@MainActor
final class AppComposition {
    let onboardingStatus: any OnboardingStatusStore
    let goals: any GoalRepository

    init(onboardingStatus: any OnboardingStatusStore, goals: any GoalRepository) {
        self.onboardingStatus = onboardingStatus
        self.goals = goals
    }

    static func live() -> AppComposition {
        let container: ModelContainer
        do {
            container = try AwradStore.persistent()
        } catch {
            // Can't continue without a store; `persistent()` already recreated it once.
            fatalError("Couldn't open the Awrad store: \(error)")
        }
        return AppComposition(
            onboardingStatus: UserDefaultsOnboardingStatusStore(),
            goals: SwiftDataGoalRepository(modelContainer: container)
        )
    }
}
