import Foundation

struct AwradPersistenceValidationError: LocalizedError, Equatable {
    var issues: [String]

    var errorDescription: String? {
        "Awrad persistence validation failed: \(issues.joined(separator: "; "))"
    }
}

enum AwradPersistenceValidator {
    static func validate(state: AwradRepositoryState) throws {
        var issues: [String] = []
        issues += duplicateIssues(state.dhikrs.map { ($0.id.uuidString, "dhikr") })
        issues += duplicateIssues(state.goals.map { ($0.id.uuidString, "goal") })
        issues += duplicateIssues(state.countEntries.map { ($0.id.uuidString, "count entry") })
        issues += duplicateIssues(state.wirds.map { ($0.id.uuidString, "wird") })
        issues += duplicateIssues(state.wirdSessions.map { ($0.id.uuidString, "wird session") })

        let catalogKeys = state.dhikrs.compactMap(\.catalogKey)
        issues += duplicateValueIssues(catalogKeys, label: "dhikr catalog key")
        issues += duplicateValueIssues(state.wirds.map(\.slug), label: "wird slug")

        for dhikr in state.dhikrs {
            if dhikr.arabic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append("dhikr \(dhikr.id) has empty Arabic text")
            }
            if dhikr.audioCountPerPlay < 1 {
                issues.append("dhikr \(dhikr.id) has invalid audioCountPerPlay")
            }
            if dhikr.sortOrder < 0 {
                issues.append("dhikr \(dhikr.id) has a negative sort order")
            }
            if let quran = dhikr.quranRef,
               quran.surah < 1 || quran.surah > 114 || quran.ayahStart < 1 || (quran.ayahEnd ?? quran.ayahStart) < quran.ayahStart {
                issues.append("dhikr \(dhikr.id) has an invalid Quran reference")
            }
        }

        let dhikrIDs = Set(state.dhikrs.map(\.id))
        let goalIDs = Set(state.goals.map(\.id))
        var allSlotIDs = Set<AwradID>()
        var allReminderIDs = Set<AwradID>()
        for goal in state.goals {
            if !dhikrIDs.contains(goal.dhikrID) {
                issues.append("goal \(goal.id) references missing dhikr \(goal.dhikrID)")
            }
            issues += goalIssues(goal)
            for slot in goal.slots where !allSlotIDs.insert(slot.id).inserted {
                issues.append("duplicate goal slot id \(slot.id)")
            }
            for reminder in goal.reminders where !allReminderIDs.insert(reminder.id).inserted {
                issues.append("duplicate goal reminder id \(reminder.id)")
            }
        }

        var countKeys = Set<String>()
        for entry in state.countEntries {
            issues += countEntryIssues(entry)
            guard goalIDs.contains(entry.goalID) else {
                issues.append("count entry \(entry.id) references missing goal \(entry.goalID)")
                continue
            }
            guard let goal = state.goals.first(where: { $0.id == entry.goalID }),
                  goal.slots.contains(where: { $0.id == entry.slotID }) else {
                issues.append("count entry \(entry.id) references a slot outside its goal")
                continue
            }
            let semanticKey = AwradSchemaV1.CountEntryRecord.makeSemanticKey(
                goalID: entry.goalID.uuidString.lowercased(),
                dateKey: entry.dateKey,
                slotID: entry.slotID.uuidString.lowercased()
            )
            if !countKeys.insert(semanticKey).inserted {
                issues.append("duplicate count entry semantic key \(semanticKey)")
            }
        }

        issues += seasonTemplateIssues(state.seasonTemplates)

        for wird in state.wirds {
            issues += wirdIssues(wird)
            for part in wird.parts {
                for segment in part.segments {
                    if let sourceDhikrID = segment.sourceDhikrID,
                       !dhikrIDs.contains(sourceDhikrID) {
                        issues.append("wird segment \(segment.id) references missing dhikr \(sourceDhikrID)")
                    }
                }
            }
        }
        var sessionKeys = Set<String>()
        for session in state.wirdSessions {
            issues += wirdSessionIssues(session, wirds: state.wirds)
            let semanticKey = AwradSchemaV1.WirdSessionRecord.makeSemanticKey(
                wirdID: session.wirdID.uuidString.lowercased(),
                partID: session.partID.uuidString.lowercased(),
                occasionKey: session.occasionKey,
                dateKey: session.dateKey
            )
            if !sessionKeys.insert(semanticKey).inserted {
                issues.append("duplicate wird session semantic key \(semanticKey)")
            }
        }

