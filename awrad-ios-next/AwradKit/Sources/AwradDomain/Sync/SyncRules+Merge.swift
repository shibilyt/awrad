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
    /// Tags are queued first, then custom dhikrs, then personal records (shared ones first), so
    /// each command's references exist on the server before it arrives.
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
    }
}
