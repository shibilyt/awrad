import AVFoundation
import CoreLocation
import Foundation
import MediaPlayer
import Observation
import UserNotifications

@Observable
@MainActor
final class AppServices {
    let notifications: NotificationService
    let prayerTimes: PrayerTimeService
    let locations: LocationService
    let audio: AudioSessionService
    let auth: AuthService
    let persistence: AwradPersistenceRuntime?
    let persistenceInitializationError: String?

    init(
        notifications: NotificationService? = nil,
        prayerTimes: PrayerTimeService? = nil,
        locations: LocationService? = nil,
        audio: AudioSessionService? = nil,
        auth: AuthService? = nil,
        persistence: AwradPersistenceRuntime? = nil
    ) {
        self.notifications = notifications ?? NotificationService()
        self.prayerTimes = prayerTimes ?? PrayerTimeService()
        self.locations = locations ?? LocationService()
        self.audio = audio ?? AudioSessionService()
        self.auth = auth ?? AuthService()
        if let persistence {
            self.persistence = persistence
            self.persistenceInitializationError = nil
        } else {
            do {
                self.persistence = try AwradPersistenceRuntime()
                self.persistenceInitializationError = nil
            } catch {
                self.persistence = nil
                self.persistenceInitializationError = error.localizedDescription
            }
        }
    }

    /// Reschedules (or clears) a wird's reminders, resolving prayer-offset times from the
    /// user's current location/method.
    @discardableResult
    func rescheduleWirdReminders(for wird: Wird, store: AwradStore) async -> NotificationSchedulingResult {
        let language = store.preferences.appLanguage
        let summary = prayerTimes.summary(
            for: Date(),
            latitude: store.preferences.latitude,
            longitude: store.preferences.longitude,
            method: store.preferences.calculationMethod,
            madhab: store.preferences.madhab
        )
        return await notifications.scheduleWirdReminders(for: wird, language: language, prayerTimes: summary)
    }

    @discardableResult
    func cancelWirdReminders(wirdID: AwradID) async -> NotificationSchedulingResult {
        await notifications.cancelWirdReminders(wirdID: wirdID)
    }
}

@MainActor
protocol AwradUserNotificationCenter: AnyObject {
    func awradAuthorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func pendingNotificationRequests() async -> [UNNotificationRequest]
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
}

extension UNUserNotificationCenter: AwradUserNotificationCenter {
    func awradAuthorizationStatus() async -> UNAuthorizationStatus {
        await notificationSettings().authorizationStatus
    }
}

enum NotificationAuthorizationRequestResult: Equatable {
    case authorized
    case denied
    case failed(String)
}

enum NotificationSchedulingResult: Equatable {
    case scheduled(count: Int)
    case cleared
    case denied
    case failed(String)

    var succeeded: Bool {
        switch self {
        case .scheduled, .cleared: true
        case .denied, .failed: false
        }
    }

    func localizedFailureMessage(language: AppLanguage) -> String? {
        switch self {
        case .scheduled, .cleared:
            nil
        case .denied:
            AwradLocalizer.localized(
                "Notifications are disabled. Enable them in Settings, then try again.",
                language: language
            )
        case .failed:
            AwradLocalizer.localized(
                "Some reminders could not be scheduled. Try again.",
                language: language
            )
        }
    }

    static func combined(_ results: [NotificationSchedulingResult]) -> NotificationSchedulingResult {
        if let failure = results.first(where: {
            if case .failed = $0 { return true }
            return false
        }) {
            return failure
        }
        if results.contains(.denied) { return .denied }
        let count = results.reduce(into: 0) { partial, result in
            if case .scheduled(let scheduled) = result { partial += scheduled }
        }
        return count > 0 ? .scheduled(count: count) : .cleared
    }
}

@MainActor
final class NotificationService {
    private let center: any AwradUserNotificationCenter

    init(center: any AwradUserNotificationCenter = UNUserNotificationCenter.current()) {
        self.center = center
    }

    @discardableResult
    func requestAuthorizationIfUseful() async -> NotificationAuthorizationRequestResult {
        switch await center.awradAuthorizationStatus() {
        case .authorized, .provisional, .ephemeral:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            do {
                guard try await center.requestAuthorization(options: [.alert, .badge, .sound]) else {
                    return .denied
                }
                return [.authorized, .provisional, .ephemeral].contains(await center.awradAuthorizationStatus())
                    ? .authorized
                    : .denied
            } catch {
                return .failed(error.localizedDescription)
            }
        @unknown default:
            return .denied
        }
    }

    func authorizationState() async -> NotificationAuthorizationState {
        NotificationAuthorizationState(centerStatus: await center.awradAuthorizationStatus())
    }

    @discardableResult
    func scheduleDailyReminder(hour: Int, minute: Int, language: AppLanguage = .english) async -> NotificationSchedulingResult {
        await schedule(
            [ReminderPlanner.dailyReminder(hour: hour, minute: minute, language: language)],
            replacingIdentifiers: [ReminderPlanner.dailyReminderIdentifier]
        )
    }

    @discardableResult
    func cancelDailyReminder() -> NotificationSchedulingResult {
        center.removePendingNotificationRequests(withIdentifiers: [ReminderPlanner.dailyReminderIdentifier])
        return .cleared
    }

    @discardableResult
    func scheduleDailyRemembrance(language: AppLanguage = .english) async -> NotificationSchedulingResult {
        await schedule(
            [ReminderPlanner.dailyRemembrance(language: language)],
            replacingIdentifiers: [ReminderPlanner.dailyRemembranceIdentifier]
        )
    }

    @discardableResult
    func cancelDailyRemembrance() -> NotificationSchedulingResult {
        center.removePendingNotificationRequests(withIdentifiers: [ReminderPlanner.dailyRemembranceIdentifier])
        return .cleared
    }

