import Foundation

extension PersonalContent {
    /// What the screens show of a profile's sync state: custom dhikrs and tags by name (never by
    /// an ID's time, root ADR-2026-10-28), personal records with tags, open conflicts.
    public init(state: InMemorySyncState, notices: [SyncNotice] = []) {
        var dhikrs: [CustomDhikr] = []
        var tags: [UserTag] = []
        var tagsByDhikr: [AwradID: [AwradID]] = [:]
        for (key, document) in state.documents {
            switch document {
            case .customDhikr(let custom): dhikrs.append(CustomDhikr(id: key.id, document: custom))
            case .userTag(let tag):
                tags.append(UserTag(id: key.id, name: tag.name, normalizedName: tag.normalizedName))
            case .dhikrPersonal(let personal) where !personal.tagIDs.isEmpty: tagsByDhikr[key.id] = personal.tagIDs
            case .dhikrPersonal: break
            }
        }
        self.init(
            customDhikrs: dhikrs.sorted { ($0.sortName, $0.id) < ($1.sortName, $1.id) },
            tags: tags.sorted { ($0.name.localizedLowercase, $0.id) < ($1.name.localizedLowercase, $1.id) },
            tagsByDhikr: tagsByDhikr, conflicts: state.conflicts.keys.sorted().compactMap { state.conflicts[$0] },
            notices: notices)
    }
}

extension CustomDhikr {
    fileprivate var sortName: String { document.title.resolved(in: .en)?.localizedLowercase ?? "" }
}
