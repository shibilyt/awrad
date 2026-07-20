import Foundation

struct CommunityStatsResponse: Decodable, Equatable, Sendable {
    struct DailyCount: Decodable, Equatable, Identifiable, Sendable {
        let date: String
        let approximateCount: DecimalIntegerString

        var id: String { date }

        enum CodingKeys: String, CodingKey {
            case date
            case approximateCount = "approximate_count"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            date = try container.decode(String.self, forKey: .date)
            guard Self.dateFormatter.date(from: date) != nil else {
                throw DecodingError.dataCorruptedError(
                    forKey: .date,
                    in: container,
                    debugDescription: "Expected a YYYY-MM-DD date"
                )
            }
            approximateCount = try container.decode(DecimalIntegerString.self, forKey: .approximateCount)
        }

        private static let dateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.isLenient = false
            return formatter
        }()
    }

    let asOf: Date
    let countSemantics: String
    let totalTrackedGoals: Int
    let approximateTotalCounts: DecimalIntegerString
    let approximateDhikrHours: Double
    let secondsPerCount: Int
    let dailyCounts: [DailyCount]

    enum CodingKeys: String, CodingKey {
        case asOf = "as_of"
        case countSemantics = "count_semantics"
        case totalTrackedGoals = "total_tracked_goals"
        case approximateTotalCounts = "approximate_total_counts"
        case approximateDhikrHours = "approximate_dhikr_hours"
        case secondsPerCount = "seconds_per_count"
        case dailyCounts = "daily_counts"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let timestamp = try container.decode(String.self, forKey: .asOf)
        guard let parsedDate = Self.rfc3339Formatter.date(from: timestamp)
                ?? Self.rfc3339FractionalFormatter.date(from: timestamp) else {
            throw DecodingError.dataCorruptedError(
                forKey: .asOf,
                in: container,
                debugDescription: "Expected an RFC3339 timestamp"
            )
        }
        asOf = parsedDate
        countSemantics = try container.decode(String.self, forKey: .countSemantics)
        totalTrackedGoals = try container.decode(Int.self, forKey: .totalTrackedGoals)
        approximateTotalCounts = try container.decode(DecimalIntegerString.self, forKey: .approximateTotalCounts)
        approximateDhikrHours = try container.decode(Double.self, forKey: .approximateDhikrHours)
        secondsPerCount = try container.decode(Int.self, forKey: .secondsPerCount)
        dailyCounts = try container.decode([DailyCount].self, forKey: .dailyCounts)

        guard totalTrackedGoals >= 0, approximateDhikrHours.isFinite,
              approximateDhikrHours >= 0, secondsPerCount > 0 else {
            throw DecodingError.dataCorruptedError(
                forKey: .secondsPerCount,
                in: container,
                debugDescription: "Community statistics must be nonnegative and use a positive count duration"
            )
        }
    }

    private static let rfc3339Formatter = ISO8601DateFormatter()
    private static let rfc3339FractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

struct DecimalIntegerString: Decodable, Equatable, Sendable {
    let rawValue: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        guard !value.isEmpty, value.allSatisfy(\.isNumber),
              value.unicodeScalars.allSatisfy({ $0.value >= 48 && $0.value <= 57 }) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected a nonnegative decimal integer string"
            )
        }
        let normalized = String(value.drop(while: { $0 == "0" }))
        rawValue = normalized.isEmpty ? "0" : normalized
    }

    var magnitudeForChart: Double {
        guard rawValue.count <= 308 else { return .greatestFiniteMagnitude }
        return Double(rawValue) ?? 0
    }
}
