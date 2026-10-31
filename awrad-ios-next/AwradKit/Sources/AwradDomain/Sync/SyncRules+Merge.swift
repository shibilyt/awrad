import Foundation

// "Add to my account" into an account's existing profile (contracts/sync/v1 README "Profiles",
// profile_switch.json `merge` and `merged_data`).

extension SyncRules {
    /// Merges an anonymous profile's data into an account's profile, queuing every merged entity
    /// as a put in `target`:
    ///
    /// - a tag whose normalized name the account already has folds onto the account's tag (nothing
    ///   queued); any other tag is added;
    /// - custom dhikrs are added;
    /// - a personal record both profiles have gets the union of their tags: the account's first, in
    ///   their order, then the anonymous-only ones, without repeats after folding and capped at 20,
    ///   keeping the account's. It's queued only when that changes it. Records only the anonymous
    ///   profile has are added with their folded tags.
    ///
    /// - goals keep their IDs and are added; the account profile's goal order (when it has one)
    ///   gets the anonymous goals it doesn't name appended, in the anonymous profile's order.
    ///
    /// Tags are queued first, then custom dhikrs, then personal records (shared ones first), then
    /// goals and the goal order, so each command's references exist on the server before it arrives.
    public static func merge(_ source: some SyncLocalState, into target: inout some SyncLocalState) {
        let keys = source.allKeys()
        var tagsByName: [String: AwradID] = [:]
        for key in target.allKeys() where key.type == .userTag {
            if case .userTag(let tag) = target.document(key) { tagsByName[tag.normalizedName] = key.id }
        }
        var folded: [AwradID: AwradID] = [:]
        for key in keys where key.type == .userTag {
            guard case .userTag(let tag) = source.document(key) else { continue }
            if let existing = tagsByName[tag.normalizedName] {
                folded[key.id] = existing
            } else {
                tagsByName[tag.normalizedName] = key.id
                save(.put(.userTag(tag), id: key.id), queue: true, in: &target)
            }
        }
        for key in keys where key.type == .customDhikr {
            guard let document = source.document(key) else { continue }
            save(.put(document, id: key.id), queue: true, in: &target)
        }
        let records = keys.filter { $0.type == .dhikrPersonal }
        let shared = records.filter { target.document($0) != nil }
        for key in shared + records.filter({ target.document($0) == nil }) {
            guard let theirs = source.document(key)?.tagIDs else { continue }
            let mine = target.document(key)?.tagIDs
            var union = mine ?? []
            var seen = Set(union)
            for tag in theirs.map({ folded[$0] ?? $0 })
            where target.document(SyncEntityKey(.userTag, tag)) != nil && seen.insert(tag).inserted {
                union.append(tag)
            }
            union = Array(union.prefix(DhikrPersonalDocument.maxTags))
            guard union != (mine ?? []) else { continue }
            save(.put(.dhikrPersonal(DhikrPersonalDocument(tagIDs: union)), id: key.id), queue: true, in: &target)
        }
        mergeGoals(source, into: &target)
    }

    private static func mergeGoals(_ source: some SyncLocalState, into target: inout some SyncLocalState) {
        let keys = source.allKeys()
        let goals = keys.filter { $0.type == .goal }
        for key in goals {
            guard let document = source.document(key) else { continue }
            save(.put(document, id: key.id), queue: true, in: &target)
        }
        guard let orderKey = target.allKeys().first(where: { $0.type == .goalOrder }),
            let accountOrder = target.document(orderKey)?.goalOrder
        else { return }
        let named = keys.first { $0.type == .goalOrder }.flatMap { source.document($0)?.goalOrder?.goalIDs } ?? []
        let anonymous = named.filter { goals.contains(SyncEntityKey(.goal, $0)) } + goals.map(\.id)
        var ids = accountOrder.goalIDs
        for id in anonymous where !ids.contains(id) { ids.append(id) }
        guard ids != accountOrder.goalIDs else { return }
        save(.put(.goalOrder(GoalOrder(goalIDs: ids)), id: orderKey.id), queue: true, in: &target)
    }
}
