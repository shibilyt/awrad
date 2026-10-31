import AwradDomain
import Foundation

// The timeline, document, count log and goal order shapes of
// `contracts/goal-model/v1/goal-model.schema.json`, decoded into domain values. Fixture-only.

/// `$defs/version_shape`: `from` plus settings.
struct VersionShape: Decodable {
    let from: String
    let settings: SettingsShape

    private enum CodingKeys: String, CodingKey {
        case from
    }

    init(from decoder: any Decoder) throws {
        from = try decoder.container(keyedBy: CodingKeys.self).decode(String.self, forKey: .from)
        settings = try SettingsShape(from: decoder)
    }

    /// A valid version; invalid settings fail the case.
    func version() throws -> GoalVersion {
        GoalVersion(from: try FixtureValue.day(from), settings: try settings.settings())
    }
}

/// `$defs/goal_timeline` (also the timeline part of a document), possibly invalid.
struct TimelineShape: Decodable {
    struct EndedShape: Decodable {
        let on: String
        let reason: String
    }

    let createdOn: String
    let versions: [VersionShape]
    let paused: [PausedShape]
    let excused: [String]
    let ended: EndedShape?

    /// A valid timeline; an invalid one fails the case.
    func timeline() throws -> GoalTimeline {
        try construct().get()
    }

    /// The timeline through the domain's validation. A document has every version's errors plus
    /// its own; its own are checked even when a version is invalid. Throws only when the shape
    /// can't be read.
    func construct() throws -> Result<GoalTimeline, GoalValidationError> {
        let createdOn = try FixtureValue.day(createdOn)
        let constructed = try versions.map { try $0.settings.construct() }
        let versionCodes = constructed.flatMap { result -> [GoalValidationError.Code] in
            guard case .failure(let error) = result else { return [] }
            return error.codes
        }
        guard versionCodes.isEmpty else {
            let structures = try versions.map {
                (from: try FixtureValue.day($0.from), structure: try $0.settings.structure())
            }
            let codes = GoalTimeline.validationCodes(createdOn: createdOn, versions: structures)
            return .failure(GoalValidationError(codes.union(versionCodes)))
        }
        let versions = try versions.map { try $0.version() }
        let paused = try paused.map {
            PausedRange(from: try FixtureValue.day($0.from), to: try $0.to.map(FixtureValue.day))
        }
        let excused = try excused.map(FixtureValue.day)
        let ended = try ended.map {
            GoalEnding(
                on: try FixtureValue.day($0.on),
                reason: try FixtureValue.require(GoalEnding.Reason(rawValue: $0.reason), "ended reason \($0.reason)"))
        }
        return Result { () throws(GoalValidationError) in
            try GoalTimeline(createdOn: createdOn, versions: versions, paused: paused, excused: excused, ended: ended)
        }
    }
}

/// `$defs/goal_document_shape`: the timeline plus the dhikr, its snapshot, name and counts.
struct DocumentShape: Decodable {
    struct SnapshotShape: Decodable {
        let title: LanguageTextsShape
        let arabic: String
        let kind: String
    }

    let dhikrId: String
    let dhikrSnapshot: SnapshotShape
    let name: String?
    let counts: String
    let timeline: TimelineShape

    private enum CodingKeys: String, CodingKey {
        case dhikrId, dhikrSnapshot, name, counts
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        dhikrId = try values.decode(String.self, forKey: .dhikrId)
        dhikrSnapshot = try values.decode(SnapshotShape.self, forKey: .dhikrSnapshot)
        name = try values.decode(String?.self, forKey: .name)
        counts = try values.decode(String.self, forKey: .counts)
        timeline = try TimelineShape(from: decoder)
    }

    /// A valid document; an invalid one fails the case.
    func document() throws -> GoalDocument {
        let title = dhikrSnapshot.title
        let snapshot = DhikrSnapshot(
            title: LanguageTexts(en: title.en, ar: title.ar, ml: title.ml),
            arabic: dhikrSnapshot.arabic,
            kind: try FixtureValue.require(DhikrKind(rawValue: dhikrSnapshot.kind), "kind \(dhikrSnapshot.kind)"))
        return GoalDocument(
            dhikrID: try FixtureValue.id(dhikrId), dhikrSnapshot: snapshot, name: name,
            counts: try FixtureValue.require(GoalCounts(rawValue: counts), "counts \(counts)"),
            timeline: try timeline.timeline())
    }
}

/// en, ar and ml, each possibly `null`.
struct LanguageTextsShape: Decodable {
    let en: String?
    let ar: String?
    let ml: String?
}

/// `$defs/goal_input`: a lone goal or a timeline, as the timeline it stands for.
struct GoalInputShape: Decodable {
    let timeline: GoalTimeline

    private enum CodingKeys: String, CodingKey {
        case versions
    }

    init(from decoder: any Decoder) throws {
        if try decoder.container(keyedBy: CodingKeys.self).contains(.versions) {
            timeline = try TimelineShape(from: decoder).timeline()
        } else {
            timeline = GoalTimeline(try GoalShape(from: decoder).goal())
        }
    }
}

/// `$defs/count_log_entry`.
struct CountLogShape: Decodable {
    let id: String
    let dhikrId: String
    let practiceDay: String
    let sessionId: String?
    let goalId: String?
    let amount: Int64
    let countedAt: String

    func entry() throws -> CountLogEntry {
        CountLogEntry(
            id: try FixtureValue.id(id), dhikrID: try FixtureValue.id(dhikrId),
            practiceDay: try FixtureValue.day(practiceDay), sessionID: sessionId,
            goalID: try goalId.map(FixtureValue.id), amount: amount, countedAt: try FixtureValue.instant(countedAt))
    }
}

/// `$defs/goal_order_document`.
struct GoalOrderShape: Decodable {
    let goalIds: [String]

    func order() throws -> GoalOrder {
        GoalOrder(goalIDs: try goalIds.map(FixtureValue.id))
    }
}
