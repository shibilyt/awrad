import AwradDomain
import Foundation

/// This module's strings, from `Resources/Localizable.xcstrings` (en, ar, ml). Each carries its
/// English default value, so `swift test` (which copies the catalog uncompiled) reads the English.
///
/// Numbers are format arguments, never digits inside a translation, so they take the locale's
/// digits. City and place names come from data and are never translated.
enum Strings {
    static let bundle = LocalizedStringResource.BundleDescription.atURL(Bundle.module.bundleURL)

    static func text(_ key: StaticString, _ english: String.LocalizationValue) -> LocalizedStringResource {
        LocalizedStringResource(key, defaultValue: english, bundle: bundle)
    }

    /// Wraps text from data in first-strong isolates, so it stays whole inside right-to-left text.
    static func isolated(_ text: String) -> String {
        "\u{2068}\(text)\u{2069}"
    }

    static let title = text("practice.title", "Practice settings")
    static let saveFailed = text("practice.save_failed", "Couldn't save the change. Try again.")
    static let ok = text("practice.ok", "OK")

    // MARK: - Today

    static let today = text("practice.today.title", "Today")
    static let maghribLabel = text("practice.today.maghrib", "Maghrib")
    static let maghribNeedsLocation = text("practice.today.maghrib_needs_location", "Choose a location to see Maghrib.")
    static let maghribNone = text("practice.today.maghrib_none", "The sun doesn't set here today.")
    static let outsideCalendar = text("practice.hijri.outside", "This date is outside the Hijri calendar.")

    /// Today's Hijri date: "14 Jumada al-Ula 1448 AH".
    static func hijriDate(_ date: HijriDate) -> LocalizedStringResource {
        let month = String(localized: monthName(date.month))
        return LocalizedStringResource(
            "practice.hijri.date", defaultValue: "\(date.day) \(month) \(date.year) AH", bundle: bundle)
    }

    /// A Hijri month: "Ramadan 1448 AH".
    static func hijriMonth(year: Int, month: Int) -> LocalizedStringResource {
        let name = String(localized: monthName(month))
        return LocalizedStringResource("practice.hijri.month_year", defaultValue: "\(name) \(year) AH", bundle: bundle)
    }

    static func monthName(_ month: Int) -> LocalizedStringResource {
        switch month {
        case 1: text("practice.hijri.month.1", "Muharram")
        case 2: text("practice.hijri.month.2", "Safar")
        case 3: text("practice.hijri.month.3", "Rabi al-Awwal")
        case 4: text("practice.hijri.month.4", "Rabi al-Thani")
        case 5: text("practice.hijri.month.5", "Jumada al-Ula")
        case 6: text("practice.hijri.month.6", "Jumada al-Akhirah")
        case 7: text("practice.hijri.month.7", "Rajab")
        case 8: text("practice.hijri.month.8", "Shaban")
        case 9: text("practice.hijri.month.9", "Ramadan")
        case 10: text("practice.hijri.month.10", "Shawwal")
        case 11: text("practice.hijri.month.11", "Dhu al-Qadah")
        default: text("practice.hijri.month.12", "Dhu al-Hijjah")
        }
    }

    // MARK: - Day reset

    static let dayReset = text("practice.day_reset.title", "New day starts at")
    static let midnight = text("practice.day_reset.midnight", "Midnight")
    static let maghrib = text("practice.day_reset.maghrib", "Maghrib")
    static let dayResetNote = text(
        "practice.day_reset.note", "With Maghrib, your day's practice counts from sunset, as the Islamic day does.")
    static let maghribWithoutLocation = text(
        "practice.day_reset.no_location",
        "Choose a location to reset at Maghrib. Until then, the day resets at midnight."
    )
    static let maghribWithoutSunset = text(
        "practice.day_reset.no_sunset", "There's no Maghrib here today, so the day resets at midnight.")

    // MARK: - Location

