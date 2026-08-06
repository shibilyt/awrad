import CryptoKit
import Foundation
import UserNotifications

/// iOS local notifications cannot execute app code when they fire. Desired urgency state is
/// therefore reconciled after app mutations/lifecycle work; stale pending requests are removed
/// before their triggers. A notification service extension would not change that constraint.
/// Testable delivered-notification snapshot. `UNNotification` has no public initializer.
struct DeliveredUserNotification: Sendable {
    let request: UNNotificationRequest
    let date: Date
}

@MainActor
protocol UrgencyNotificationCenter: AnyObject {
    func authorizationStatus() async throws -> UNAuthorizationStatus
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func pendingRequests() async throws -> [UNNotificationRequest]
    func deliveredNotifications() async throws -> [DeliveredUserNotification]
    func add(_ request: UNNotificationRequest) async throws
    func removePending(withIdentifiers identifiers: [String])
    func removeDelivered(withIdentifiers identifiers: [String])
}

@MainActor
final class SystemUrgencyNotificationCenter: UrgencyNotificationCenter {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) { self.center = center }
    func authorizationStatus() async throws -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        try await center.requestAuthorization(options: options)
    }
    func pendingRequests() async throws -> [UNNotificationRequest] {
        await center.pendingNotificationRequests()
    }
    func deliveredNotifications() async throws -> [DeliveredUserNotification] {
        await center.deliveredNotifications().map {
            DeliveredUserNotification(request: $0.request, date: $0.date)
        }
    }
    func add(_ request: UNNotificationRequest) async throws { try await center.add(request) }
    func removePending(withIdentifiers identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
    func removeDelivered(withIdentifiers identifiers: [String]) {
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }
}

struct UrgencyDeliveredStage: Codable, Hashable {
    let identity: String
    let deliveredAtMillis: Int64
    let expiryMillis: Int64?
}

@MainActor
protocol UrgencyDeliveredLedger: AnyObject {
    func load() throws -> Set<UrgencyDeliveredStage>
    func save(_ stages: Set<UrgencyDeliveredStage>) throws
}

@MainActor
final class InMemoryUrgencyDeliveredLedger: UrgencyDeliveredLedger {
    private var stages: Set<UrgencyDeliveredStage> = []
    func load() throws -> Set<UrgencyDeliveredStage> { stages }
    func save(_ stages: Set<UrgencyDeliveredStage>) throws { self.stages = stages }
}

/// Versioned JSON in the existing App Group defaults. Bad records are removed, never treated as
/// delivered; a corrupt container remains observable to the caller instead of silently resetting.
@MainActor
final class AppGroupUrgencyDeliveredLedger: UrgencyDeliveredLedger {
    private static let key = "AwradUrgencyDeliveredLedger.v1"
    private let defaults: UserDefaults
    init(defaults: UserDefaults) { self.defaults = defaults }

    func load() throws -> Set<UrgencyDeliveredStage> {
        guard let data = defaults.data(forKey: Self.key) else { return [] }
        let envelope: Envelope
        do { envelope = try JSONDecoder().decode(Envelope.self, from: data) }
        catch { defaults.removeObject(forKey: Self.key); throw error }
        guard envelope.version == 1 else {
            defaults.removeObject(forKey: Self.key)
            throw UrgencyNotificationError.unsupportedLedgerVersion
        }
        let valid = Set(envelope.stages.filter { $0.deliveredAtMillis >= 0 && UrgencyNotificationMetadata.validatedIdentity($0.identity) != nil })
        if valid.count != envelope.stages.count { try save(valid) }
        return valid
    }

    func save(_ stages: Set<UrgencyDeliveredStage>) throws {
        let envelope = Envelope(version: 1, stages: stages.sorted { $0.identity < $1.identity })
        defaults.set(try JSONEncoder().encode(envelope), forKey: Self.key)
    }

    private struct Envelope: Codable { let version: Int; let stages: [UrgencyDeliveredStage] }
}

enum UrgencyNotificationError: Error, Equatable {
    case duplicateDesiredIdentity
    case invalidDesiredRecord
    case unsupportedLedgerVersion
}

