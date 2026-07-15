import Foundation

/// A process-safe projection. It contains only stable identity and rendering
/// values needed by WidgetKit; it is never an authority for devotional data.
struct PersistenceWidgetSnapshot: Codable, Hashable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int = currentSchemaVersion
    var revision: Int
    var generatedAt: Date
    /// The instant at which `todayKey` stops being authoritative. Widget/App
    /// Intent code must fail closed after this boundary until the app publishes
    /// a new projection.
    var effectiveDateValidUntil: Date? = nil
    var todayKey: String
    var languageCode: String
    var focus: Focus?
    var wird: WirdProgress?

    struct Focus: Codable, Hashable {
        var goalID: AwradID
        var slotID: AwradID
        var title: String
        var symbol: String
        var count: Int64
        var target: Int64?
        var canIncrement: Bool
        /// Detects a projection left behind by an interrupted app commit.
        var goalUpdatedAt: Date? = nil
        var slotType: String? = nil
        var slotCountingPolicy: String? = nil
        /// Absolute interval is projected because prayer calculation remains
        /// app-owned. The extension still validates goal/slot records live.
        var slotWindowStart: Date? = nil
        var slotWindowEnd: Date? = nil
    }

    struct WirdProgress: Codable, Hashable {
        var wirdID: AwradID
        var partID: AwradID
        var occasionKey: String
        var title: String
        var completedItems: Int
        var totalItems: Int
    }
}

extension PersistenceWidgetSnapshot {
    static func effectiveDateValidityEnd(
        todayKey: String,
        preferences: UserPreferences,
        now: Date,
        calendar inputCalendar: Calendar = .current,
        timeZone: TimeZone = .current,
        prayerTimeService: PrayerTimeService = PrayerTimeService()
    ) -> Date? {
        var calendar = inputCalendar
        calendar.timeZone = timeZone
        guard let occurrenceDate = date(from: todayKey, calendar: calendar) else { return nil }

        if preferences.dayReset == .maghrib,
           let maghrib = prayerTimeService.summary(
                for: occurrenceDate,
                latitude: preferences.latitude,
                longitude: preferences.longitude,
                method: preferences.calculationMethod,
                madhab: preferences.madhab,
                calendar: calendar,
                timeZone: timeZone
           )?.maghrib {
            // If this occurrence's boundary has passed, `todayKey` was not
            // refreshed before projection. Fail closed instead of extending a
            // stale key to midnight.
            return maghrib > now ? maghrib : nil
        }

        let nextMidnight = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: now)
        )
        return nextMidnight.flatMap { $0 > now ? $0 : nil }
    }

    static func slotTiming(
        for slot: GoalSlot,
        todayKey: String,
        preferences: UserPreferences,
        now: Date
    ) -> SlotTimingResolution {
        SlotStatusCalculator.timing(
            for: slot,
            occurrenceDateKey: todayKey,
            preferences: preferences,
            now: now
        )
    }

    private static func date(from dateKey: String, calendar: Calendar) -> Date? {
        let parts = dateKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: parts[0],
            month: parts[1],
            day: parts[2]
        ))
    }
}

@MainActor
final class PersistenceWidgetSnapshotStore {
    nonisolated static let storageKey = "AwradPersistenceWidgetSnapshot.v1"

    private let defaults: UserDefaults
    private let storageKey: String

    init(defaults: UserDefaults, storageKey: String = PersistenceWidgetSnapshotStore.storageKey) {
        self.defaults = defaults
        self.storageKey = storageKey
    }

    convenience init(
        appGroupID: String = AwradPersistenceContainerFactory.appGroupID,
        storageKey: String = PersistenceWidgetSnapshotStore.storageKey
    ) throws {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            throw AwradPersistenceError.appGroupUnavailable(appGroupID)
        }
        self.init(defaults: defaults, storageKey: storageKey)
    }

    func load() throws -> PersistenceWidgetSnapshot? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        do {
            let snapshot = try Self.decoder.decode(PersistenceWidgetSnapshot.self, from: data)
            guard snapshot.schemaVersion == PersistenceWidgetSnapshot.currentSchemaVersion else {
                throw AwradPersistenceError.corruptRecord(
                    entity: "widget snapshot",
                    id: storageKey,
                    field: "schema version"
                )
            }
            return snapshot
        } catch let error as AwradPersistenceError {
            throw error
        } catch {
            throw AwradPersistenceError.corruptRecord(entity: "widget snapshot", id: storageKey, field: "payload")
        }
    }

    func save(_ snapshot: PersistenceWidgetSnapshot) throws {
        guard snapshot.schemaVersion == PersistenceWidgetSnapshot.currentSchemaVersion else {
            throw AwradPersistenceError.corruptRecord(
                entity: "widget snapshot",
                id: storageKey,
                field: "schema version"
            )
        }
        defaults.set(try Self.encoder.encode(snapshot), forKey: storageKey)
    }

    func reset() {
        defaults.removeObject(forKey: storageKey)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }()
}
