import SwiftUI

struct HomeDateHeader: View {
    let date: Date
    let calendarSystem: CalendarSystem
    let language: AppLanguage
    let onSettingsTap: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Today")
                    .font(AwradTheme.displayFont(40, weight: .bold))
                    .foregroundStyle(AwradTheme.sageDark)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(primaryDate)
                    .font(AwradTheme.bodyFont(.title3, weight: .semibold))
                    .foregroundStyle(AwradTheme.sageDark.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(secondaryDate)
                    .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onSettingsTap) {
                Image(systemName: "slider.horizontal.3")
                    .font(AwradTheme.bodyFont(26, weight: .bold))
                    .foregroundStyle(AwradTheme.sageDark)
                    .frame(width: 64, height: 64)
                    .background(AwradTheme.mint.opacity(0.45), in: Circle())
            }
            .buttonStyle(.plain)
            .fixedSize()
            .accessibilityLabel("Settings")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var primaryDate: String {
        calendarSystem == .gregorian
            ? AwradLocalizer.gregorianDate(date, language: language)
            : AwradLocalizer.hijriDate(date, language: language)
    }

    private var secondaryDate: String {
        calendarSystem == .gregorian
            ? AwradLocalizer.hijriDate(date, language: language)
            : AwradLocalizer.gregorianDate(date, language: language)
    }
}

struct PrayerTimeCard: View {
    let summary: PrayerTimesSummary
    let nextPrayer: NextPrayerSummary
    let cityName: String
    let now: Date
    let language: AppLanguage

    var body: some View {
        AwradCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "sun.horizon")
                        .font(AwradTheme.bodyFont(21, weight: .semibold))
                        .foregroundStyle(AwradTheme.sage)
                        .frame(width: 44, height: 44)
                        .background(AwradTheme.mint.opacity(0.24), in: Circle())
                        .overlay(Circle().stroke(AwradTheme.sage.opacity(0.25), lineWidth: 1))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Prayer times")
                            .font(AwradTheme.displayFont(24, weight: .bold))
                            .foregroundStyle(AwradTheme.sageDark)
                        Text(cityName.isEmpty ? "Prayer location set" : cityName)
                            .font(AwradTheme.bodyFont(.subheadline))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text(nextPrayerLabel)
                        .font(AwradTheme.bodyFont(.headline, weight: .bold))
                        .foregroundStyle(AwradTheme.sage)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                }

                PrayerTimelineView(
                    rows: Array(summary.rows.filter(\.isPrayer).prefix(5)),
                    nextPrayer: nextPrayer.prayer,
                    now: now,
                    language: language
                )
            }
        }
    }

    private var nextPrayerLabel: String {
        "\(nextPrayer.prayer.title) \(AwradLocalizer.countdown(from: now, to: nextPrayer.time, language: language))"
    }
}

private struct PrayerTimelineView: View {
    let rows: [PrayerTimeRow]
    let nextPrayer: Prayer
    let now: Date
    let language: AppLanguage

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    if index > 0 {
                        Rectangle()
                            .fill(connectorColor(for: rows[index - 1]))
                            .frame(height: 1)
                    }
                    timelineDot(for: row)
                }
            }
            HStack(spacing: 0) {
                ForEach(rows) { row in
                    VStack(spacing: 3) {
                        Text(LocalizedStringKey(row.name))
                            .font(AwradTheme.bodyFont(.caption, weight: .bold))
                            .foregroundStyle(row.prayer == nextPrayer ? AwradTheme.sage : AwradTheme.sageDark)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(AwradLocalizer.formattedTime(row.date, language: language))
                            .font(AwradTheme.bodyFont(.caption))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    @ViewBuilder
    private func timelineDot(for row: PrayerTimeRow) -> some View {
        let complete = row.date < now
        let next = row.prayer == nextPrayer
        ZStack {
            Circle()
                .fill(complete || next ? AwradTheme.sage : AwradTheme.trackFill)
                .frame(width: next ? 28 : 24, height: next ? 28 : 24)
                .overlay {
                    Circle().stroke(complete || next ? AwradTheme.sage : AwradTheme.outline, lineWidth: next ? 2 : 1.5)
                }
            if complete {
                Image(systemName: "checkmark")
                    .font(AwradTheme.bodyFont(.caption, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func connectorColor(for row: PrayerTimeRow) -> Color {
        row.date < now || row.prayer == nextPrayer ? AwradTheme.sage.opacity(0.78) : AwradTheme.outline
    }
}

private extension PrayerTimeRow {
    var prayer: Prayer? {
        switch name.lowercased() {
        case "fajr": .fajr
        case "dhuhr": .dhuhr
        case "asr": .asr
        case "maghrib": .maghrib
        case "isha": .isha
        default: nil
        }
    }
}

struct CompactStreakCard: View {
    let streak: Int
    let activeDates: Set<String>
    let today: Date
    let language: AppLanguage

    var body: some View {
        AwradCard {
            VStack(spacing: 10) {
                HStack(spacing: 0) {
                    ForEach(days) { day in
                        VStack(spacing: 8) {
                            Text(day.weekdayInitial)
                                .font(AwradTheme.bodyFont(.caption, weight: .semibold))
                                .foregroundStyle(.secondary)
                            ZStack {
                                Circle()
                                    .fill(day.isActive ? AwradTheme.sage : AwradTheme.trackFill)
                                    .frame(width: day.isToday ? 32 : 28, height: day.isToday ? 32 : 28)
                                    .overlay {
                                        Circle()
                                            .stroke(day.isActive || day.isToday ? AwradTheme.sage : AwradTheme.outline, lineWidth: day.isToday ? 2 : 1)
                                    }
                                if day.isActive {
                                    Image(systemName: "checkmark")
                                        .font(AwradTheme.bodyFont(.caption, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                Text(AwradLocalizer.format("%d day streak", language: language, streak))
                    .font(AwradTheme.bodyFont(.caption, weight: .bold))
                    .foregroundStyle(AwradTheme.sage)
            }
        }
    }

    private var days: [CompactStreakDay] {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: today)
        let formatter = Self.dateKeyFormatter

        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset - 6, to: todayStart) else {
                return nil
            }
            let key = formatter.string(from: date)
            return CompactStreakDay(
                id: offset,
                date: date,
                isToday: offset == 6,
                isActive: activeDates.contains(key)
            )
        }
    }

    private static let dateKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private struct CompactStreakDay: Identifiable {
    let id: Int
    let date: Date
    let isToday: Bool
    let isActive: Bool

    var weekdayInitial: String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "EEEEE"
        return formatter.string(from: date)
    }
}