enum UrgencyNotificationMetadata {
    static let identity = "awrad.urgency.identity"
    static let kind = "awrad.urgency.kind"
    static let goalID = "awrad.urgency.goal_id"
    static let slotID = "awrad.urgency.slot_id"
    static let scope = "awrad.urgency.scope"
    static let triggerMillis = "awrad.urgency.trigger_ms"
    static let expiryMillis = "awrad.urgency.expiry_ms"
    static let format = "awrad.urgency.format"
    static let contentFingerprint = "awrad.urgency.content_fingerprint"
    static let contentFingerprintVersion = "awrad.urgency.content_fingerprint_version"
    static let version = 1
    static let currentContentFingerprintVersion = 3
    static let prefix = "awrad.notification/1/"

    static func decodedIdentity(_ value: String) -> DecodedUrgencyIdentity? {
        guard value.hasPrefix(prefix),
              let data = decodeBase64URL(String(value.dropFirst(prefix.count))),
              data.count > 1,
              data[data.startIndex] == UInt8(version) else { return nil }
        var cursor = data.index(after: data.startIndex)
        guard let goal = readField(data, cursor: &cursor),
              let scope = readField(data, cursor: &cursor),
              let slot = readField(data, cursor: &cursor),
              let kind = readField(data, cursor: &cursor),
              cursor == data.endIndex,
              let goalData = goal,
              let goalText = String(data: goalData, encoding: .utf8),
              UUID(uuidString: goalText) != nil,
              scope != nil,
              let kindData = kind,
              let kindText = String(data: kindData, encoding: .utf8),
              NotificationNudgeKind(rawValue: kindText) != nil else { return nil }
        if let slot {
            guard let slotText = String(data: slot, encoding: .utf8),
                  UUID(uuidString: slotText) != nil else { return nil }
        }
        return DecodedUrgencyIdentity(
            canonicalKey: value,
            goalID: UUID(uuidString: goalText)!,
            scope: String(data: scope!, encoding: .utf8)!,
            slotID: slot.flatMap { String(data: $0, encoding: .utf8).flatMap(UUID.init(uuidString:)) },
            kind: NotificationNudgeKind(rawValue: kindText)!
        )
    }

    static func validatedIdentity(_ value: String) -> String? { decodedIdentity(value)?.canonicalKey }

    private static func decodeBase64URL(_ payload: String) -> Data? {
        guard !payload.isEmpty, payload.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }) else { return nil }
        let base64 = payload.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let padding = String(repeating: "=", count: (4 - base64.count % 4) % 4)
        return Data(base64Encoded: base64 + padding)
    }

    private static func readField(_ data: Data, cursor: inout Data.Index) -> Data?? {
        guard data.distance(from: cursor, to: data.endIndex) >= 4 else { return nil }
        let lengthData = data[cursor..<data.index(cursor, offsetBy: 4)]
        cursor = data.index(cursor, offsetBy: 4)
        let length = lengthData.reduce(Int32(0)) { ($0 << 8) | Int32($1) }
        if length == -1 { return .some(nil) }
        guard length >= 0, data.distance(from: cursor, to: data.endIndex) >= Int(length) else { return nil }
        let end = data.index(cursor, offsetBy: Int(length))
        defer { cursor = end }
        return Data(data[cursor..<end])
    }

    static func parse(_ request: UNNotificationRequest) -> ParsedUrgencyRequest? {
        guard let decoded = decodedIdentity(request.identifier),
              let canonical = request.content.userInfo[identity] as? String,
              canonical == request.identifier,
              let kind = request.content.userInfo[kind] as? String,
              NotificationNudgeKind(rawValue: kind) == decoded.kind,
              let goal = request.content.userInfo[goalID] as? String, UUID(uuidString: goal) == decoded.goalID,
              let scope = request.content.userInfo[scope] as? String, scope == decoded.scope,
              let format = request.content.userInfo[format] as? Int, format == version,
              let trigger = request.content.userInfo[triggerMillis] as? Int64,
              let expiry = request.content.userInfo[expiryMillis] as? Int64,
              let fingerprintVersion = request.content.userInfo[contentFingerprintVersion] as? Int,
              fingerprintVersion == currentContentFingerprintVersion,
              let fingerprint = request.content.userInfo[contentFingerprint] as? String,
              isValidContentFingerprint(fingerprint),
              trigger >= 0, expiry > trigger else { return nil }
        let metadataSlot = request.content.userInfo[slotID] as? String
        guard metadataSlot.flatMap(UUID.init(uuidString:)) == decoded.slotID,
              (decoded.slotID == nil) == (metadataSlot == nil),
              fingerprint == UrgencyNotificationRequestFactory.contentFingerprint(for: request.content) else {
            return nil
        }
        return ParsedUrgencyRequest(
            identity: canonical,
            triggerMillis: trigger,
            expiryMillis: expiry,
            contentFingerprint: fingerprint
        )
    }

    private static func isValidContentFingerprint(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy { $0.isASCII && ($0.isNumber || ("a"..."f").contains($0)) }
    }
}