    static let location = text("practice.location.title", "Location")
    static let locationNotSet = text("practice.location.not_set", "Not set")
    static let currentLocation = text("practice.location.current", "My location")
    static let locationNote = text(
        "practice.location.note", "Your location stays on this phone. It's used only to find Maghrib.")
    static let useMyLocation = text("practice.location.use_mine", "Use my location")
    static let removeLocation = text("practice.location.remove", "Remove location")
    static let locationDenied = text(
        "practice.location.denied", "Location access is off. Allow it in the Settings app, or search for your city.")
    static let locationUnavailable = text(
        "practice.location.unavailable", "Couldn't find your location. Try again, or search for your city.")
    static let searchLabel = text("practice.location.search", "Search for a city")
    static let searchPrompt = text("practice.location.search_prompt", "City name")
    static let clearSearch = text("practice.location.clear", "Clear search")
    static let cities = text("practice.location.cities", "Cities")
    static let morePlaces = text("practice.location.more_places", "More places")
    static let noCities = text(
        "practice.location.no_results", "No cities found. Check the spelling, or try a nearby city.")

    /// Where a city or place is: "Kerala, India" (both from data).
    static func placeDetail(region: String, country: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "practice.location.detail", defaultValue: "\(isolated(region)), \(isolated(country))", bundle: bundle)
    }

    // MARK: - Method and madhab

    static let method = text("practice.method.title", "Calculation method")
    static let methodNote = text(
        "practice.method.note", "Only Dubai and the Moonsighting Committee move Maghrib, by 3 minutes.")

    static func methodName(_ method: CalculationMethod) -> LocalizedStringResource {
        switch method {
        case .karachi: text("practice.method.karachi", "University of Islamic Sciences, Karachi")
        case .northAmerica: text("practice.method.north_america", "Islamic Society of North America")
        case .muslimWorldLeague: text("practice.method.muslim_world_league", "Muslim World League")
        case .egyptian: text("practice.method.egyptian", "Egyptian General Authority of Survey")
        case .ummAlQura: text("practice.method.umm_al_qura", "Umm al-Qura University, Makkah")
        case .moonsightingCommittee: text("practice.method.moonsighting_committee", "Moonsighting Committee")
        case .dubai: text("practice.method.dubai", "Dubai")
        case .kuwait: text("practice.method.kuwait", "Kuwait")
        case .qatar: text("practice.method.qatar", "Qatar")
        case .singapore: text("practice.method.singapore", "Singapore")
        }
    }

    static let madhab = text("practice.madhab.title", "Asr time")
    static let madhabStandard = text("practice.madhab.shafi", "Standard")
    static let madhabHanafi = text("practice.madhab.hanafi", "Hanafi")
    static let madhabNote = text(
        "practice.madhab.note", "Standard is the Shafi'i, Maliki and Hanbali time. Only Asr changes.")

    // MARK: - Week start

    static let weekStart = text("practice.week_start.title", "Week starts on")

    static func weekday(_ start: WeekStart) -> LocalizedStringResource {
        switch start {
        case .saturday: text("practice.week_start.saturday", "Saturday")
        case .sunday: text("practice.week_start.sunday", "Sunday")
        case .monday: text("practice.week_start.monday", "Monday")
        }
    }

    // MARK: - Hijri corrections

    static let hijri = text("practice.hijri.title", "Hijri calendar")
    static let hijriNote = text(
        "practice.hijri.note",
        "If the new moon was sighted a day earlier or later where you are, move the month to match.")
    static let adjustThisMonth = text("practice.hijri.adjust_this", "Adjust this month")
    static let adjustNextMonth = text("practice.hijri.adjust_next", "Adjust next month")
    static let earlierCorrections = text("practice.hijri.earlier", "Earlier corrections")
    static let remove = text("practice.hijri.remove", "Remove")
    static let removeBlocked = text(
        "practice.hijri.remove_blocked",
        "Remove the later correction first: removing this one would leave a month too long or too short.")
    static let correctionsReplacedTitle = text("practice.hijri.replaced.title", "Hijri corrections replaced")
    static let correctionsReplacedBody = text(
        "practice.hijri.replaced.body",
        "These settings were also changed on another device. Its Hijri corrections didn't fit with yours, so its corrections were kept."
    )

    /// An offset from the Umm al-Qura table, as an option.
    static func offset(_ days: Int) -> LocalizedStringResource {
        switch days {
        case ...(-2): text("practice.hijri.offset.earlier_2", "Starts 2 days earlier")
        case -1: text("practice.hijri.offset.earlier_1", "Starts 1 day earlier")
        case 0: text("practice.hijri.offset.table", "As in the Umm al-Qura calendar")
        case 1: text("practice.hijri.offset.later_1", "Starts 1 day later")
        default: text("practice.hijri.offset.later_2", "Starts 2 days later")
        }
    }
}
