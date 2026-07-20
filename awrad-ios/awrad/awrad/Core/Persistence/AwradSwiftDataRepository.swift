import Foundation
import SwiftData

@MainActor
final class SwiftDataAwradRepository: AwradPersistenceRepository {
    private typealias Schema = AwradSchemaV1
    private typealias SyncSchema = AwradSchemaV2

    let modelContext: ModelContext

    init(container: ModelContainer) {
        modelContext = ModelContext(container)
        modelContext.autosaveEnabled = false
    }

    init(context: ModelContext) {
        modelContext = context
        modelContext.autosaveEnabled = false
    }

    /// Progress sync shares this repository's context so product rows, outbox
    /// receipts, entity shadows, and transfer page advancement commit as one
    /// App Group transaction. Remote application deliberately bypasses local
    /// diff generation.
    func performProgressSyncTransaction(
        _ work: (ModelContext) throws -> Void
    ) throws {
        try performTransaction(enqueueSync: false) {
            try work(modelContext)
        }
    }

    func loadState() throws -> AwradRepositoryState {
        let dhikrs = try fetchDhikrs()
        let goals = try fetchGoals()
        let countEntries = try fetchCountEntries()
        let seasonTemplates = try fetchSeasonTemplates()
        let wirds = try fetchWirds()
        let wirdSessions = try fetchWirdSessions()
        return AwradRepositoryState(
            dhikrs: dhikrs,
            goals: goals,
            countEntries: countEntries,
            seasonTemplates: seasonTemplates,
            wirds: wirds,
            wirdSessions: wirdSessions
        )
    }

    func isEmpty() throws -> Bool {
        try count(Schema.DhikrRecord.self) == 0 &&
            count(Schema.GoalRecord.self) == 0 &&
            count(Schema.GoalRecurrenceRecord.self) == 0 &&
            count(Schema.GoalRecurrenceWeekdayRecord.self) == 0 &&
            count(Schema.GoalRecurrenceMonthDayRecord.self) == 0 &&
            count(Schema.GoalRecurrenceDateRecord.self) == 0 &&
            count(Schema.GoalSlotRecord.self) == 0 &&
            count(Schema.GoalReminderRecord.self) == 0 &&
            count(Schema.SeasonTemplateRecord.self) == 0 &&
            count(Schema.SeasonTemplateDayRecord.self) == 0 &&
            count(Schema.CountEntryRecord.self) == 0 &&
            count(Schema.WirdRecord.self) == 0 &&
            count(Schema.WirdSessionRecord.self) == 0
    }

    func replaceAll(with state: AwradRepositoryState) throws {
        try AwradPersistenceValidator.validate(state: state)
        try performTransaction {
            try deleteAllRecords()
            try insert(state)
        }
    }

    func deleteAll() throws {
        try performTransaction {
            try deleteAllRecords()
        }
    }

    /// Replaces this installation's product graph without interpreting the
    /// removal as cloud mutations. Account-recovery reset uses this path to
    /// guarantee that local erasure cannot enqueue server deletes.
    func resetLocalState(with state: AwradRepositoryState) throws {
        try AwradPersistenceValidator.validate(state: state)
        try performTransaction(enqueueSync: false) {
            try deleteAllSyncRecords()
            try deleteAllRecords()
            try insert(state)
        }
    }

    // MARK: DhikrRepository

    func fetchDhikrs() throws -> [Dhikr] {
        try modelContext.fetch(FetchDescriptor<Schema.DhikrRecord>())
            .map(AwradPersistenceMapper.dhikr)
            .sorted {
                $0.sortOrder == $1.sortOrder
                    ? AwradPersistenceMapper.idString($0.id) < AwradPersistenceMapper.idString($1.id)
                    : $0.sortOrder < $1.sortOrder
            }
    }

    func saveDhikr(_ dhikr: Dhikr) throws {
        let key = dhikr.catalogKey
        if let key {
            let conflicts = try modelContext.fetch(
                FetchDescriptor<Schema.DhikrRecord>(
                    predicate: #Predicate { $0.catalogKey == key }
                )
            )
            if conflicts.contains(where: { $0.id != AwradPersistenceMapper.idString(dhikr.id) }) {
                throw AwradPersistenceError.duplicateUniqueValue(entity: "dhikr", field: "catalogKey", value: key)
            }
        }
        try performTransaction {
            try deleteDhikrRecordOnly(id: AwradPersistenceMapper.idString(dhikr.id))
            modelContext.insert(try AwradPersistenceMapper.dhikrRecord(from: dhikr))
        }
    }