struct DecodedUrgencyIdentity: Hashable {
    let canonicalKey: String
    let goalID: UUID
    let scope: String
    let slotID: UUID?
    let kind: NotificationNudgeKind
}

struct ParsedUrgencyRequest: Hashable {
    let identity: String
    let triggerMillis: Int64
    let expiryMillis: Int64
    let contentFingerprint: String
}

struct UrgencyReconciliationOutcome: Equatable {
    var scheduled: [String] = []
    var replaced: [String] = []
    var removed: [String] = []
    var unchanged: [String] = []
    var deliveredSuppressed: [String] = []
    var malformedRemoved: [String] = []
    var capacityDropped: [String] = []
}

enum UrgencyReconciliationResult: Equatable {
    case reconciled(UrgencyReconciliationOutcome)
    case disabledBySystem
    case authorizationNotDetermined
    case failed(String)
}

enum UrgencyDeliveredCleanupResult: Equatable {
    case removed
    case failed(String)
}

@MainActor
final class UrgencyNotificationReconciler {
    private let center: any UrgencyNotificationCenter
    private let ledger: any UrgencyDeliveredLedger
    private let maximumPendingRequests: Int
    private static let retentionMillis: Int64 = 48 * 60 * 60 * 1_000

    init(
        center: any UrgencyNotificationCenter,
        ledger: any UrgencyDeliveredLedger,
        maximumPendingRequests: Int = 64
    ) {
        self.center = center
        self.ledger = ledger
        self.maximumPendingRequests = max(maximumPendingRequests, 0)
    }

