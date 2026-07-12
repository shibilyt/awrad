import Foundation

enum AwradLocalizer {
    static func localized(_ key: String, language: AppLanguage) -> String {
        bundle(for: language).localizedString(forKey: key, value: key, table: nil)
    }

    static func format(_ key: String, language: AppLanguage, _ arguments: CVarArg...) -> String {
        let format = localized(key, language: language)
        return String(
            format: format,
            locale: Locale(identifier: language.localeIdentifier),
            arguments: arguments
        )
    }

    static func formattedTime(_ date: Date, language: AppLanguage) -> String {
        timeFormatter(language: language).string(from: date)
    }

    static func gregorianDate(_ date: Date, language: AppLanguage) -> String {
        gregorianDateFormatter.string(from: date)
    }

    static func hijriDate(_ date: Date, language: AppLanguage) -> String {
        var calendar = Calendar(identifier: .islamicUmmAlQura)
        calendar.timeZone = .current
        let components = calendar.dateComponents([.day, .month, .year], from: date)
        guard
            let day = components.day,
            let month = components.month,
            let year = components.year,
            hijriMonthNames.indices.contains(month - 1)
        else {
            return ""
        }
        return "\(day) \(hijriMonthNames[month - 1]) \(year) AH"
    }

    static func countdown(from now: Date, to target: Date, language: AppLanguage) -> String {
        let diff = max(Int(target.timeIntervalSince(now) / 60), 0)
        let hours = diff / 60
        let minutes = diff % 60
        return hours > 0
            ? format("in %dh%dm", language: language, hours, minutes)
            : format("in %dm", language: language, minutes)
    }

    static func selectedCount(_ count: Int, language: AppLanguage) -> String {
        format("%d selected", language: language, count)
    }

    static func activeCount(_ count: Int, language: AppLanguage) -> String {
        format("%d active", language: language, count)
    }

    static func dueCount(_ count: Int, language: AppLanguage) -> String {
        format("%d due", language: language, count)
    }

    static func itemCount(_ count: Int, language: AppLanguage) -> String {
        format("%d items", language: language, count)
    }

    static func dhikrCount(_ count: Int, language: AppLanguage) -> String {
        format("%d dhikrs", language: language, count)
    }

    static func collectionCount(_ count: Int, language: AppLanguage) -> String {
        format("%d collections", language: language, count)
    }

    static func readingProgress(completed: Int, total: Int, language: AppLanguage) -> String {
        format("%d of %d read", language: language, completed, total)
    }

    static func wirdStreak(_ count: Int, language: AppLanguage) -> String {
        format("%d day streak", language: language, count)
    }

    private static func bundle(for language: AppLanguage) -> Bundle {
        guard let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }

    private static func timeFormatter(language: AppLanguage) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.localeIdentifier)
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }

    private static let hijriMonthNames = [
        "Muharram", "Safar", "Rabi' al-Awwal", "Rabi' al-Thani",
        "Jumada al-Ula", "Jumada al-Thani", "Rajab", "Sha'ban",
        "Ramadan", "Shawwal", "Dhul Qa'dah", "Dhul Hijjah"
    ]

    private static let gregorianDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter
    }()
}