    @discardableResult
    func scheduleGoalReminders(
        for goal: Goal,
        dhikrTitle: String,
        language: AppLanguage = .english,
        prayerTimes: [PrayerTimesSummary] = [],
        now: Date = Date(),
        calendar: Calendar = .current
    ) async -> NotificationSchedulingResult {
        guard goal.isActive else {
            return await cancelGoalReminders(goalID: goal.id)
        }

        let planned = ReminderPlanner.goalReminders(
            for: goal,
            dhikrTitle: dhikrTitle,
            language: language,
            prayerTimes: prayerTimes,
            now: now,
            calendar: calendar
        )
        return await replaceGoalReminders(goalID: goal.id, with: planned)
    }

    @discardableResult
    func refreshScheduledReminders(
        goalInputs: [GoalReminderScheduleInput],
        dailyReminder: (enabled: Bool, hour: Int, minute: Int, language: AppLanguage),
        dailyRemembrance: (enabled: Bool, language: AppLanguage),
        wirdInputs: [WirdReminderScheduleInput],
        now: Date = Date(),
        calendar: Calendar = .current
    ) async -> NotificationSchedulingResult {
        var results: [NotificationSchedulingResult] = []
        if dailyReminder.enabled {
            results.append(await scheduleDailyReminder(
                hour: dailyReminder.hour,
                minute: dailyReminder.minute,
                language: dailyReminder.language
            ))
        } else {
            results.append(cancelDailyReminder())
        }

        if dailyRemembrance.enabled {
            results.append(await scheduleDailyRemembrance(language: dailyRemembrance.language))
        } else {
            results.append(cancelDailyRemembrance())
        }

        let existingGoalIdentifiers = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(ReminderPlanner.goalReminderIdentifierRoot) }
        let plannedGoals = goalInputs
            .filter { $0.goal.isActive && $0.goal.reminders.contains(where: \.enabled) }
            .flatMap { input in
                ReminderPlanner.goalReminders(
                for: input.goal,
                dhikrTitle: input.dhikrTitle,
                language: input.language,
                prayerTimes: input.prayerTimes,
                now: now,
                calendar: calendar
            )
            }
        results.append(await schedule(plannedGoals, replacingIdentifiers: existingGoalIdentifiers))

        let existingWirdIdentifiers = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(ReminderPlanner.wirdReminderIdentifierRoot) }
        let plannedWirds = wirdInputs.flatMap { input in
            ReminderPlanner.wirdReminders(
                for: input.wird,
                language: input.language,
                prayerTimes: input.prayerTimes,
                calendar: calendar
            )
        }
        results.append(await schedule(plannedWirds, replacingIdentifiers: existingWirdIdentifiers))
        return .combined(results)
    }

    @discardableResult
    func cancelGoalReminders(goalID: AwradID) async -> NotificationSchedulingResult {
        let prefix = ReminderPlanner.goalReminderIdentifierPrefix(for: goalID)
        let identifiers = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        return .cleared
    }

    @discardableResult
    func cancelAllGoalReminders() async -> NotificationSchedulingResult {
        let identifiers = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(ReminderPlanner.goalReminderIdentifierRoot) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        return .cleared
    }

    @discardableResult
    func scheduleWirdReminders(
        for wird: Wird,
        language: AppLanguage = .english,
        prayerTimes: PrayerTimesSummary? = nil
    ) async -> NotificationSchedulingResult {
        let planned = ReminderPlanner.wirdReminders(for: wird, language: language, prayerTimes: prayerTimes)
        return await replaceWirdReminders(wirdID: wird.id, with: planned)
    }

    @discardableResult
    func cancelWirdReminders(wirdID: AwradID) async -> NotificationSchedulingResult {
        let prefix = ReminderPlanner.wirdReminderIdentifierPrefix(for: wirdID)
        let identifiers = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        return .cleared
    }

    private func replaceWirdReminders(wirdID: AwradID, with notifications: [PlannedNotification]) async -> NotificationSchedulingResult {
        let prefix = ReminderPlanner.wirdReminderIdentifierPrefix(for: wirdID)
        let existing = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(prefix) }
        return await schedule(notifications, replacingIdentifiers: existing)
    }

    #if DEBUG
    @discardableResult
    func deliverDebugNotificationNow(title: String = "Awrad", body: String) async -> Bool {
        await addDebugNotification(
            identifier: "awrad.debug.now.\(UUID().uuidString)",
            title: title,
            body: body,
            trigger: nil
        )
    }

    @discardableResult
    func scheduleDebugNotification(after seconds: TimeInterval, title: String = "Awrad", body: String) async -> Bool {
        await addDebugNotification(
            identifier: "awrad.debug.scheduled.\(UUID().uuidString)",
            title: title,
            body: body,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(seconds, 1), repeats: false)
        )
    }
    #endif

    private func replaceGoalReminders(goalID: AwradID, with notifications: [PlannedNotification]) async -> NotificationSchedulingResult {
        let prefix = ReminderPlanner.goalReminderIdentifierPrefix(for: goalID)
        let existing = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(prefix) }
        return await schedule(notifications, replacingIdentifiers: existing)
    }

    private func schedule(
        _ notifications: [PlannedNotification],
        replacingIdentifiers identifiers: [String]
    ) async -> NotificationSchedulingResult {
        guard !notifications.isEmpty else {
            if !identifiers.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: identifiers)
            }
            return .cleared
        }

        switch await requestAuthorizationIfUseful() {
        case .authorized:
            break
        case .denied:
            return .denied
        case .failed(let message):
            return .failed(message)
        }

        let existingIdentifiers = Set(identifiers)
        let requestedIdentifiers = notifications.map(\.identifier)
        guard Set(requestedIdentifiers).count == requestedIdentifiers.count else {
            return .failed("Duplicate notification identifiers")
        }
        let existingRequests = await center.pendingNotificationRequests()
        let originalsByIdentifier = Dictionary(uniqueKeysWithValues: existingRequests.compactMap { request in
            existingIdentifiers.contains(request.identifier) ? (request.identifier, request) : nil
        })
        var newlyAddedIdentifiers: [String] = []
        var overwrittenOriginals: [UNNotificationRequest] = []
        for notification in notifications {
            let content = UNMutableNotificationContent()
            content.title = notification.title
            content.body = notification.body
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: notification.dateComponents,
                repeats: notification.repeats
            )
            let request = UNNotificationRequest(
                identifier: notification.identifier,
                content: content,
                trigger: trigger
            )
            do {
                try await center.add(request)
                if !existingIdentifiers.contains(notification.identifier) {
                    newlyAddedIdentifiers.append(notification.identifier)
                } else if let original = originalsByIdentifier[notification.identifier] {
                    overwrittenOriginals.append(original)
                }
            } catch {
                if !newlyAddedIdentifiers.isEmpty {
                    center.removePendingNotificationRequests(withIdentifiers: newlyAddedIdentifiers)
                }
                var rollbackError: Error?
                for original in overwrittenOriginals {
                    do {
                        try await center.add(original)
                    } catch {
                        rollbackError = error
                    }
                }
                let message = if let rollbackError {
                    "\(error.localizedDescription) (rollback: \(rollbackError.localizedDescription))"
                } else {
                    error.localizedDescription
                }
                return .failed(message)
            }
        }

        let staleIdentifiers = existingIdentifiers.subtracting(Set(requestedIdentifiers))
        if !staleIdentifiers.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: Array(staleIdentifiers))
        }
        return .scheduled(count: notifications.count)
    }

    #if DEBUG
    private func addDebugNotification(
        identifier: String,
        title: String,
        body: String,
        trigger: UNNotificationTrigger?
    ) async -> Bool {
        guard case .authorized = await requestAuthorizationIfUseful() else {
            return false
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        do {
            try await center.add(request)
            return true
        } catch {
            return false
        }
    }
    #endif
}

