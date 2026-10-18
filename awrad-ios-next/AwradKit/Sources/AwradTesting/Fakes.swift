import AwradDomain

// In-memory adapters, one per domain port. Every test target shares these
// instead of hand-rolling its own. Adding a port to AwradDomain means adding
// its fake here.

public actor FakeOnboardingStatusStore: OnboardingStatusStore {
    public private(set) var value: Bool

    public init(onboarded: Bool = false) {
        value = onboarded
    }

    public func isOnboarded() -> Bool { value }
    public func markOnboarded() { value = true }
    public func reset() { value = false }
}

public actor FakeGoalRepository: GoalRepository {
    public private(set) var goals: [Goal] = []

    public init() {}

    public func add(_ goal: Goal) { goals.append(goal) }
    public func count() -> Int { goals.count }
}
