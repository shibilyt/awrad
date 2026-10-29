import Adhan
import AwradDomain
import Foundation

/// `MaghribCalculator` with adhan-swift (batoulapps/adhan-swift, ADR 0006), pinned by
/// `maghrib_time.json` to within a minute of adhan-js. The madhab doesn't affect Maghrib.
public struct AdhanMaghribCalculator: MaghribCalculator {
    public init() {}

    public func maghrib(
        on day: CalendarDay, latitude: Double, longitude: Double, method: AwradDomain.CalculationMethod
    ) -> Date? {
        let date = DateComponents(year: day.year, month: day.month, day: day.day)
        // `nil` where the sun doesn't set or rise that day: the Maghrib reset falls back to midnight.
        let times = PrayerTimes(
            coordinates: Adhan.Coordinates(latitude: latitude, longitude: longitude), date: date,
            calculationParameters: method.adhan.params)
        return times?.maghrib
    }
}

extension AwradDomain.CalculationMethod {
    /// The same method in adhan's own names.
    var adhan: Adhan.CalculationMethod {
        switch self {
        case .karachi: .karachi
        case .northAmerica: .northAmerica
        case .muslimWorldLeague: .muslimWorldLeague
        case .egyptian: .egyptian
        case .ummAlQura: .ummAlQura
        case .moonsightingCommittee: .moonsightingCommittee
        case .dubai: .dubai
        case .kuwait: .kuwait
        case .qatar: .qatar
        case .singapore: .singapore
        }
    }
}