enum NotificationAuthorizationState: String, Equatable {
    case notDetermined
    case denied
    case authorized

    init(centerStatus: UNAuthorizationStatus) {
        switch centerStatus {
        case .notDetermined:
            self = .notDetermined
        case .denied:
            self = .denied
        case .authorized, .provisional, .ephemeral:
            self = .authorized
        @unknown default:
            self = .denied
        }
    }
}

struct GoalReminderScheduleInput {
    var goal: Goal
    var dhikrTitle: String
    var language: AppLanguage
    var prayerTimes: [PrayerTimesSummary]
}

struct WirdReminderScheduleInput {
    var wird: Wird
    var language: AppLanguage
    var prayerTimes: PrayerTimesSummary?
}

struct PlannedNotification: Equatable {
    var identifier: String
    var title: String
    var body: String
    var dateComponents: DateComponents
    var repeats: Bool
}

enum ReminderPlanner {
    static let dailyReminderIdentifier = "awrad.daily-reminder"
    static let dailyRemembranceIdentifier = "awrad.daily-remembrance"
    static let goalReminderIdentifierRoot = "awrad.goal."

    static func dailyReminder(hour: Int, minute: Int, language: AppLanguage = .english) -> PlannedNotification {
        var components = DateComponents()
        components.hour = hour.clamped(to: 0...23)
        components.minute = minute.clamped(to: 0...59)

        return PlannedNotification(
            identifier: dailyReminderIdentifier,
            title: "Awrad",
            body: AwradLocalizer.localized("Your daily remembrance is ready.", language: language),
            dateComponents: components,
            repeats: true
        )
    }

    static func dailyRemembrance(language: AppLanguage = .english) -> PlannedNotification {
        var components = DateComponents()
        components.hour = 9
        components.minute = 0

        return PlannedNotification(
            identifier: dailyRemembranceIdentifier,
            title: AwradLocalizer.localized("Daily remembrance", language: language),
            body: AwradLocalizer.localized("Take a moment to remember Allah.", language: language),
            dateComponents: components,
            repeats: true
        )
    }

