import Foundation

// Rules: the version on a day (contracts/goal-model/v1/fixtures/goal_version_on_day.json) and
// saving an edit as a version (goal_version_add.json). Editing never rewrites the past (decision 23).

extension GoalTimeline {
    /// At most this many versions; a 101st folds the oldest into the next.
    public static let maximumVersions = 100

    /// The index of the version in force on `day`: the one with the latest `from` on or before
    /// it. Days before the first version use the first.
    public func versionIndex(on day: CalendarDay) -> Int {
        versions.lastIndex { $0.from <= day } ?? 0
    }

    /// The goal a rule evaluates on `day`: that version's settings with the timeline's pauses and
    /// excused days. Once ended, a version whose own last day is later than `ended.on` (or that
    /// has none) ends on `ended.on` instead.
    public func goal(on day: CalendarDay) -> Goal {
        let settings = versions[versionIndex(on: day)].settings
        guard let ended, settings.activePeriod.lastDay.map({ $0 > ended.on }) ?? true else {
            return Goal(settings: settings, paused: paused, excused: excused)
        }
        return Goal(settings: settings.ending(on: ended.on), paused: paused, excused: excused)
    }

    /// The goal on `day` with its version's own end, even after the goal has ended: daily pace
    /// judges each day against the end its version had then.
    func uncappedGoal(on day: CalendarDay) -> Goal {
        Goal(settings: versions[versionIndex(on: day)].settings, paused: paused, excused: excused)
    }

    /// The versions after saving a detail edit made on `today` (README.md, Dated versions):
    /// unchanged settings add nothing; an edit applies from today as a new version; a second edit
    /// on the same day (or to a version starting after today) replaces it, and an edit back to
    /// the previous settings removes it; a 101st version folds the oldest into the next, which
    /// takes its `from`.
    public static func versions(
        _ versions: [GoalVersion], saving settings: GoalSettings, on today: CalendarDay
    ) -> [GoalVersion] {
        guard let last = versions.last, last.settings != settings else { return versions }
        var result = versions
        if last.from >= today {
            result[result.count - 1].settings = settings
            if result.count >= 2, result[result.count - 2].settings == settings { result.removeLast() }
        } else {
            result.append(GoalVersion(from: today, settings: settings))
        }
        if result.count > maximumVersions {
            let oldest = result.removeFirst()
            result[0].from = oldest.from
        }
        return result
    }

    /// This timeline after saving a detail edit made on `today` (`versions(_:saving:on:)`). Throws
    /// when the edit changes a structural field: that ends the goal and starts a new one instead.
    public func saving(_ settings: GoalSettings, on today: CalendarDay) throws(GoalValidationError) -> GoalTimeline {
        try GoalTimeline(
            createdOn: createdOn, versions: Self.versions(versions, saving: settings, on: today), paused: paused,
            excused: excused, ended: ended)
    }
}
