import Foundation
import Testing
@testable import awrad

@MainActor
struct UrgencyPreferenceTests {
    @Test func newPreferencesPersistUrgencyEnabledByDefault() throws {
        let encoded = try JSONEncoder().encode(UserPreferences())
        let object = try #require(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )

        #expect(object["urgencyRemindersEnabled"] as? Bool == true)
    }

    @Test func legacyMissingUrgencyBackingDefaultsToEnabled() throws {
        let preferences = try JSONDecoder().decode(UserPreferences.self, from: Data("{}".utf8))
        #expect(preferences.urgencyRemindersEnabled)
    }

    @Test func urgencyRoundTripsWithoutChangingReminderPreferences() throws {
        let suite = "UrgencyPreferenceTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = AppGroupPreferenceStore(defaults: defaults, storageKey: "urgency")
        var preferences = UserPreferences()
        preferences.dailyReminderEnabled = true
        preferences.reminderHour = 21
        preferences.urgencyRemindersEnabled = false
        try store.save(preferences)

        #expect(try store.load().urgencyRemindersEnabled == false)
        #expect(try store.load().dailyReminderEnabled)
        #expect(try store.load().reminderHour == 21)

        preferences.urgencyRemindersEnabled = true
        try store.save(preferences)
        #expect(try store.load().urgencyRemindersEnabled)
    }
}