    static func goalReminders(
        for goal: Goal,
        dhikrTitle: String,
        language: AppLanguage = .english,
        prayerTimes: [PrayerTimesSummary] = [],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [PlannedNotification] {
        guard goal.isActive else { return [] }

        let slotsByID = Dictionary(uniqueKeysWithValues: goal.slots.map { ($0.id, $0) })
        return goal.reminders
            .filter(\.enabled)
            .sorted { $0.sortOrder < $1.sortOrder }
            .flatMap { reminder in
                plannedNotifications(
                    for: reminder,
                    goal: goal,
                    dhikrTitle: dhikrTitle,
                    language: language,
                    slotsByID: slotsByID,
                    prayerTimes: prayerTimes,
                    now: now,
                    calendar: calendar
                )
            }
    }

    static func goalReminderIdentifierPrefix(for goalID: AwradID) -> String {
        "\(goalReminderIdentifierRoot)\(goalID.uuidString)."
    }

    static let wirdReminderIdentifierRoot = "awrad.wird."

    static func wirdReminderIdentifierPrefix(for wirdID: AwradID) -> String {
        "\(wirdReminderIdentifierRoot)\(wirdID.uuidString)."
    }

    /// Daily-repeating reminders for a wird. Prayer-offset reminders resolve to a clock time
    /// from the supplied prayer times (today's), falling back to 7:00 when unavailable.
    static func wirdReminders(
        for wird: Wird,
        language: AppLanguage = .english,
        prayerTimes: PrayerTimesSummary? = nil,
        calendar: Calendar = .current
    ) -> [PlannedNotification] {
        let title = wird.displayName(language: language)
        return wird.reminders.filter(\.enabled).map { reminder in
            var components = DateComponents()
            switch reminder.reminderType {
            case .prayerOffset:
                if let prayerTimes,
                   let prayer = reminder.prayer,
                   let base = prayerDate(for: prayer, in: prayerTimes),
                   let fire = calendar.date(byAdding: .minute, value: reminder.offsetMinutes ?? 0, to: base) {
                    let resolved = calendar.dateComponents([.hour, .minute], from: fire)
                    components.hour = resolved.hour
                    components.minute = resolved.minute
                } else {
                    components.hour = 7
                    components.minute = 0
                }
            default:
                components.hour = (reminder.hour ?? 7).clamped(to: 0...23)
                components.minute = (reminder.minute ?? 0).clamped(to: 0...59)
            }
            return PlannedNotification(
                identifier: "\(wirdReminderIdentifierPrefix(for: wird.id))\(reminder.id.uuidString)",
                title: title,
                body: AwradLocalizer.format("Time for %@.", language: language, title),
                dateComponents: components,
                repeats: true
            )
        }
    }

    private static func plannedNotifications(
        for reminder: GoalReminder,
        goal: Goal,
        dhikrTitle: String,
        language: AppLanguage,
        slotsByID: [AwradID: GoalSlot],
        prayerTimes: [PrayerTimesSummary],
        now: Date,
        calendar: Calendar
    ) -> [PlannedNotification] {
        switch reminder.reminderType {
        case .fixedTime:
            let hour = (reminder.hour ?? 8).clamped(to: 0...23)
            let minute = (reminder.minute ?? 0).clamped(to: 0...59)
            return candidateScheduleDates(now: now, calendar: calendar).compactMap { day in
                let dateKey = dateKey(for: day, calendar: calendar)
                guard GoalProgressCalculator.isDue(goal, on: dateKey),
                      let fireDate = fireDate(on: day, hour: hour, minute: minute, calendar: calendar),
                      fireDate > now else {
                    return nil
                }
                return PlannedNotification(
                    identifier: identifier(goalID: goal.id, reminderID: reminder.id, dateKey: dateKey),
                    title: dhikrTitle,
                    body: AwradLocalizer.format("Time for your %@ goal.", language: language, dhikrTitle),
                    dateComponents: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate),
                    repeats: false
                )
            }
        case .prayerOffset:
            guard let slotID = reminder.slotID,
                  let slot = slotsByID[slotID],
                  let prayer = slot.prayerName else {
                return []
            }

            let offset = reminder.offsetMinutes ?? 0
            return prayerTimes.compactMap { summary in
                let dateKey = dateKey(for: summary.date, calendar: calendar)
                guard GoalProgressCalculator.isDue(goal, on: dateKey),
                      let prayerDate = prayerDate(for: prayer, in: summary),
                      let fireDate = calendar.date(byAdding: .minute, value: offset, to: prayerDate),
                      fireDate > now else {
                    return nil
                }

                let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
                return PlannedNotification(
                    identifier: identifier(goalID: goal.id, reminderID: reminder.id, dateKey: dateKey),
                    title: dhikrTitle,
                    body: AwradLocalizer.format("%@: %@", language: language, slot.displayLabel(language: language), dhikrTitle),
                    dateComponents: components,
                    repeats: false
                )
            }
        case .timeWindowStart:
            guard let slotID = reminder.slotID,
                  let slot = slotsByID[slotID],
                  let startMinute = slot.startMinute else {
                return []
            }
            let hour = (startMinute / 60).clamped(to: 0...23)
            let minute = (startMinute % 60).clamped(to: 0...59)
            return candidateScheduleDates(now: now, calendar: calendar).compactMap { day in
                let dateKey = dateKey(for: day, calendar: calendar)
                guard GoalProgressCalculator.isDue(goal, on: dateKey),
                      let fireDate = fireDate(on: day, hour: hour, minute: minute, calendar: calendar),
                      fireDate > now else {
                    return nil
                }
                return PlannedNotification(
                    identifier: identifier(goalID: goal.id, reminderID: reminder.id, dateKey: dateKey),
                    title: dhikrTitle,
                    body: AwradLocalizer.format("Time for your %@ goal.", language: language, dhikrTitle),
                    dateComponents: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate),
                    repeats: false
                )
            }
        }
    }

    private static func identifier(goalID: AwradID, reminderID: AwradID, dateKey: String? = nil) -> String {
        let base = "\(goalReminderIdentifierPrefix(for: goalID))\(reminderID.uuidString)"
        guard let dateKey else { return base }
        return "\(base).\(dateKey)"
    }

    private static func prayerDate(for prayer: Prayer, in summary: PrayerTimesSummary) -> Date? {
        switch prayer {
        case .fajr: summary.fajr
        case .dhuhr: summary.dhuhr
        case .asr: summary.asr
        case .maghrib: summary.maghrib
        case .isha: summary.isha
        }
    }

    private static func candidateScheduleDates(now: Date, calendar: Calendar) -> [Date] {
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        return [today, tomorrow]
    }

    private static func fireDate(on day: Date, hour: Int, minute: Int, calendar: Calendar) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)
    }

    private static func dateKey(for date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

enum ReminderScheduleBuilder {
    static func goalInputs(
        goals: [Goal],
        dhikrs: [Dhikr],
        preferences: UserPreferences,
        prayerTimeService: PrayerTimeService,
        now: Date = Date(),
        calendar: Calendar = .current,
        timeZone: TimeZone = .current
    ) -> [GoalReminderScheduleInput] {
        let titlesByID = Dictionary(uniqueKeysWithValues: dhikrs.map { ($0.id, $0.title) })
        return goals.map { goal in
            GoalReminderScheduleInput(
                goal: goal,
                dhikrTitle: titlesByID[goal.dhikrID] ?? "Dhikr",
                language: preferences.appLanguage,
                prayerTimes: prayerSummaries(
                    for: goal,
                    preferences: preferences,
                    prayerTimeService: prayerTimeService,
                    now: now,
                    calendar: calendar,
                    timeZone: timeZone
                )
            )
        }
    }

    static func wirdInputs(
        wirds: [Wird],
        preferences: UserPreferences,
        prayerTimeService: PrayerTimeService,
        now: Date = Date(),
        calendar: Calendar = .current,
        timeZone: TimeZone = .current
    ) -> [WirdReminderScheduleInput] {
        let prayerTimes = prayerTimeService.summary(
            for: now,
            latitude: preferences.latitude,
            longitude: preferences.longitude,
            method: preferences.calculationMethod,
            madhab: preferences.madhab,
            calendar: calendar,
            timeZone: timeZone
        )
        return wirds.map {
            WirdReminderScheduleInput(
                wird: $0,
                language: preferences.appLanguage,
                prayerTimes: prayerTimes
            )
        }
    }

    static func prayerSummaries(
        for goal: Goal,
        preferences: UserPreferences,
        prayerTimeService: PrayerTimeService,
        now: Date = Date(),
        calendar: Calendar = .current,
        timeZone: TimeZone = .current
    ) -> [PrayerTimesSummary] {
        guard goal.reminders.contains(where: { $0.enabled && $0.reminderType == .prayerOffset }),
              preferences.latitude != nil,
              preferences.longitude != nil else {
            return []
        }

        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        return [now, tomorrow].compactMap { date in
            prayerTimeService.summary(
                for: date,
                latitude: preferences.latitude,
                longitude: preferences.longitude,
                method: preferences.calculationMethod,
                madhab: preferences.madhab,
                calendar: calendar,
                timeZone: timeZone
            )
        }
    }
}

struct PrayerTimeService {
    func summary(
        for date: Date = Date(),
        latitude: Double?,
        longitude: Double?,
        method: PrayerCalculationMethod,
        madhab: PrayerMadhab,
        calendar: Calendar = .current,
        timeZone: TimeZone = .current
    ) -> PrayerTimesSummary? {
        guard let latitude, let longitude else { return nil }
        let parameters = MethodParameters(method: method)
        let declination = SolarPosition.declination(for: date, calendar: calendar, timeZone: timeZone)
        let equationOfTime = SolarPosition.equationOfTime(for: date, calendar: calendar, timeZone: timeZone)
        let startOfDay = calendar.startOfDay(for: date)
        let timeZoneMinutes = Double(timeZone.secondsFromGMT(for: date)) / 60
        let solarNoon = 720 - 4 * longitude - equationOfTime + timeZoneMinutes

        func dateFor(minutes: Double) -> Date {
            let rounded = Int(minutes.rounded())
            return calendar.date(byAdding: .minute, value: rounded, to: startOfDay) ?? date
        }

        let sunriseOffset = hourAngleMinutes(
            latitude: latitude,
            declination: declination,
            altitude: -0.833
        )
        let fajrOffset = hourAngleMinutes(
            latitude: latitude,
            declination: declination,
            altitude: -parameters.fajrAngle
        )
        let asrOffset = asrHourAngleMinutes(
            latitude: latitude,
            declination: declination,
            shadowFactor: madhab.shadowFactor
        )

        let ishaMinutes: Double
        if let interval = parameters.ishaIntervalMinutes {
            ishaMinutes = solarNoon + sunriseOffset + Double(interval)
        } else {
            ishaMinutes = solarNoon + hourAngleMinutes(
                latitude: latitude,
                declination: declination,
                altitude: -parameters.ishaAngle
            )
        }

        return PrayerTimesSummary(
            date: startOfDay,
            fajr: dateFor(minutes: solarNoon - fajrOffset),
            sunrise: dateFor(minutes: solarNoon - sunriseOffset),
            dhuhr: dateFor(minutes: solarNoon),
            asr: dateFor(minutes: solarNoon + asrOffset),
            maghrib: dateFor(minutes: solarNoon + sunriseOffset),
            isha: dateFor(minutes: ishaMinutes)
        )
    }

    func nextPrayer(
        today: PrayerTimesSummary,
        tomorrow: PrayerTimesSummary?,
        now: Date = Date()
    ) -> NextPrayerSummary? {
        let prayers: [(Prayer, Date)] = [
            (.fajr, today.fajr),
            (.dhuhr, today.dhuhr),
            (.asr, today.asr),
            (.maghrib, today.maghrib),
            (.isha, today.isha)
        ]

        if let upcoming = prayers.first(where: { $0.1 > now }) {
            return NextPrayerSummary(
                prayer: upcoming.0,
                time: upcoming.1,
                countdown: Self.formatCountdown(from: now, to: upcoming.1),
                isTomorrow: false
            )
        }

        guard let tomorrow else { return nil }
        return NextPrayerSummary(
            prayer: .fajr,
            time: tomorrow.fajr,
            countdown: Self.formatCountdown(from: now, to: tomorrow.fajr),
            isTomorrow: true
        )
    }

    static func formatTime(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    static func formatCountdown(from now: Date, to target: Date) -> String {
        let diff = max(Int(target.timeIntervalSince(now) / 60), 0)
        let hours = diff / 60
        let minutes = diff % 60
        return hours > 0 ? "in \(hours)h\(minutes)m" : "in \(minutes)m"
    }

    private func hourAngleMinutes(latitude: Double, declination: Double, altitude: Double) -> Double {
        let latitudeRadians = latitude.degreesToRadians
        let altitudeRadians = altitude.degreesToRadians
        let numerator = sin(altitudeRadians) - sin(latitudeRadians) * sin(declination)
        let denominator = cos(latitudeRadians) * cos(declination)
        let cosine = (numerator / denominator).clamped(to: -1...1)
        return acos(cosine).radiansToDegrees * 4
    }

    private func asrHourAngleMinutes(latitude: Double, declination: Double, shadowFactor: Double) -> Double {
        let latitudeRadians = latitude.degreesToRadians
        let angle = atan(1 / (shadowFactor + tan(abs(latitudeRadians - declination))))
        return hourAngleMinutes(latitude: latitude, declination: declination, altitude: angle.radiansToDegrees)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}

final class LocationService: NSObject, CLLocationManagerDelegate {
    private let geocoder = CLGeocoder()
    private let manager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CitySearchResult, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func searchCity(_ query: String) async -> [CitySearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return await withCheckedContinuation { continuation in
            geocoder.geocodeAddressString(trimmed) { placemarks, _ in
                let results = (placemarks ?? [])
                    .compactMap(Self.cityResult)
                    .reduce(into: [CitySearchResult]()) { partial, result in
                        guard !partial.contains(where: { $0.displayName == result.displayName }) else { return }
                        partial.append(result)
                    }
                continuation.resume(returning: Array(results.prefix(5)))
            }
        }
    }

    func requestCurrentLocation() async throws -> CitySearchResult {
        try await withCheckedThrowingContinuation { continuation in
            guard locationContinuation == nil else {
                continuation.resume(throwing: LocationLookupError.alreadyRequesting)
                return
            }

            locationContinuation = continuation
            switch manager.authorizationStatus {
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            case .authorizedAlways, .authorizedWhenInUse:
                manager.requestLocation()
            case .denied, .restricted:
                finishLocationRequest(with: .failure(LocationLookupError.permissionDenied))
            @unknown default:
                finishLocationRequest(with: .failure(LocationLookupError.permissionDenied))
            }
        }
    }

    func reverseGeocode(latitude: Double, longitude: Double) async -> String {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        return await withCheckedContinuation { continuation in
            geocoder.reverseGeocodeLocation(location) { placemarks, _ in
                let displayName = placemarks?.compactMap(Self.displayName).first ?? ""
                continuation.resume(returning: displayName)
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard locationContinuation != nil else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            finishLocationRequest(with: .failure(LocationLookupError.permissionDenied))
        case .notDetermined:
            break
        @unknown default:
            finishLocationRequest(with: .failure(LocationLookupError.permissionDenied))
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            finishLocationRequest(with: .failure(LocationLookupError.locationUnavailable))
            return
        }

        Task {
            let cityName = await reverseGeocode(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
            let result = CitySearchResult(
                name: cityName.isEmpty ? "Current Location" : cityName,
                displayName: cityName.isEmpty ? "Current Location" : cityName,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
            finishLocationRequest(with: .success(result))
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finishLocationRequest(with: .failure(error))
    }

    private func finishLocationRequest(with result: Result<CitySearchResult, Error>) {
        guard let continuation = locationContinuation else { return }
        locationContinuation = nil
        continuation.resume(with: result)
    }

    nonisolated private static func cityResult(from placemark: CLPlacemark) -> CitySearchResult? {
        guard let location = placemark.location else { return nil }
        let name = placemark.locality ?? placemark.subAdministrativeArea ?? placemark.administrativeArea ?? placemark.country ?? "Location"
        let displayName = displayName(from: placemark) ?? name
        return CitySearchResult(
            name: name,
            displayName: displayName,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
    }

    nonisolated private static func displayName(from placemark: CLPlacemark) -> String? {
        let parts = [
            placemark.locality,
            placemark.administrativeArea,
            placemark.country
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }

        let unique = parts.reduce(into: [String]()) { partial, part in
            guard !partial.contains(part) else { return }
            partial.append(part)
        }
        return unique.isEmpty ? nil : unique.joined(separator: ", ")
    }
}

enum LocationLookupError: LocalizedError {
    case alreadyRequesting
    case permissionDenied
    case locationUnavailable

    var errorDescription: String? {
        switch self {
        case .alreadyRequesting: "A location request is already running."
        case .permissionDenied: "Location permission is needed for prayer times."
        case .locationUnavailable: "Current location is unavailable."
        }
    }
}

private struct MethodParameters {
    let fajrAngle: Double
    let ishaAngle: Double
    let ishaIntervalMinutes: Int?

    init(method: PrayerCalculationMethod) {
        switch method {
        case .karachi:
            fajrAngle = 18
            ishaAngle = 18
            ishaIntervalMinutes = nil
        case .northAmerica:
            fajrAngle = 15
            ishaAngle = 15
            ishaIntervalMinutes = nil
        case .muslimWorldLeague:
            fajrAngle = 18
            ishaAngle = 17
            ishaIntervalMinutes = nil
        case .egypt:
            fajrAngle = 19.5
            ishaAngle = 17.5
            ishaIntervalMinutes = nil
        case .ummAlQura:
            fajrAngle = 18.5
            ishaAngle = 0
            ishaIntervalMinutes = 90
        case .moonSighting:
            fajrAngle = 18
            ishaAngle = 18
            ishaIntervalMinutes = nil
        case .dubai:
            fajrAngle = 18.2
            ishaAngle = 18.2
            ishaIntervalMinutes = nil
        case .kuwait:
            fajrAngle = 18
            ishaAngle = 17.5
            ishaIntervalMinutes = nil
        case .qatar:
            fajrAngle = 18
            ishaAngle = 0
            ishaIntervalMinutes = 90
        case .singapore:
            fajrAngle = 20
            ishaAngle = 18
            ishaIntervalMinutes = nil
        }
    }
}

private enum SolarPosition {
    static func equationOfTime(for date: Date, calendar: Calendar, timeZone: TimeZone) -> Double {
        let gamma = fractionalYear(for: date, calendar: calendar, timeZone: timeZone)
        return 229.18 * (
            0.000075
            + 0.001868 * cos(gamma)
            - 0.032077 * sin(gamma)
            - 0.014615 * cos(2 * gamma)
            - 0.040849 * sin(2 * gamma)
        )
    }

    static func declination(for date: Date, calendar: Calendar, timeZone: TimeZone) -> Double {
        let gamma = fractionalYear(for: date, calendar: calendar, timeZone: timeZone)
        return 0.006918
            - 0.399912 * cos(gamma)
            + 0.070257 * sin(gamma)
            - 0.006758 * cos(2 * gamma)
            + 0.000907 * sin(2 * gamma)
            - 0.002697 * cos(3 * gamma)
            + 0.00148 * sin(3 * gamma)
    }

    private static func fractionalYear(for date: Date, calendar: Calendar, timeZone: TimeZone) -> Double {
        var calendar = calendar
        calendar.timeZone = timeZone
        let day = Double(calendar.ordinality(of: .day, in: .year, for: date) ?? 1)
        return 2 * .pi / 365 * (day - 1)
    }
}

private extension Double {
    var degreesToRadians: Double { self * .pi / 180 }
    var radiansToDegrees: Double { self * 180 / .pi }

    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

@Observable
final class AudioSessionService {
    private(set) var isConfigured = false
    private(set) var playbackContext: AudioPlaybackContext?
    private(set) var isPlaying = false
    private(set) var progress: Double = 0
    private(set) var elapsedText = "0:00"
    private(set) var durationText = "0:00"
    private(set) var errorMessage: String?
    /// Monotonic counter incremented each time a counting-mode play completes a loop.
    /// Used by the counter coach-mark to gate the audio step.
    private(set) var countingPlayTick = 0
    var playbackRate: Double = 1 {
        didSet {
            playbackRate = playbackRate.clamped(to: 0.75...3)
            guard isPlaying else { return }
            player?.rate = Float(playbackRate)
            updateNowPlayingInfo(force: true)
        }
    }

    private var player: AVPlayer?
    private var progressTimer: Timer?
    private var endObserver: NSObjectProtocol?
    private let notificationCenter: NotificationCenter
    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?
    private var mediaServicesResetObserver: NSObjectProtocol?
    private var shouldResumeAfterInterruption = false
    private var remoteCommandTargets: [(command: MPRemoteCommand, target: Any)] = []
    private var onCountingLoopCompleted: (() -> Bool)?
    private var nowPlayingTitle = "Awrad"
    private var nowPlayingSubtitle = "Dhikr"
    private var lastNowPlayingElapsedSecond: Int?

    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
        registerAudioSessionObservers()
    }

    deinit {
        stop()
        unregisterRemoteCommands()
        removeAudioSessionObservers()
    }

    func configureForPlayback() {
        guard !isConfigured else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            registerRemoteCommandsIfNeeded()
            isConfigured = true
        } catch {
            isConfigured = false
        }
    }

    func togglePreview(for dhikr: Dhikr, title: String? = nil) {
        let context = AudioPlaybackContext.preview(dhikrID: dhikr.id)
        if playbackContext == context {
            isPlaying ? pause() : play()
            return
        }
        startPreview(for: dhikr, title: title)
    }

    func startPreview(for dhikr: Dhikr, title: String? = nil) {
        do {
            try preparePlayer(for: dhikr, context: .preview(dhikrID: dhikr.id), title: title)
            onCountingLoopCompleted = nil
            play()
        } catch {
            fail(with: error)
        }
    }

    func startCounting(
        for dhikr: Dhikr,
        goalID: AwradID,
        title: String? = nil,
        onCompletedPlay: @escaping () -> Bool
    ) {
        do {
            try preparePlayer(for: dhikr, context: .counting(goalID: goalID, dhikrID: dhikr.id), title: title)
            onCountingLoopCompleted = onCompletedPlay
            play()
        } catch {
            fail(with: error)
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingInfo(force: true)
    }

    func play() {
        guard player != nil else { return }
        configureForPlayback()
        player?.playImmediately(atRate: Float(playbackRate))
        isPlaying = true
        startProgressTimer()
        updateNowPlayingInfo(force: true)
    }

    func stop() {
        player?.pause()
        player = nil
        playbackContext = nil
        onCountingLoopCompleted = nil
        isPlaying = false
        progress = 0
        elapsedText = "0:00"
        durationText = "0:00"
        errorMessage = nil
        clearNowPlayingInfo()
        progressTimer?.invalidate()
        progressTimer = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
    }

    func isPreviewing(_ dhikrID: AwradID) -> Bool {
        playbackContext == .preview(dhikrID: dhikrID)
    }

    func isCounting(goalID: AwradID) -> Bool {
        playbackContext?.goalID == goalID
    }

    func sourceURL(for dhikr: Dhikr) -> URL? {
        if dhikr.isDownloaded,
           let fileName = dhikr.audioFileName,
           let localURL = localAudioURL(fileName: fileName) {
            return localURL
        }
        return dhikr.audioURL
    }

    func downloadAudio(from url: URL, suggestedFileName: String?) async throws -> String {
        let (temporaryURL, _) = try await URLSession.shared.download(from: url)
        let fileName = suggestedFileName ?? url.lastPathComponent
        let destinationDirectory = try Self.audioDirectory()
        let destinationURL = destinationDirectory.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
        return fileName
    }

    func localAudioURL(fileName: String) -> URL? {
        guard let url = try? Self.audioDirectory().appendingPathComponent(fileName),
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return url
    }

    private func preparePlayer(for dhikr: Dhikr, context: AudioPlaybackContext, title: String?) throws {
        errorMessage = nil
        if playbackContext == context, player != nil {
            player?.seek(to: .zero)
            refreshProgress()
            return
        }

        stop()
        guard let sourceURL = sourceURL(for: dhikr) else {
            throw AudioPlaybackError.missingSource
        }

        let item = AVPlayerItem(url: sourceURL)
        let player = AVPlayer(playerItem: item)
        self.player = player
        playbackContext = context
        updateNowPlayingMetadata(for: dhikr, context: context, title: title)
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.handlePlaybackEnd()
        }
        startProgressTimer()
    }

    private func handlePlaybackEnd() {
        guard let playbackContext else { return }
        switch playbackContext {
        case .preview:
            pause()
            player?.seek(to: .zero)
            progress = 0
            elapsedText = "0:00"
            updateNowPlayingInfo(force: true)
        case .counting:
            countingPlayTick &+= 1
            let shouldContinue = onCountingLoopCompleted?() ?? false
            guard shouldContinue else {
                stop()
                return
            }
            player?.seek(to: .zero) { [weak self] _ in
                guard let self else { return }
                self.play()
            }
        }
    }

    private func fail(with error: Error) {
        stop()
        errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    private func startProgressTimer() {
        progressTimer?.invalidate()
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.refreshProgress()
        }
        progressTimer = timer
        RunLoop.main.add(timer, forMode: .common)
        refreshProgress()
    }

    private func refreshProgress() {
        guard let player else {
            progress = 0
            elapsedText = "0:00"
            durationText = "0:00"
            return
        }

        let elapsed = player.currentTime().seconds
        let duration = player.currentItem?.duration.seconds ?? 0
        elapsedText = Self.durationString(elapsed)
        durationText = Self.durationString(duration)
        if duration.isFinite, duration > 0, elapsed.isFinite {
            progress = (elapsed / duration).clamped(to: 0...1)
        } else {
            progress = 0
        }
        updateNowPlayingInfo()
    }

    private func updateNowPlayingMetadata(for dhikr: Dhikr, context: AudioPlaybackContext, title: String?) {
        nowPlayingTitle = title ?? dhikr.title
        nowPlayingSubtitle = context.nowPlayingSubtitle
        lastNowPlayingElapsedSecond = nil
        updateNowPlayingInfo(force: true)
    }

    private func updateNowPlayingInfo(force: Bool = false) {
        guard player != nil else { return }

        let elapsed = player?.currentTime().seconds ?? 0
        let elapsedSecond = elapsed.isFinite ? Int(elapsed.rounded(.down)) : 0
        guard force || elapsedSecond != lastNowPlayingElapsedSecond else { return }
        lastNowPlayingElapsedSecond = elapsedSecond

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: nowPlayingTitle,
            MPMediaItemPropertyArtist: "Awrad",
            MPMediaItemPropertyAlbumTitle: nowPlayingSubtitle,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed.isFinite ? elapsed : 0,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? playbackRate : 0
        ]

        let duration = player?.currentItem?.duration.seconds ?? 0
        if duration.isFinite, duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
    }

    private func clearNowPlayingInfo() {
        lastNowPlayingElapsedSecond = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        MPNowPlayingInfoCenter.default().playbackState = .stopped
    }

    private func registerRemoteCommandsIfNeeded() {
        guard remoteCommandTargets.isEmpty else { return }

        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.isEnabled = true
        remoteCommandTargets.append((commandCenter.playCommand, commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self, self.player != nil else { return .noActionableNowPlayingItem }
            self.play()
            return .success
        }))

        commandCenter.pauseCommand.isEnabled = true
        remoteCommandTargets.append((commandCenter.pauseCommand, commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self, self.player != nil else { return .noActionableNowPlayingItem }
            self.pause()
            return .success
        }))

        commandCenter.togglePlayPauseCommand.isEnabled = true
        remoteCommandTargets.append((commandCenter.togglePlayPauseCommand, commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self, self.player != nil else { return .noActionableNowPlayingItem }
            self.isPlaying ? self.pause() : self.play()
            return .success
        }))

        commandCenter.stopCommand.isEnabled = true
        remoteCommandTargets.append((commandCenter.stopCommand, commandCenter.stopCommand.addTarget { [weak self] _ in
            guard let self, self.player != nil else { return .noActionableNowPlayingItem }
            self.stop()
            return .success
        }))

        commandCenter.changePlaybackPositionCommand.isEnabled = true
        remoteCommandTargets.append((commandCenter.changePlaybackPositionCommand, commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self,
                  let event = event as? MPChangePlaybackPositionCommandEvent,
                  self.player != nil else {
                return .noActionableNowPlayingItem
            }
            let time = CMTime(seconds: event.positionTime, preferredTimescale: 600)
            self.player?.seek(to: time)
            self.refreshProgress()
            self.updateNowPlayingInfo(force: true)
            return .success
        }))
    }

    private func unregisterRemoteCommands() {
        guard !remoteCommandTargets.isEmpty else { return }
        for registration in remoteCommandTargets {
            registration.command.removeTarget(registration.target)
        }
        remoteCommandTargets.removeAll()
    }

    private func registerAudioSessionObservers() {
        let session = AVAudioSession.sharedInstance()
        interruptionObserver = notificationCenter.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            self?.handleAudioSessionInterruption(notification)
        }
        routeChangeObserver = notificationCenter.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            guard Self.routeChangeRequiresPause(notification) else { return }
            self?.pause()
        }
        mediaServicesResetObserver = notificationCenter.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: session,
            queue: .main
        ) { [weak self] _ in
            self?.restoreAfterMediaServicesReset()
        }
    }

    private func removeAudioSessionObservers() {
        for observer in [interruptionObserver, routeChangeObserver, mediaServicesResetObserver].compactMap({ $0 }) {
            notificationCenter.removeObserver(observer)
        }
        interruptionObserver = nil
        routeChangeObserver = nil
        mediaServicesResetObserver = nil
    }

    private func handleAudioSessionInterruption(_ notification: Notification) {
        switch Self.interruptionAction(notification) {
        case .pause:
            shouldResumeAfterInterruption = isPlaying
            pause()
        case .resume:
            let shouldResume = shouldResumeAfterInterruption
            shouldResumeAfterInterruption = false
            if shouldResume {
                play()
            }
        case .finishWithoutResuming:
            shouldResumeAfterInterruption = false
        case .ignore:
            break
        }
    }

    private func restoreAfterMediaServicesReset() {
        let shouldResume = isPlaying
        isConfigured = false
        configureForPlayback()
        if shouldResume {
            play()
        }
    }

    enum InterruptionAction: Equatable {
        case pause
        case resume
        case finishWithoutResuming
        case ignore
    }

    static func interruptionAction(_ notification: Notification) -> InterruptionAction {
        guard let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return .ignore
        }
        switch type {
        case .began:
            return .pause
        case .ended:
            let optionValue = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionValue)
            return options.contains(.shouldResume) ? .resume : .finishWithoutResuming
        @unknown default:
            return .ignore
        }
    }

    static func routeChangeRequiresPause(_ notification: Notification) -> Bool {
        guard let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return false
        }
        return reason == .oldDeviceUnavailable
    }

    private static func durationString(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0:00" }
        let totalSeconds = Int(seconds.rounded())
        return "\(totalSeconds / 60):\(String(format: "%02d", totalSeconds % 60))"
    }

    private static func audioDirectory() throws -> URL {
        let supportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let directory = supportURL
            .appendingPathComponent("Awrad", isDirectory: true)
            .appendingPathComponent("Audio", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

enum AudioPlaybackContext: Equatable {
    case preview(dhikrID: AwradID)
    case counting(goalID: AwradID, dhikrID: AwradID)

    var goalID: AwradID? {
        switch self {
        case .preview:
            nil
        case .counting(let goalID, _):
            goalID
        }
    }

    var dhikrID: AwradID {
        switch self {
        case .preview(let dhikrID):
            dhikrID
        case .counting(_, let dhikrID):
            dhikrID
        }
    }

    var nowPlayingSubtitle: String {
        switch self {
        case .preview:
            "Audio preview"
        case .counting:
            "Audio counting"
        }
    }
}

enum AudioPlaybackError: LocalizedError {
    case missingSource

    var errorDescription: String? {
        switch self {
        case .missingSource: "Audio is not available for this dhikr."
        }
    }
}
