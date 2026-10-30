import Foundation

// Rule: merge by setting (contracts/practice-settings/v1/fixtures/practice_policy_merge.json).

/// What merging a conflicting policy gives.
public struct PracticePolicyMerge: Hashable, Sendable {
    /// The merged policy: the new local document.
    public let policy: PracticePolicy
    /// Whether it differs from the server's copy and must be sent.
    public let requeue: Bool
    /// Whether this phone's Hijri corrections were dropped because the merged set wasn't valid
    /// (the notice `hijri_corrections_replaced`).
    public let correctionsReplaced: Bool
}

extension PracticePolicy {
    /// Merges `mine` (edited from `base`) with the server's `theirs`, by setting:
    ///
    /// - every setting where `mine` differs from `base` keeps mine; the others take theirs;
    /// - Hijri corrections merge month by month the same way: a month mine added, changed or
    ///   removed relative to the base wins, and the server's other months stay;
    /// - if the merged corrections aren't valid, theirs are kept (`correctionsReplaced`).
    public static func merge(
        base: PracticePolicy, mine: PracticePolicy, theirs: PracticePolicy
    ) -> PracticePolicyMerge {
        func pick<Value: Equatable>(_ setting: KeyPath<PracticePolicy, Value>) -> Value {
            mine[keyPath: setting] != base[keyPath: setting] ? mine[keyPath: setting] : theirs[keyPath: setting]
        }
        let corrections: HijriCorrections
        let replaced: Bool
        if let merged = try? HijriCorrections(
            mergedCorrections(base: base.hijriCorrections, mine: mine.hijriCorrections, theirs: theirs.hijriCorrections)
        ) {
            corrections = merged
            replaced = false
        } else {
            corrections = theirs.hijriCorrections
            replaced = true
        }
        let policy = PracticePolicy(
            dayReset: pick(\.dayReset), calculationMethod: pick(\.calculationMethod), madhab: pick(\.madhab),
            weekStart: pick(\.weekStart), hijriCorrections: corrections)
        return PracticePolicyMerge(policy: policy, requeue: policy != theirs, correctionsReplaced: replaced)
    }

    private static func mergedCorrections(
        base: HijriCorrections, mine: HijriCorrections, theirs: HijriCorrections
    ) -> [HijriCorrection] {
        func byMonth(_ set: HijriCorrections) -> [[Int]: HijriCorrection] {
            Dictionary(set.all.map { ([$0.year, $0.month], $0) }, uniquingKeysWith: { first, _ in first })
        }
        let (baseMonths, mineMonths) = (byMonth(base), byMonth(mine))
        var result = byMonth(theirs)
        for month in Set(baseMonths.keys).union(mineMonths.keys) where mineMonths[month] != baseMonths[month] {
            result[month] = mineMonths[month]
        }
        return result.values.sorted { ($0.year, $0.month) < ($1.year, $1.month) }
    }
}