        if !issues.isEmpty {
            throw AwradPersistenceValidationError(issues: issues.sorted())
        }
    }

    static func validateGoal(_ goal: Goal) throws {
        let issues = goalIssues(goal)
        if !issues.isEmpty {
            throw AwradPersistenceValidationError(issues: issues.sorted())
        }
    }

    static func validateCountEntry(_ entry: CountEntry) throws {
        let issues = countEntryIssues(entry)
        if !issues.isEmpty {
            throw AwradPersistenceValidationError(issues: issues.sorted())
        }
    }

    static func validateSeasonTemplates(_ templates: [SeasonTemplateDefinition]) throws {
        let issues = seasonTemplateIssues(templates)
        if !issues.isEmpty {
            throw AwradPersistenceValidationError(issues: issues.sorted())
        }
    }

    static func validateWird(_ wird: Wird) throws {
        let issues = wirdIssues(wird)
        if !issues.isEmpty {
            throw AwradPersistenceValidationError(issues: issues.sorted())
        }
    }

    static func validateWirdSession(_ session: WirdSession, wirds: [Wird]) throws {
        let issues = wirdSessionIssues(session, wirds: wirds)
        if !issues.isEmpty {
            throw AwradPersistenceValidationError(issues: issues.sorted())
        }
    }

    static func preferenceIssues(_ preferences: UserPreferences) -> [String] {
        var issues: [String] = []
        if preferences.onboardingStep < 0 || preferences.onboardingStep > 9 {
            issues.append("preferences have an invalid onboarding step")
        }
        if preferences.onboardingFirstGoalCount < 1 {
            issues.append("preferences have an invalid first-goal count")
        }
        if !(0...23).contains(preferences.reminderHour) || !(0...59).contains(preferences.reminderMinute) {
            issues.append("preferences have an invalid reminder time")
        }
        if preferences.prayerSlotDefaultLeadMinutes < 0 {
            issues.append("preferences have an invalid prayer lead time")
        }
        if preferences.prayerSlotDefaultLeadMinutes > 180 {
            issues.append("preferences have an unsupported prayer lead time")
        }
        if !preferences.countingDhikrTextScale.isFinite ||
            !(0.85...1.3).contains(preferences.countingDhikrTextScale) {
            issues.append("preferences have an invalid counting text scale")
        }
        if !preferences.countingDhikrLineSpacing.isFinite ||
            !(0.9...1.3).contains(preferences.countingDhikrLineSpacing) {
            issues.append("preferences have invalid counting line spacing")
        }
        if let latitude = preferences.latitude, !(-90...90).contains(latitude) {
            issues.append("preferences have an invalid latitude")
        }
        if let longitude = preferences.longitude, !(-180...180).contains(longitude) {
            issues.append("preferences have an invalid longitude")
        }
        if (preferences.latitude == nil) != (preferences.longitude == nil) {
            issues.append("preferences have an incomplete location")
        }
        let normalizedPresetKeys = preferences.onboardingReminderPresetKeys.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if normalizedPresetKeys.contains(where: \.isEmpty) ||
            Set(normalizedPresetKeys).count != normalizedPresetKeys.count {
            issues.append("preferences have invalid onboarding reminder presets")
        }
        if !AppLanguage.allCases.contains(where: { $0.rawValue == preferences.languageCode }) {
            issues.append("preferences have an unsupported language")
        }
        return issues
    }

    private static func goalIssues(_ goal: Goal) -> [String] {
        var issues: [String] = []
        if !isDateKey(goal.startDate) {
            issues.append("goal \(goal.id) has an invalid start date")
        }
        if let endDate = goal.endDate {
            if !isDateKey(endDate) {
                issues.append("goal \(goal.id) has an invalid end date")
            } else if endDate < goal.startDate {
                issues.append("goal \(goal.id) ends before it starts")
            }
        }
        if let durationDays = goal.durationDays, durationDays < 1 {
            issues.append("goal \(goal.id) has an invalid duration")
        }
        if let minimumStreakCount = goal.minimumStreakCount, minimumStreakCount < 1 {
            issues.append("goal \(goal.id) has an invalid minimum streak count")
        }
        if let intervalDays = goal.recurrence.intervalDays, intervalDays < 1 {
            issues.append("goal \(goal.id) has an invalid recurrence interval")
        }
        if let month = goal.recurrence.month, !(1...12).contains(month) {
            issues.append("goal \(goal.id) has an invalid recurrence month")
        }
        if !goal.recurrence.weekdays.allSatisfy({ (1...7).contains($0) }) {
            issues.append("goal \(goal.id) has an invalid weekday")
        }
        if !goal.recurrence.monthDays.allSatisfy({ (1...31).contains($0) }) {
            issues.append("goal \(goal.id) has an invalid month day")
        }
        if !goal.recurrence.specificDates.allSatisfy(isValidSpecificDate) {
            issues.append("goal \(goal.id) has an invalid specific date")
        }
        issues += countPolicyIssues(
            minimum: goal.countPolicy.minimumCount,
            target: goal.countPolicy.targetCount,
            maximum: goal.countPolicy.maximumCount,
            label: "goal \(goal.id)"
        )
        if goal.totalCompletedCount < 0 {
            issues.append("goal \(goal.id) has a negative completed count")
        }
        if goal.slots.isEmpty {
            issues.append("goal \(goal.id) has no slots")
        }

        let slotIDs = Set(goal.slots.map(\.id))
        if slotIDs.count != goal.slots.count {
            issues.append("goal \(goal.id) has duplicate slot ids")
        }
        for slot in goal.slots {
            if slot.goalID != goal.id {
                issues.append("slot \(slot.id) has the wrong goal id")
            }
            issues += countPolicyIssues(
                minimum: slot.minimumCount,
                target: slot.targetCount,
                maximum: slot.maximumCount,
                label: "slot \(slot.id)"
            )
            if let minute = slot.startMinute, !(0...1439).contains(minute) {
                issues.append("slot \(slot.id) has an invalid start minute")
            }
            if let minute = slot.endMinute, !(0...1439).contains(minute) {
                issues.append("slot \(slot.id) has an invalid end minute")
            }
            if let lead = slot.startLeadMinutesOverride, lead < 0 {
                issues.append("slot \(slot.id) has an invalid prayer lead")
            }
            if slot.sortOrder < 0 {
                issues.append("slot \(slot.id) has a negative sort order")
            }
            switch slot.slotType {
            case .prayer:
                if slot.prayerName == nil || slot.prayerRelation == nil {
                    issues.append("slot \(slot.id) has incomplete prayer timing")
                }
            case .timeWindow:
                if slot.startMinute == nil || slot.endMinute == nil ||
                    slot.label?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                    issues.append("slot \(slot.id) has an incomplete time window")
                }
            case .anytime:
                break
            }
        }

        let reminderIDs = Set(goal.reminders.map(\.id))
        if reminderIDs.count != goal.reminders.count {
            issues.append("goal \(goal.id) has duplicate reminder ids")
        }
        for reminder in goal.reminders {
            if reminder.goalID != goal.id {
                issues.append("reminder \(reminder.id) has the wrong goal id")
            }
            if let slotID = reminder.slotID, !slotIDs.contains(slotID) {
                issues.append("reminder \(reminder.id) references a slot outside its goal")
            }
            if let hour = reminder.hour, !(0...23).contains(hour) {
                issues.append("reminder \(reminder.id) has an invalid hour")
            }
            if let minute = reminder.minute, !(0...59).contains(minute) {
                issues.append("reminder \(reminder.id) has an invalid minute")
            }
            if reminder.sortOrder < 0 {
                issues.append("reminder \(reminder.id) has a negative sort order")
            }
            switch reminder.reminderType {
            case .fixedTime:
                if reminder.hour == nil || reminder.minute == nil {
                    issues.append("reminder \(reminder.id) has an incomplete fixed time")
                }
            case .prayerOffset, .timeWindowStart:
                if reminder.slotID == nil {
                    issues.append("reminder \(reminder.id) is missing its session")
                }
            }
        }
        return issues
    }

    private static func countPolicyIssues(minimum: Int?, target: Int?, maximum: Int?, label: String) -> [String] {
        let values = [minimum, target, maximum].compactMap { $0 }
        var issues = values.contains(where: { $0 < 1 }) ? ["\(label) has a non-positive count threshold"] : []
        if let minimum, let target, minimum > target {
            issues.append("\(label) minimum exceeds target")
        }
        if let target, let maximum, target > maximum {
            issues.append("\(label) target exceeds maximum")
        }
        if let minimum, let maximum, minimum > maximum {
            issues.append("\(label) minimum exceeds maximum")
        }
        return issues
    }

    private static func countEntryIssues(_ entry: CountEntry) -> [String] {
        var issues: [String] = []
        if entry.count < 0 {
            issues.append("count entry \(entry.id) has a negative count")
        }
        if entry.dateKey != "all-time", !isDateKey(entry.dateKey) {
            issues.append("count entry \(entry.id) has an invalid date key")
        }
        return issues
    }

    private static func seasonTemplateIssues(_ templates: [SeasonTemplateDefinition]) -> [String] {
        var issues = duplicateValueIssues(templates.map(\.code), label: "season template code")
        for template in templates {
            if template.code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append("season template has an empty code")
            }
            if !(1...12).contains(template.month) {
                issues.append("season template \(template.code) has an invalid month")
            }
            if !template.days.allSatisfy({ (1...31).contains($0) }) {
                issues.append("season template \(template.code) has an invalid day")
            }
        }
        return issues
    }

    nonisolated private static func isValidSpecificDate(_ rule: GoalSpecificDate) -> Bool {
        if let date = rule.date {
            return isDateKey(date) && rule.month == nil && rule.dayOfMonth == nil
        }
        guard let month = rule.month, let day = rule.dayOfMonth else { return false }
        return (1...12).contains(month) && (1...31).contains(day)
    }

    private static func wirdIssues(_ wird: Wird) -> [String] {
        var issues: [String] = []
        if wird.slug.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("wird \(wird.id) has an empty slug")
        }
        if wird.version < 1 {
            issues.append("wird \(wird.id) has an invalid version")
        }
        if wird.sortOrder < 0 {
            issues.append("wird \(wird.id) has a negative sort order")
        }
        if let estimatedMinutes = wird.estimatedMinutes, estimatedMinutes < 1 {
            issues.append("wird \(wird.id) has invalid estimated minutes")
        }
        issues += scheduleIssues(wird.schedule, partCount: wird.parts.count, label: "wird \(wird.id)")
        let partIDs = Set(wird.parts.map(\.id))
        if partIDs.count != wird.parts.count {
            issues.append("wird \(wird.id) has duplicate part ids")
        }
        var segmentIDs = Set<AwradID>()
        for part in wird.parts {
            if part.blockRepeat < 1 {
                issues.append("wird part \(part.id) has an invalid block repeat")
            }
            if case let .some(.timeWindow(start, end)) = part.occasion,
               (!(0...1439).contains(start) || !(0...1439).contains(end)) {
                issues.append("wird part \(part.id) has an invalid time window")
            }
            for segment in part.segments {
                if !segmentIDs.insert(segment.id).inserted {
                    issues.append("wird \(wird.id) has duplicate segment id \(segment.id)")
                }
                if segment.repeatSpec.count < 1 || (segment.repeatSpec.min ?? 1) < 1 || (segment.repeatSpec.max ?? 1) < 1 {
                    issues.append("wird segment \(segment.id) has an invalid repeat")
                }
                if let lower = segment.repeatSpec.min, let upper = segment.repeatSpec.max, lower > upper {
                    issues.append("wird segment \(segment.id) repeat minimum exceeds maximum")
                }
                if let quran = segment.quranRef,
                   quran.surah < 1 || quran.surah > 114 || quran.ayahStart < 1 ||
                    (quran.ayahEnd ?? quran.ayahStart) < quran.ayahStart {
                    issues.append("wird segment \(segment.id) has an invalid Quran reference")
                }
            }
        }
        let reminderIDs = Set(wird.reminders.map(\.id))
        if reminderIDs.count != wird.reminders.count {
            issues.append("wird \(wird.id) has duplicate reminder ids")
        }
        for reminder in wird.reminders {
            if let hour = reminder.hour, !(0...23).contains(hour) {
                issues.append("wird reminder \(reminder.id) has an invalid hour")
            }
            if let minute = reminder.minute, !(0...59).contains(minute) {
                issues.append("wird reminder \(reminder.id) has an invalid minute")
            }
            if reminder.enabled {
                switch reminder.reminderType {
                case .fixedTime:
                    if reminder.hour == nil || reminder.minute == nil {
                        issues.append("wird reminder \(reminder.id) has an incomplete fixed time")
                    }
                case .prayerOffset:
                    if reminder.prayer == nil || reminder.offsetMinutes == nil {
                        issues.append("wird reminder \(reminder.id) has incomplete prayer timing")
                    }
                case .timeWindowStart:
                    break
                }
            }
        }
        return issues
    }

    private static func scheduleIssues(_ schedule: WirdSchedule, partCount: Int, label: String) -> [String] {
        var issues: [String] = []
        switch schedule.cadence {
        case .everyDay, .rotation:
            break
        case .daysOfWeek(let days):
            if days.isEmpty || !days.allSatisfy({ (1...7).contains($0) }) {
                issues.append("\(label) has invalid cadence weekdays")
            }
        case .interval(let days, let anchor):
            if days < 1 || !isDateKey(anchor) {
                issues.append("\(label) has an invalid interval cadence")
            }
        }
        if let partsByWeekday = schedule.partsByWeekday {
            for (weekday, indexes) in partsByWeekday {
                if !(1...7).contains(weekday) || indexes.isEmpty ||
                    indexes.contains(where: { !(0..<partCount).contains($0) }) ||
                    Set(indexes).count != indexes.count {
                    issues.append("\(label) has an invalid weekday-part assignment")
                }
            }
        }
        switch schedule.hijriAnchor {
        case .hijriMonth(let month):
            if !(1...12).contains(month) { issues.append("\(label) has an invalid Hijri month") }
        case .hijriDate(let month, let day):
            if !(1...12).contains(month) || !(1...30).contains(day) {
                issues.append("\(label) has an invalid Hijri date")
            }
        case .ramadan, .lastTenNights, nil:
            break
        }
        if case .timeWindow(let start, let end) = schedule.defaultOccasion,
           (!(0...1439).contains(start) || !(0...1439).contains(end)) {
            issues.append("\(label) has an invalid default time window")
        }
        return issues
    }

    private static func wirdSessionIssues(_ session: WirdSession, wirds: [Wird]) -> [String] {
        var issues: [String] = []
        guard let wird = wirds.first(where: { $0.id == session.wirdID }) else {
            return ["wird session \(session.id) references missing wird \(session.wirdID)"]
        }
        guard let part = wird.parts.first(where: { $0.id == session.partID }) else {
            return ["wird session \(session.id) references missing part \(session.partID)"]
        }
        if session.occasionKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("wird session \(session.id) has an empty occasion key")
        }
        if !isDateKey(session.dateKey) {
            issues.append("wird session \(session.id) has an invalid date key")
        }
        let segmentIDs = Set(part.segments.map { $0.id.uuidString.lowercased() })
        for (rawID, count) in session.segmentProgress {
            guard let parsed = UUID(uuidString: rawID) else {
                issues.append("wird session \(session.id) has an invalid segment key")
                continue
            }
            if !segmentIDs.contains(parsed.uuidString.lowercased()) {
                issues.append("wird session \(session.id) references missing segment \(rawID)")
            }
            if count < 0 {
                issues.append("wird session \(session.id) has negative segment progress")
            }
        }
        if let lastSegmentID = session.lastSegmentID,
           !segmentIDs.contains(lastSegmentID.uuidString.lowercased()) {
            issues.append("wird session \(session.id) has a missing last segment")
        }
        return issues
    }

    private static func duplicateIssues(_ values: [(String, String)]) -> [String] {
        let grouped = Dictionary(grouping: values, by: \.0)
        return grouped.compactMap { id, matches in
            matches.count > 1 ? "duplicate \(matches[0].1) id \(id)" : nil
        }
    }

    private static func duplicateValueIssues(_ values: [String], label: String) -> [String] {
        Dictionary(grouping: values, by: { $0 })
            .compactMap { value, matches in matches.count > 1 ? "duplicate \(label) \(value)" : nil }
    }

    nonisolated private static func isDateKey(_ value: String) -> Bool {
        let pieces = value.split(separator: "-", omittingEmptySubsequences: false)
        guard value.count == 10,
              pieces.count == 3,
              pieces[0].count == 4,
              pieces[1].count == 2,
              pieces[2].count == 2,
              let year = Int(pieces[0]),
              let month = Int(pieces[1]),
              let day = Int(pieces[2]) else { return false }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else {
            return false
        }
        let roundTrip = calendar.dateComponents([.year, .month, .day], from: date)
        return roundTrip.year == year && roundTrip.month == month && roundTrip.day == day
    }
}