    func deleteDhikr(id: AwradID) throws {
        let targetID = AwradPersistenceMapper.idString(id)
        try performTransaction {
            let goals = try modelContext.fetch(
                FetchDescriptor<Schema.GoalRecord>(predicate: #Predicate { $0.dhikrID == targetID })
            )
            for goal in goals {
                try deleteGoalRecords(id: goal.id, includingCounts: true)
            }
            try deleteDhikrRecordOnly(id: targetID)
        }
    }

    // MARK: GoalRepository

    func fetchGoals() throws -> [Goal] {
        let goalRecords = try modelContext.fetch(FetchDescriptor<Schema.GoalRecord>())
        let recurrenceByGoal = Dictionary(
            uniqueKeysWithValues: try modelContext.fetch(FetchDescriptor<Schema.GoalRecurrenceRecord>())
                .map { ($0.goalID, $0) }
        )
        let weekdays = Dictionary(
            grouping: try modelContext.fetch(FetchDescriptor<Schema.GoalRecurrenceWeekdayRecord>()),
            by: \.goalID
        )
        let monthDays = Dictionary(
            grouping: try modelContext.fetch(FetchDescriptor<Schema.GoalRecurrenceMonthDayRecord>()),
            by: \.goalID
        )
        let dates = Dictionary(
            grouping: try modelContext.fetch(FetchDescriptor<Schema.GoalRecurrenceDateRecord>()),
            by: \.goalID
        )
        let slots = Dictionary(
            grouping: try modelContext.fetch(FetchDescriptor<Schema.GoalSlotRecord>()),
            by: \.goalID
        )
        let reminders = Dictionary(
            grouping: try modelContext.fetch(FetchDescriptor<Schema.GoalReminderRecord>()),
            by: \.goalID
        )
        return try goalRecords.map { record in
            try AwradPersistenceMapper.goal(
                from: record,
                recurrence: recurrenceByGoal[record.id],
                weekdays: weekdays[record.id] ?? [],
                monthDays: monthDays[record.id] ?? [],
                dates: dates[record.id] ?? [],
                slots: slots[record.id] ?? [],
                reminders: reminders[record.id] ?? []
            )
        }.sorted { $0.createdAt == $1.createdAt ? $0.id.uuidString < $1.id.uuidString : $0.createdAt < $1.createdAt }
    }

    func fetchCountEntries() throws -> [CountEntry] {
        try modelContext.fetch(FetchDescriptor<Schema.CountEntryRecord>())
            .map(AwradPersistenceMapper.countEntry)
            .sorted {
                let left = Schema.CountEntryRecord.makeSemanticKey(
                    goalID: AwradPersistenceMapper.idString($0.goalID),
                    dateKey: $0.dateKey,
                    slotID: AwradPersistenceMapper.idString($0.slotID)
                )
                let right = Schema.CountEntryRecord.makeSemanticKey(
                    goalID: AwradPersistenceMapper.idString($1.goalID),
                    dateKey: $1.dateKey,
                    slotID: AwradPersistenceMapper.idString($1.slotID)
                )
                return left < right
            }
    }

    func fetchSeasonTemplates() throws -> [SeasonTemplateDefinition] {
        let days = Dictionary(
            grouping: try modelContext.fetch(FetchDescriptor<Schema.SeasonTemplateDayRecord>()),
            by: \.templateCode
        )
        return try modelContext.fetch(FetchDescriptor<Schema.SeasonTemplateRecord>())
            .map { try AwradPersistenceMapper.seasonTemplate(from: $0, days: days[$0.code] ?? []) }
            .sorted { $0.code < $1.code }
    }

    func saveGoal(_ goal: Goal) throws {
        let dhikrID = AwradPersistenceMapper.idString(goal.dhikrID)
        guard try modelContext.fetchCount(
            FetchDescriptor<Schema.DhikrRecord>(predicate: #Predicate { $0.id == dhikrID })
        ) == 1 else {
            throw AwradPersistenceError.missingReference(
                entity: "goal",
                id: AwradPersistenceMapper.idString(goal.id),
                reference: "dhikr \(dhikrID)"
            )
        }
        try AwradPersistenceValidator.validateGoal(goal)
        let goalID = AwradPersistenceMapper.idString(goal.id)
        let retainedSlotIDs = Set(goal.slots.map { AwradPersistenceMapper.idString($0.id) })
        let existingEntries = try modelContext.fetch(
            FetchDescriptor<Schema.CountEntryRecord>(predicate: #Predicate { $0.goalID == goalID })
        )
        if let orphan = existingEntries.first(where: { !retainedSlotIDs.contains($0.slotID) }) {
            throw AwradPersistenceError.missingReference(
                entity: "count entry",
                id: orphan.id,
                reference: "retained or archived slot \(orphan.slotID)"
            )
        }
        try performTransaction {
            try deleteGoalRecords(id: goalID, includingCounts: false)
            try insert(goal)
        }
    }

    func saveGoalAggregate(_ goal: Goal, countEntries: [CountEntry]) throws {
        let dhikrID = AwradPersistenceMapper.idString(goal.dhikrID)
        guard try modelContext.fetchCount(
            FetchDescriptor<Schema.DhikrRecord>(predicate: #Predicate { $0.id == dhikrID })
        ) == 1 else {
            throw AwradPersistenceError.missingReference(
                entity: "goal",
                id: AwradPersistenceMapper.idString(goal.id),
                reference: "dhikr \(dhikrID)"
            )
        }
        try AwradPersistenceValidator.validateGoal(goal)
        let slotIDs = Set(goal.slots.map(\.id))
        let invalidEntry = countEntries.first {
            $0.goalID != goal.id || !slotIDs.contains($0.slotID)
        }
        if let invalidEntry {
            throw AwradPersistenceError.missingReference(
                entity: "count entry",
                id: invalidEntry.id.uuidString,
                reference: "goal aggregate slot"
            )
        }
        for entry in countEntries {
            try AwradPersistenceValidator.validateCountEntry(entry)
        }
        let semanticKeys = countEntries.map {
            Schema.CountEntryRecord.makeSemanticKey(
                goalID: AwradPersistenceMapper.idString($0.goalID),
                dateKey: $0.dateKey,
                slotID: AwradPersistenceMapper.idString($0.slotID)
            )
        }
        if Set(semanticKeys).count != semanticKeys.count {
            throw AwradPersistenceError.duplicateUniqueValue(
                entity: "count entry",
                field: "goal/date/slot",
                value: AwradPersistenceMapper.idString(goal.id)
            )
        }
        try performTransaction {
            try deleteGoalRecords(id: AwradPersistenceMapper.idString(goal.id), includingCounts: true)
            try insert(goal)
            countEntries.map(AwradPersistenceMapper.countEntryRecord).forEach(modelContext.insert)
        }
    }

    func deleteGoal(id: AwradID) throws {
        try performTransaction {
            try deleteGoalRecords(id: AwradPersistenceMapper.idString(id), includingCounts: true)
        }
    }

    func saveCountEntry(_ entry: CountEntry) throws {
        try AwradPersistenceValidator.validateCountEntry(entry)
        let goalID = AwradPersistenceMapper.idString(entry.goalID)
        let slotID = AwradPersistenceMapper.idString(entry.slotID)
        guard try modelContext.fetchCount(
            FetchDescriptor<Schema.GoalRecord>(predicate: #Predicate { $0.id == goalID })
        ) == 1 else {
            throw AwradPersistenceError.missingReference(entity: "count entry", id: entry.id.uuidString, reference: "goal \(goalID)")
        }
        guard try modelContext.fetchCount(
            FetchDescriptor<Schema.GoalSlotRecord>(predicate: #Predicate { $0.id == slotID && $0.goalID == goalID })
        ) == 1 else {
            throw AwradPersistenceError.missingReference(entity: "count entry", id: entry.id.uuidString, reference: "slot \(slotID)")
        }
        let semanticKey = Schema.CountEntryRecord.makeSemanticKey(goalID: goalID, dateKey: entry.dateKey, slotID: slotID)
        try performTransaction {
            let previous = try modelContext.fetch(
                FetchDescriptor<Schema.CountEntryRecord>(predicate: #Predicate { $0.semanticKey == semanticKey })
            )
            previous.forEach(modelContext.delete)
            modelContext.insert(AwradPersistenceMapper.countEntryRecord(from: entry))
        }
    }

    func replaceSeasonTemplates(_ templates: [SeasonTemplateDefinition]) throws {
        try AwradPersistenceValidator.validateSeasonTemplates(templates)
        try performTransaction {
            try delete(Schema.SeasonTemplateDayRecord.self)
            try delete(Schema.SeasonTemplateRecord.self)
            for template in templates {
                let (record, days) = AwradPersistenceMapper.seasonRecords(from: template)
                modelContext.insert(record)
                days.forEach(modelContext.insert)
            }
        }
    }

    // MARK: WirdRepository

    func fetchWirds() throws -> [Wird] {
        try modelContext.fetch(FetchDescriptor<Schema.WirdRecord>())
            .map(AwradPersistenceMapper.wird)
            .sorted {
                $0.sortOrder == $1.sortOrder
                    ? $0.slug < $1.slug
                    : $0.sortOrder < $1.sortOrder
            }
    }

    func fetchWirdSessions() throws -> [WirdSession] {
        try modelContext.fetch(FetchDescriptor<Schema.WirdSessionRecord>())
            .map(AwradPersistenceMapper.wirdSession)
            .sorted {
                let left = Schema.WirdSessionRecord.makeSemanticKey(
                    wirdID: $0.wirdID.uuidString,
                    partID: $0.partID.uuidString,
                    occasionKey: $0.occasionKey,
                    dateKey: $0.dateKey
                )
                let right = Schema.WirdSessionRecord.makeSemanticKey(
                    wirdID: $1.wirdID.uuidString,
                    partID: $1.partID.uuidString,
                    occasionKey: $1.occasionKey,
                    dateKey: $1.dateKey
                )
                return left < right
            }
    }

    func saveWird(_ wird: Wird) throws {
        let slug = wird.slug
        let id = AwradPersistenceMapper.idString(wird.id)
        let conflicts = try modelContext.fetch(
            FetchDescriptor<Schema.WirdRecord>(predicate: #Predicate { $0.slug == slug })
        )
        if conflicts.contains(where: { $0.id != id }) {
            throw AwradPersistenceError.duplicateUniqueValue(entity: "wird", field: "slug", value: slug)
        }
        try AwradPersistenceValidator.validateWird(wird)
        let existingSessions = try fetchWirdSessions().filter { $0.wirdID == wird.id }
        for session in existingSessions {
            try AwradPersistenceValidator.validateWirdSession(session, wirds: [wird])
        }
        try performTransaction {
            let previous = try modelContext.fetch(
                FetchDescriptor<Schema.WirdRecord>(predicate: #Predicate { $0.id == id })
            )
            previous.forEach(modelContext.delete)
            modelContext.insert(try AwradPersistenceMapper.wirdRecord(from: wird))
        }
    }

    func deleteWird(id: AwradID) throws {
        let targetID = AwradPersistenceMapper.idString(id)
        try performTransaction {
            let sessions = try modelContext.fetch(
                FetchDescriptor<Schema.WirdSessionRecord>(predicate: #Predicate { $0.wirdID == targetID })
            )
            sessions.forEach(modelContext.delete)
            let wirds = try modelContext.fetch(
                FetchDescriptor<Schema.WirdRecord>(predicate: #Predicate { $0.id == targetID })
            )
            wirds.forEach(modelContext.delete)
        }
    }

    func saveWirdSession(_ session: WirdSession) throws {
        let state = try loadState()
        try AwradPersistenceValidator.validateWirdSession(session, wirds: state.wirds)
        let semanticKey = Schema.WirdSessionRecord.makeSemanticKey(
            wirdID: AwradPersistenceMapper.idString(session.wirdID),
            partID: AwradPersistenceMapper.idString(session.partID),
            occasionKey: session.occasionKey,
            dateKey: session.dateKey
        )
        try performTransaction {
            let previous = try modelContext.fetch(
                FetchDescriptor<Schema.WirdSessionRecord>(predicate: #Predicate { $0.semanticKey == semanticKey })
            )
            previous.forEach(modelContext.delete)
            modelContext.insert(try AwradPersistenceMapper.wirdSessionRecord(from: session))
        }
    }

    // MARK: Transactions and cascades

    private func performTransaction(
        enqueueSync: Bool = true,
        _ work: () throws -> Void
    ) throws {
        let previousState = enqueueSync ? try loadState() : nil
        do {
            try modelContext.transaction {
                try work()
                if let previousState {
                    try ProgressSyncLocalStore.enqueueDiff(
                        previous: previousState,
                        current: try loadState(),
                        in: modelContext
                    )
                }
                try modelContext.save()
            }
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    private func insert(_ state: AwradRepositoryState) throws {
        for dhikr in state.dhikrs {
            modelContext.insert(try AwradPersistenceMapper.dhikrRecord(from: dhikr))
        }
        for goal in state.goals {
            try insert(goal)
        }
        for entry in state.countEntries {
            modelContext.insert(AwradPersistenceMapper.countEntryRecord(from: entry))
        }
        for template in state.seasonTemplates {
            let (record, days) = AwradPersistenceMapper.seasonRecords(from: template)
            modelContext.insert(record)
            days.forEach(modelContext.insert)
        }
        for wird in state.wirds {
            modelContext.insert(try AwradPersistenceMapper.wirdRecord(from: wird))
        }
        for session in state.wirdSessions {
            modelContext.insert(try AwradPersistenceMapper.wirdSessionRecord(from: session))
        }
    }

    private func insert(_ goal: Goal) throws {
        let records = try AwradPersistenceMapper.goalRecords(from: goal)
        modelContext.insert(records.goal)
        modelContext.insert(records.recurrence)
        records.weekdays.forEach(modelContext.insert)
        records.monthDays.forEach(modelContext.insert)
        records.dates.forEach(modelContext.insert)
        records.slots.forEach(modelContext.insert)
        records.reminders.forEach(modelContext.insert)
    }

    private func deleteDhikrRecordOnly(id targetID: String) throws {
        let records = try modelContext.fetch(
            FetchDescriptor<Schema.DhikrRecord>(predicate: #Predicate { $0.id == targetID })
        )
        records.forEach(modelContext.delete)
    }

    private func deleteGoalRecords(id targetID: String, includingCounts: Bool) throws {
        try deleteMatching(Schema.GoalReminderRecord.self, predicate: #Predicate { $0.goalID == targetID })
        try deleteMatching(Schema.GoalRecurrenceWeekdayRecord.self, predicate: #Predicate { $0.goalID == targetID })
        try deleteMatching(Schema.GoalRecurrenceMonthDayRecord.self, predicate: #Predicate { $0.goalID == targetID })
        try deleteMatching(Schema.GoalRecurrenceDateRecord.self, predicate: #Predicate { $0.goalID == targetID })
        try deleteMatching(Schema.GoalRecurrenceRecord.self, predicate: #Predicate { $0.goalID == targetID })
        try deleteMatching(Schema.GoalSlotRecord.self, predicate: #Predicate { $0.goalID == targetID })
        if includingCounts {
            try deleteMatching(Schema.CountEntryRecord.self, predicate: #Predicate { $0.goalID == targetID })
        }
        try deleteMatching(Schema.GoalRecord.self, predicate: #Predicate { $0.id == targetID })
    }

    private func deleteAllRecords() throws {
        try delete(Schema.GoalReminderRecord.self)
        try delete(Schema.GoalRecurrenceWeekdayRecord.self)
        try delete(Schema.GoalRecurrenceMonthDayRecord.self)
        try delete(Schema.GoalRecurrenceDateRecord.self)
        try delete(Schema.GoalRecurrenceRecord.self)
        try delete(Schema.CountEntryRecord.self)
        try delete(Schema.GoalSlotRecord.self)
        try delete(Schema.GoalRecord.self)
        try delete(Schema.DhikrRecord.self)
        try delete(Schema.SeasonTemplateDayRecord.self)
        try delete(Schema.SeasonTemplateRecord.self)
        try delete(Schema.WirdSessionRecord.self)
        try delete(Schema.WirdRecord.self)
    }

    private func deleteAllSyncRecords() throws {
        try delete(SyncSchema.SyncOutboxRecord.self)
        try delete(SyncSchema.SyncOpenCountBatchRecord.self)
        try delete(SyncSchema.SyncEntityShadowRecord.self)
        try delete(SyncSchema.SyncCountShadowRecord.self)
        try delete(SyncSchema.SyncInboxPageRecord.self)
        try delete(SyncSchema.SyncConflictRecord.self)
        try delete(SyncSchema.SyncStateRecord.self)
    }

    private func count<T: PersistentModel>(_ type: T.Type) throws -> Int {
        try modelContext.fetchCount(FetchDescriptor<T>())
    }

    private func delete<T: PersistentModel>(_ type: T.Type) throws {
        try modelContext.fetch(FetchDescriptor<T>()).forEach(modelContext.delete)
    }

    private func deleteMatching<T: PersistentModel>(
        _ type: T.Type,
        predicate: Predicate<T>
    ) throws {
        try modelContext.fetch(FetchDescriptor<T>(predicate: predicate)).forEach(modelContext.delete)
    }
}
