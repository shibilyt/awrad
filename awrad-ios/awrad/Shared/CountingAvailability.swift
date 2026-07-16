import Foundation

enum CountingAvailabilityReason: String, Codable, CaseIterable, Hashable {
    case futureStart
    case offRecurrence
    case slotUpcoming
    case slotEnded
    case slotTimingUnavailable
}

enum CountingHardBlockReason: String, Codable, Equatable {
    case paused
    case completed
    case expired
    case durationEnded
}

struct CountingAvailabilityConfirmationKey: Codable, Hashable {
    var goalID: UUID
    var slotID: UUID?
    var effectiveDateKey: String
    var reasons: Set<CountingAvailabilityReason>

    var persistedValue: String {
        [
            effectiveDateKey,
            goalID.uuidString.lowercased(),
            slotID?.uuidString.lowercased() ?? "none",
            reasons.map(\.rawValue).sorted().joined(separator: ","),
        ].joined(separator: ":")
    }
}

enum CountingAvailabilityDecision: Equatable {
    case allow
    case requiresConfirmation(
        reasons: Set<CountingAvailabilityReason>,
        key: CountingAvailabilityConfirmationKey
    )
    case hardBlock(CountingHardBlockReason)
}

enum CountingAvailabilityConfirmationStore {
    static let appGroupID = "group.app.awrad.awrad"
    private static let storageKey = "counting_availability_confirmations"

    static func isConfirmed(
        _ key: CountingAvailabilityConfirmationKey,
        defaults: UserDefaults? = UserDefaults(suiteName: appGroupID)
    ) -> Bool {
        guard let defaults else { return false }
        let prefix = "\(key.effectiveDateKey):"
        let stored = defaults.stringArray(forKey: storageKey) ?? []
        let current = stored.filter { $0.hasPrefix(prefix) }
        if current.count != stored.count {
            defaults.set(current.sorted(), forKey: storageKey)
        }
        return Set(current).contains(key.persistedValue)
    }

    static func confirm(
        _ key: CountingAvailabilityConfirmationKey,
        defaults: UserDefaults? = UserDefaults(suiteName: appGroupID)
    ) {
        guard let defaults else { return }
        let prefix = "\(key.effectiveDateKey):"
        var confirmations = Set(
            (defaults.stringArray(forKey: storageKey) ?? []).filter { $0.hasPrefix(prefix) }
        )
        confirmations.insert(key.persistedValue)
        defaults.set(confirmations.sorted(), forKey: storageKey)
    }
}