    func reconcile(desired: [PlannedNotificationNudge], now: Date) async -> UrgencyReconciliationResult {
        do {
            let nowMillis = try requiredMillis(now)
            let desiredByID = try index(desired, nowMillis: nowMillis)
            let status = try await center.authorizationStatus()
            let pending = try await center.pendingRequests()
            let owned = pending.filter { $0.identifier.hasPrefix(UrgencyNotificationMetadata.prefix) }
            switch status {
            case .denied:
                center.removePending(withIdentifiers: owned.map(\.identifier).sorted())
                return .disabledBySystem
            case .authorized, .provisional, .ephemeral:
                break
            case .notDetermined:
                return .authorizationNotDetermined
            @unknown default:
                return .failed("Unsupported notification authorization state")
            }

            var ledgerStages = try ledger.load()
            for notification in try await center.deliveredNotifications() {
                guard let parsed = UrgencyNotificationMetadata.parse(notification.request) else { continue }
                let delivered = try requiredMillis(notification.date)
                ledgerStages.insert(
                    .init(
                        identity: parsed.identity,
                        deliveredAtMillis: delivered,
                        expiryMillis: parsed.expiryMillis
                    )
                )
            }
            ledgerStages = prune(ledgerStages, nowMillis: nowMillis)
            try ledger.save(ledgerStages)
            let delivered = Set(ledgerStages.map(\.identity))

            var result = UrgencyReconciliationOutcome()
            result.deliveredSuppressed = desiredByID.keys.filter { delivered.contains($0) }.sorted()
            let active = desiredByID.filter { !delivered.contains($0.key) }
            let parsed = Dictionary(uniqueKeysWithValues: owned.compactMap { request in
                UrgencyNotificationMetadata.parse(request).map { (request.identifier, $0) }
            })
            let malformedIDs = Set(owned.filter { parsed[$0.identifier] == nil }.map(\.identifier))

            let nonEngineCount = pending.count - owned.count
            let available = max(maximumPendingRequests - nonEngineCount, 0)
            let selected = active.values.sorted { ($0.record.triggerMillis, $0.record.identity.canonicalKey) < ($1.record.triggerMillis, $1.record.identity.canonicalKey) }
                .prefix(available)
            let selectedIDs = Set(selected.map { $0.record.identity.canonicalKey })
            result.capacityDropped = active.keys.filter { !selectedIDs.contains($0) }.sorted()
            let selectedByID = Dictionary(uniqueKeysWithValues: selected.map { ($0.record.identity.canonicalKey, $0) })
            // Invalid and obsolete engine requests are safe capacity recovery. Valid requests
            // selected for replacement remain until their same-identifier add succeeds.
            let malformed = malformedIDs.filter { selectedByID[$0] == nil }.sorted()
            let stale = parsed.keys.filter { selectedByID[$0] == nil }.sorted()
            center.removePending(withIdentifiers: stale + malformed)
            result.removed = stale
            result.malformedRemoved = malformed

            for identifier in selectedByID.keys.sorted() {
                guard let plan = selectedByID[identifier] else { continue }
                let desiredRequest = try UrgencyNotificationRequestFactory.make(plan: plan, nowMillis: nowMillis)
                let desiredFingerprint = try requiredContentFingerprint(from: desiredRequest)
                if let existing = parsed[identifier],
                   existing.triggerMillis == plan.record.triggerMillis,
                   existing.expiryMillis == plan.record.expiryMillis,
                   existing.contentFingerprint == desiredFingerprint {
                    result.unchanged.append(identifier)
                    continue
                }
                if parsed[identifier] != nil || malformedIDs.contains(identifier) {
                    result.replaced.append(identifier)
                } else {
                    result.scheduled.append(identifier)
                }
                try await center.add(desiredRequest)
            }
            // Adds replace equal identifiers atomically; a failed later add leaves every valid
            // changed replacement intact and an idempotent retry converges.
            return .reconciled(result)
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// Delivered records remain in the ledger as tombstones to suppress duplicate stages.
    /// Only engine-owned delivered requests are ever removed from Notification Center.
    func removeDelivered(
        goalIDs: Set<AwradID>,
        all: Bool = false
    ) async -> UrgencyDeliveredCleanupResult {
        do {
            let identifiers = try await center.deliveredNotifications().compactMap { notification -> String? in
                guard let decoded = UrgencyNotificationMetadata.decodedIdentity(notification.request.identifier),
                      all || goalIDs.contains(decoded.goalID) else { return nil }
                return notification.request.identifier
            }
            center.removeDelivered(withIdentifiers: identifiers.sorted())
            return .removed
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    private func index(_ desired: [PlannedNotificationNudge], nowMillis: Int64) throws -> [String: PlannedNotificationNudge] {
        var values: [String: PlannedNotificationNudge] = [:]
        for plan in desired {
            let record = plan.record
            guard record.triggerMillis > nowMillis, record.expiryMillis > record.triggerMillis, record.expiryMillis > nowMillis else {
                throw UrgencyNotificationError.invalidDesiredRecord
            }
            guard values[record.identity.canonicalKey] == nil else { throw UrgencyNotificationError.duplicateDesiredIdentity }
            values[record.identity.canonicalKey] = plan
        }
        return values
    }

    private func requiredMillis(_ date: Date) throws -> Int64 {
        guard let value = EpochMilliseconds.floor(date) else { throw UrgencyNotificationError.invalidDesiredRecord }
        return value
    }

    private func requiredContentFingerprint(from request: UNNotificationRequest) throws -> String {
        guard let fingerprint = UrgencyNotificationMetadata.parse(request)?.contentFingerprint else {
            throw UrgencyNotificationError.invalidDesiredRecord
        }
        return fingerprint
    }

    private func prune(_ stages: Set<UrgencyDeliveredStage>, nowMillis: Int64) -> Set<UrgencyDeliveredStage> {
        let cutoff = nowMillis.subtractingReportingOverflow(Self.retentionMillis)
        return Set(stages.filter { stage in
            let oldEnough = cutoff.overflow ? false : stage.deliveredAtMillis <= cutoff.partialValue
            let expired = stage.expiryMillis.map { $0 <= nowMillis } ?? true
            return !(oldEnough && expired)
        })
    }
}

enum UrgencyNotificationRequestFactory {
    static func make(plan: PlannedNotificationNudge, nowMillis: Int64) throws -> UNNotificationRequest {
        let trigger = plan.record.triggerMillis
        let intervalMillis = trigger.subtractingReportingOverflow(nowMillis)
        guard !intervalMillis.overflow, intervalMillis.partialValue >= 1_000 else {
            throw UrgencyNotificationError.invalidDesiredRecord
        }
        let content = UNMutableNotificationContent()
        content.title = plan.goalName.isEmpty ? "Awrad" : plan.goalName
        content.body = UrgencyNotificationCopy.body(for: plan)
        content.sound = .default
        content.categoryIdentifier = "awrad.goal.reminder"
        content.threadIdentifier = "awrad.urgency.\(plan.goalID.uuidString.lowercased())"
        content.interruptionLevel = .active
        var metadata: [AnyHashable: Any] = [
            UrgencyNotificationMetadata.identity: plan.record.identity.canonicalKey,
            UrgencyNotificationMetadata.kind: plan.record.identity.key.kind.rawValue,
            UrgencyNotificationMetadata.goalID: plan.goalID.uuidString.lowercased(),
            UrgencyNotificationMetadata.scope: plan.record.identity.key.scope,
            UrgencyNotificationMetadata.triggerMillis: plan.record.triggerMillis,
            UrgencyNotificationMetadata.expiryMillis: plan.record.expiryMillis,
            UrgencyNotificationMetadata.format: UrgencyNotificationMetadata.version,
            UrgencyNotificationMetadata.contentFingerprintVersion: UrgencyNotificationMetadata.currentContentFingerprintVersion
        ]
        if let slotID = plan.slotID {
            metadata[UrgencyNotificationMetadata.slotID] = slotID.uuidString.lowercased()
        }
        content.userInfo = metadata
        guard let fingerprint = contentFingerprint(for: content) else {
            throw UrgencyNotificationError.invalidDesiredRecord
        }
        metadata[UrgencyNotificationMetadata.contentFingerprint] = fingerprint
        content.userInfo = metadata
        return UNNotificationRequest(
            identifier: plan.record.identity.requestIdentifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: Double(intervalMillis.partialValue) / 1_000, repeats: false)
        )
    }

    static func contentFingerprint(for content: UNNotificationContent) -> String? {
        var encoded = Data()
        append("urgency-content/v3", to: &encoded)
        guard append(content.title, named: "title", to: &encoded),
              append(content.subtitle, named: "subtitle", to: &encoded),
              append(content.body, named: "body", to: &encoded),
              append(content.categoryIdentifier, named: "category", to: &encoded),
              append(content.threadIdentifier, named: "thread", to: &encoded),
              append(sound: content.sound, to: &encoded),
              append(content.badge, named: "badge", to: &encoded),
              append(content.launchImageName, named: "launch-image", to: &encoded),
              append(content.targetContentIdentifier, named: "target-content", to: &encoded),
              append(content.summaryArgument, named: "summary-argument", to: &encoded),
              append(content.summaryArgumentCount, named: "summary-argument-count", to: &encoded),
              append(content.interruptionLevel.rawValue, named: "interruption-level", to: &encoded),
              append(content.relevanceScore.bitPattern, named: "relevance-score", to: &encoded),
              append(userInfo: content.userInfo, to: &encoded),
              append(attachments: content.attachments, to: &encoded) else {
            return nil
        }
        return SHA256.hash(data: encoded).map { String(format: "%02x", $0) }.joined()
    }

    private static func append(sound: UNNotificationSound?, to data: inout Data) -> Bool {
        guard let sound else {
            append("sound:none", to: &data)
            return true
        }
        guard sound.isEqual(UNNotificationSound.default) else { return false }
        append("sound:default", to: &data)
        return true
    }

    private static func append<T: FixedWidthInteger>(_ value: T, named name: String, to data: inout Data) -> Bool {
        append(name, to: &data)
        var value = value.bigEndian
        withUnsafeBytes(of: &value) { append(Data($0), to: &data) }
        return true
    }

    private static func append(_ value: String?, named name: String, to data: inout Data) -> Bool {
        append(name, to: &data)
        guard let value else {
            append("nil", to: &data)
            return true
        }
        append("string", to: &data)
        append(value, to: &data)
        return true
    }

    private static func append(_ value: NSNumber?, named name: String, to data: inout Data) -> Bool {
        append(name, to: &data)
        guard let value else {
            append("nil", to: &data)
            return true
        }
        return appendPropertyList(value, to: &data)
    }

    private static func append(userInfo: [AnyHashable: Any], to data: inout Data) -> Bool {
        var filtered: [String: Any] = [:]
        for (key, value) in userInfo {
            guard let key = key as? String else { return false }
            if key != UrgencyNotificationMetadata.contentFingerprint {
                filtered[key] = value
            }
        }
        append("user-info", to: &data)
        return appendPropertyList(filtered, to: &data)
    }

    private static func append(attachments: [UNNotificationAttachment], to data: inout Data) -> Bool {
        var canonical: [Data] = []
        for attachment in attachments {
            var encoded = Data()
            append("attachment/v1", to: &encoded)
            append(attachment.identifier, to: &encoded)
            append(attachment.url.absoluteString, to: &encoded)
            append(attachment.type, to: &encoded)
            canonical.append(encoded)
        }
        canonical.sort { $0.lexicographicallyPrecedes($1) }
        append("attachments", to: &data)
        append(UInt64(canonical.count), named: "count", to: &data)
        canonical.forEach { append($0, to: &data) }
        return true
    }

    private static func appendPropertyList(_ value: Any, to data: inout Data) -> Bool {
        switch value {
        case let value as String:
            append("string", to: &data)
            append(value, to: &data)
        case let value as Data:
            append("data", to: &data)
            append(value, to: &data)
        case let value as Date:
            append("date", to: &data)
            append(value.timeIntervalSinceReferenceDate.bitPattern, named: "seconds", to: &data)
        case let value as [Any]:
            append("array", to: &data)
            append(UInt64(value.count), named: "count", to: &data)
            for element in value where !appendPropertyList(element, to: &data) {
                return false
            }
        case let value as [String: Any]:
            append("dictionary", to: &data)
            for key in value.keys.sorted() {
                append(key, to: &data)
                guard let entry = value[key], appendPropertyList(entry, to: &data) else { return false }
            }
        case let value as [AnyHashable: Any]:
            var stringKeyed: [String: Any] = [:]
            for (key, entry) in value {
                guard let key = key as? String else { return false }
                stringKeyed[key] = entry
            }
            return appendPropertyList(stringKeyed, to: &data)
        default:
            return appendScalarNumber(value, to: &data)
        }
        return true
    }

    /// Canonicalizes notification property-list numbers losslessly.
    /// Uses exact dynamic Swift type identity when `UNNotificationContent` preserves it, then
    /// CFBoolean / CFNumber `objCType` identity. Never uses `stringValue` alone.
    private static func appendScalarNumber(_ value: Any, to data: inout Data) -> Bool {
        let dynamicType = type(of: value)
        if dynamicType == Bool.self {
            return appendBoolean(value as! Bool, to: &data)
        }
        if dynamicType == Int.self {
            return appendTypedInteger(kind: "swift-Int", signed: Int64(value as! Int), to: &data)
        }
        if dynamicType == UInt.self {
            return appendTypedUnsignedInteger(kind: "swift-UInt", value: UInt64(value as! UInt), to: &data)
        }
        if dynamicType == Int8.self {
            return appendTypedInteger(kind: "swift-Int8", signed: Int64(value as! Int8), to: &data)
        }
        if dynamicType == UInt8.self {
            return appendTypedUnsignedInteger(kind: "swift-UInt8", value: UInt64(value as! UInt8), to: &data)
        }
        if dynamicType == Int16.self {
            return appendTypedInteger(kind: "swift-Int16", signed: Int64(value as! Int16), to: &data)
        }
        if dynamicType == UInt16.self {
            return appendTypedUnsignedInteger(kind: "swift-UInt16", value: UInt64(value as! UInt16), to: &data)
        }
        if dynamicType == Int32.self {
            return appendTypedInteger(kind: "swift-Int32", signed: Int64(value as! Int32), to: &data)
        }
        if dynamicType == UInt32.self {
            return appendTypedUnsignedInteger(kind: "swift-UInt32", value: UInt64(value as! UInt32), to: &data)
        }
        if dynamicType == Int64.self {
            return appendTypedInteger(kind: "swift-Int64", signed: value as! Int64, to: &data)
        }
        if dynamicType == UInt64.self {
            return appendTypedUnsignedInteger(kind: "swift-UInt64", value: value as! UInt64, to: &data)
        }
        if dynamicType == Float.self {
            return appendTypedFloat(kind: "swift-Float", bits: (value as! Float).bitPattern, to: &data)
        }
        if dynamicType == Double.self {
            return appendTypedFloat(kind: "swift-Double", bits: (value as! Double).bitPattern, to: &data)
        }

        guard let number = value as? NSNumber else { return false }
        // NSDecimalNumber shares CFNumber's type ID but is not a lossless notification scalar.
        if number is NSDecimalNumber { return false }

        let typeID = CFGetTypeID(number)
        if typeID == CFBooleanGetTypeID() {
            return appendBoolean(number.boolValue, to: &data)
        }
        guard typeID == CFNumberGetTypeID() else { return false }

        let objCType = String(cString: number.objCType)
        switch objCType {
        case "c", "s", "i", "l", "q":
            return appendTypedInteger(kind: "objc-int:\(objCType)", signed: number.int64Value, to: &data)
        case "C", "S", "I", "L", "Q":
            return appendTypedUnsignedInteger(kind: "objc-uint:\(objCType)", value: number.uint64Value, to: &data)
        case "f":
            return appendTypedFloat(kind: "objc-float", bits: number.floatValue.bitPattern, to: &data)
        case "d":
            return appendTypedFloat(kind: "objc-double", bits: number.doubleValue.bitPattern, to: &data)
        default:
            return false
        }
    }

    private static func appendBoolean(_ value: Bool, to data: inout Data) -> Bool {
        append("number", to: &data)
        append("bool", to: &data)
        append(value ? "true" : "false", to: &data)
        return true
    }

    private static func appendTypedInteger(kind: String, signed value: Int64, to data: inout Data) -> Bool {
        append("number", to: &data)
        append(kind, to: &data)
        return append(value, named: "value", to: &data)
    }

    private static func appendTypedUnsignedInteger(kind: String, value: UInt64, to data: inout Data) -> Bool {
        append("number", to: &data)
        append(kind, to: &data)
        return append(value, named: "value", to: &data)
    }

    private static func appendTypedFloat<Bits: FixedWidthInteger>(
        kind: String,
        bits: Bits,
        to data: inout Data
    ) -> Bool {
        append("number", to: &data)
        append(kind, to: &data)
        return append(bits, named: "bits", to: &data)
    }

    private static func append(_ value: String, to data: inout Data) {
        let bytes = Data(value.utf8)
        var length = UInt64(bytes.count).bigEndian
        withUnsafeBytes(of: &length) { data.append(contentsOf: $0) }
        data.append(bytes)
    }

    private static func append(_ value: Data, to data: inout Data) {
        var length = UInt64(value.count).bigEndian
        withUnsafeBytes(of: &length) { data.append(contentsOf: $0) }
        data.append(value)
    }
}

enum UrgencyNotificationCopy {
    static func body(for plan: PlannedNotificationNudge) -> String {
        let language = plan.language
        let untilExpiry = plan.record.expiryMillis.subtractingReportingOverflow(plan.record.triggerMillis)
        let duration = untilExpiry.overflow ? "" : UrgencyDurationFormatter.format(milliseconds: untilExpiry.partialValue, language: language)
        if plan.record.identity.key.kind == .streakGuardian {
            return AwradLocalizer.format("urgency.guardian", language: language, duration)
        }
        if plan.slotType != nil {
            return AwradLocalizer.format("urgency.slot", language: language, duration)
        }
        guard let remaining = plan.remaining else {
            return AwradLocalizer.localized("urgency.generic", language: language)
        }
        return AwradLocalizer.format("urgency.remaining", language: language, remaining)
    }
}

enum UrgencyDurationFormatter {
    static func format(milliseconds: Int64, language: AppLanguage) -> String {
        let seconds = max(milliseconds / 1_000, 0)
        if seconds < 60 { return AwradLocalizer.localized("urgency.duration.less_than_minute", language: language) }
        let units: [(Int64, String)] = [(86_400, "day"), (3_600, "hour"), (60, "minute")]
        var remainder = seconds
        var parts: [String] = []
        for (size, key) in units where parts.count < 2 {
            let value = remainder / size
            guard value > 0 else { continue }
            parts.append(AwradLocalizer.format("urgency.duration.\(key)", language: language, value))
            remainder %= size
        }
        return parts.joined(separator: " ")
    }
}
