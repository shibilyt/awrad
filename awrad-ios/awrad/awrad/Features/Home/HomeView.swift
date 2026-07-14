import Combine
import SwiftUI

struct HomeView: View {
    @Environment(AwradStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(AppServices.self) private var services
    @Environment(\.colorScheme) private var colorScheme
    @State private var now = Date()

    private var dueGoals: [Goal] { store.todayGoals() }
    private var dailyWirds: [Wird] {
        store.sortedWirds
    }
    private var categoryCounts: [DhikrCategory: Int] {
        Dictionary(uniqueKeysWithValues: DhikrCategory.allCases.map { category in
            (category, store.dhikrs.filter { $0.category == category }.count)
        })
    }
    private var featuredCollections: [FeaturedHomeCollection] {
        FeaturedHomeCollection.collections(categoryCounts: categoryCounts)
    }
    private var primaryGoal: Goal? {
        dueGoals.first ?? store.goals.first(where: \.isActive)
    }
    private var visibleGoals: [Goal] {
        Array(dueGoals.prefix(3))
    }
    private var language: AppLanguage { store.preferences.appLanguage }
    private var prayerSummary: PrayerTimesSummary? {
        services.prayerTimes.summary(
            for: now,
            latitude: store.preferences.latitude,
            longitude: store.preferences.longitude,
            method: store.preferences.calculationMethod,
            madhab: store.preferences.madhab
        )
    }
    private var tomorrowPrayerSummary: PrayerTimesSummary? {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
        return services.prayerTimes.summary(
            for: tomorrow,
            latitude: store.preferences.latitude,
            longitude: store.preferences.longitude,
            method: store.preferences.calculationMethod,
            madhab: store.preferences.madhab
        )
    }
    private var homeImages: HomeImageSet {
        HomeImageSet(
            now: now,
            prayerSummary: prayerSummary,
            isDarkTheme: colorScheme == .dark
        )
    }

    var body: some View {
        GeometryReader { proxy in
            let horizontalPadding: CGFloat = 20
            let safeAreaWidth = proxy.safeAreaInsets.leading + proxy.safeAreaInsets.trailing
            let contentWidth = max(0, proxy.size.width - safeAreaWidth - (horizontalPadding * 2))

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HomeDateHeader(
                        date: effectiveDate,
                        calendarSystem: store.preferences.calendarSystem,
                        language: language
                    ) {
                        router.navigate(.settings, in: .home)
                    }
                    hero
                    prayerCard
                    todaysFocus
                    if store.streak() > 0 {
                        CompactStreakCard(
                            streak: store.streak(),
                            activeDates: store.contributionDateKeys(),
                            today: effectiveDate,
                            language: language
                        )
                    }
                    featuredCollectionsSection
                    dailyWird
                }
                .frame(width: contentWidth, alignment: .leading)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 20)
                .padding(.bottom, 96)
            }
        }
        .background(AwradTheme.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear(perform: refreshDayContext)
        .onChange(of: store.preferences.dayReset) { _, _ in refreshDayContext() }
        .onChange(of: store.preferences.latitude) { _, _ in refreshDayContext() }
        .onChange(of: store.preferences.longitude) { _, _ in refreshDayContext() }
        .onChange(of: store.preferences.calculationMethod) { _, _ in refreshDayContext() }
        .onChange(of: store.preferences.madhab) { _, _ in refreshDayContext() }
        .onReceive(Self.minuteTimer) { date in
            now = date
            refreshDayContext(at: date)
        }
    }

    private var hero: some View {
        Group {
            if let primaryGoal {
                Button {
                    router.navigate(.counting(goalID: primaryGoal.id), in: .home)
                } label: {
                    FeaturedGoalCard(
                        title: store.title(for: primaryGoal),
                        count: store.count(for: primaryGoal),
                        target: primaryGoal.targetPolicy == .none ? nil : primaryGoal.totalTarget,
                        progress: store.progress(for: primaryGoal),
                        language: language,
                        imageName: homeImages.featuredImageName
                    )
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    store.selectedTab = .library
                    router.popToRoot(in: .library)
                } label: {
                    EmptyHomeStartCard()
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var prayerCard: some View {
        if let prayerSummary,
           let nextPrayer = services.prayerTimes.nextPrayer(
                today: prayerSummary,
                tomorrow: tomorrowPrayerSummary,
                now: now
           ) {
            PrayerTimeCard(
                summary: prayerSummary,
                nextPrayer: nextPrayer,
                cityName: store.preferences.cityName,
                now: now,
                language: language
            )
        }
    }

    private var todaysFocus: some View {
        Group {
            if !visibleGoals.isEmpty {
                TodayGoalsQueueCard(
                    goals: visibleGoals,
                    language: language,
                    titleForGoal: { store.title(for: $0) },
                    countForGoal: { store.count(for: $0) },
                    targetForGoal: { $0.targetPolicy == .none ? nil : $0.totalTarget },
                    onViewAll: {
                        store.selectedTab = .goals
                        router.popToRoot(in: .goals)
                    },
                    onGoalTap: { goal in
                        router.navigate(.counting(goalID: goal.id), in: .home)
                    },
                    imageName: homeImages.goalsImageName
                )
            }
        }
    }

    private var dailyWird: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Wirds for Today", subtitle: "Continue your reading", actionTitle: "View All") {
                store.selectedTab = .library
                router.navigate(.wirdList, in: .library)
            }
            if dailyWirds.isEmpty {
                EmptyStateView(
                    symbol: "book.closed",
                    title: "No Wird collections",
                    message: "Add a collection to begin reading."
                )
                .background(AwradTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(dailyWirds) { wird in
                        let todayPart = store.todayPrimaryPart(for: wird)
                        let summary = store.progressSummary(for: wird)
                        let streak = store.wirdStreak(for: wird)

                        Button {
                            router.navigate(.wirdDetail(wird.id), in: .home)
                        } label: {
                            HomeWirdCard(
                                wird: wird,
                                todayPart: todayPart,
                                summary: summary,
                                streak: streak,
                                language: language,
                                imageName: homeImages.wirdImageName
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(homeWirdAccessibilityLabel(
                            wird: wird,
                            todayPart: todayPart,
                            summary: summary,
                            streak: streak
                        )))
                    }
                }
            }
        }
    }

    private var featuredCollectionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Featured collections", subtitle: nil, actionTitle: "View All") {
                store.selectedTab = .library
                router.popToRoot(in: .library)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(featuredCollections) { collection in
                        Button {
                            store.selectedTab = .library
                            router.navigate(.category(collection.category), in: .library)
                        } label: {
                            FeaturedCollectionCard(collection: collection, language: language)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
        }
    }

    private func homeWirdAccessibilityLabel(
        wird: Wird,
        todayPart: WirdPart?,
        summary: WirdProgressSummary,
        streak: Int
    ) -> String {
        var parts = [wird.displayName(language: language)]
        if let todayPart {
            parts.append(todayPart.displayTitle(language: language))
            parts.append(AwradLocalizer.readingProgress(
                completed: summary.completedItems,
                total: summary.totalItems,
                language: language
            ))
            if summary.isComplete {
                parts.append(AwradLocalizer.localized("Complete", language: language))
            }
        }
        parts.append(AwradLocalizer.wirdStreak(streak, language: language))
        return parts.joined(separator: ", ")
    }

    private var effectiveDate: Date {
        Self.dateKeyFormatter.date(from: store.todayKey) ?? now
    }

    private func refreshDayContext() {
        refreshDayContext(at: now)
    }

    private func refreshDayContext(at date: Date) {
        store.refreshEffectiveDate(prayerTimes: prayerSummary, now: date)
    }

    private static let minuteTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private static let dateKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private struct HomeImageSet {
    let featuredImageName: String
    let goalsImageName: String
    let wirdImageName: String

    init(now: Date, prayerSummary: PrayerTimesSummary?, isDarkTheme: Bool) {
        let isNight = Self.isNight(now: now, prayerSummary: prayerSummary)
        if isDarkTheme {
            featuredImageName = isNight ? "home_featured_night" : "home_featured_dark_day"
            goalsImageName = isNight ? "home_goals_night" : "home_goals_dark_day"
            wirdImageName = "collection_daily_essentials_dark"
        } else {
            featuredImageName = isNight ? "home_featured_light_night" : "home_featured_day"
            goalsImageName = isNight ? "home_goals_light_night" : "home_goals_day"
            wirdImageName = "collection_daily_essentials_light"
        }
    }

    private static func isNight(now: Date, prayerSummary: PrayerTimesSummary?) -> Bool {
        if let prayerSummary, prayerSummary.maghrib > prayerSummary.sunrise {
            return !(now >= prayerSummary.sunrise && now < prayerSummary.maghrib)
        }

        let hour = Calendar.current.component(.hour, from: now)
        return hour < 6 || hour >= 18
    }
}

private struct FeaturedGoalCard: View {
    let title: String
    let count: Int64
    let target: Int?
    let progress: Double
    let language: AppLanguage
    let imageName: String

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width

            ZStack {
                AwradBundleImage(name: imageName)
                    .scaledToFill()
                    .frame(width: width, height: 246)
                    .clipped()
                LinearGradient(
                    colors: [.white.opacity(0.16), .white.opacity(0.34)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(spacing: 12) {
                    Spacer(minLength: 34)
                    Text(title)
                        .font(AwradTheme.displayFont(32, weight: .bold))
                        .foregroundStyle(AwradTheme.sageDark)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.56)
                        .allowsTightening(true)
                        .frame(maxWidth: .infinity)
                    Text(progressText)
                        .font(AwradTheme.displayFont(26, weight: .bold))
                        .foregroundStyle(AwradTheme.subdued)
                        .lineLimit(1)
                        .minimumScaleFactor(0.64)
                        .allowsTightening(true)
                        .frame(maxWidth: .infinity)
                    AwradProgressBar(value: progress, height: 9)
                        .padding(.horizontal, 18)
                    ButtonLikeContinueLabel()
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 24)
                .frame(width: width)
            }
            .frame(width: width, height: 246)
        }
        .frame(height: 246)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(title), \(progressText)"))
    }

    private var progressText: String {
        guard let target else {
            return AwradLocalizer.format("%d today", language: language, count)
        }
        return AwradLocalizer.format("%d / %d today", language: language, count, target)
    }
}

private struct ButtonLikeContinueLabel: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(LocalizedStringKey("Continue"))
            .font(AwradTheme.bodyFont(.headline, weight: .bold))
            .foregroundStyle(contentColor)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(containerColor, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var isDark: Bool {
        colorScheme == .dark
    }

    private var containerColor: Color {
        isDark ? Self.color(0x123927) : Self.color(0x2E5C3D)
    }

    private var contentColor: Color {
        isDark ? Self.color(0xD4E8DA) : .white
    }

    private static func color(_ hex: UInt32) -> Color {
        Color(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

private struct EmptyHomeStartCard: View {
    var body: some View {
        AwradCard(padding: 24) {
            VStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(AwradTheme.bodyFont(28, weight: .bold))
                    .foregroundStyle(AwradTheme.sageDark)
                    .frame(width: 58, height: 58)
                    .background(AwradTheme.mint.opacity(0.45), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                Text("No goals yet")
                    .font(AwradTheme.displayFont(22, weight: .semibold))
                    .foregroundStyle(AwradTheme.ink)
                Text("Create a goal to begin tracking.")
                    .font(AwradTheme.bodyFont(.subheadline))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                ButtonLikeContinueLabel()
            }
        }
    }
}

private struct FeaturedHomeCollection: Identifiable {
    enum Tone {
        case asmaUlHusna
        case daily
        case swalaths
        case dhikrs
        case evening
        case prayer
    }

    let title: String
    let category: DhikrCategory
    let count: Int
    let tone: Tone

    var id: String { title }

    static func collections(categoryCounts: [DhikrCategory: Int]) -> [FeaturedHomeCollection] {
        let dailyCategory: DhikrCategory = (categoryCounts[.morning] ?? 0) > 0 ? .morning : .praise
        let dailyCount = (categoryCounts[.morning] ?? 0) > 0
            ? (categoryCounts[.morning] ?? 0)
            : count(categoryCounts, categories: [.praise, .forgiveness, .quran])

        return [
            FeaturedHomeCollection(
                title: String(
                    localized: "category.asma_ul_husna",
                    defaultValue: "Asma-ul Husna"
                ),
                category: .asmaUlHusna,
                count: categoryCounts[.asmaUlHusna] ?? 0,
                tone: .asmaUlHusna
            ),
            FeaturedHomeCollection(
                title: "Daily Essentials",
                category: dailyCategory,
                count: dailyCount,
                tone: .daily
            ),
            FeaturedHomeCollection(
                title: "Swalaths",
                category: .swalaths,
                count: categoryCounts[.swalaths] ?? 0,
                tone: .swalaths
            ),
            FeaturedHomeCollection(
                title: "Dhikrs",
                category: .praise,
                count: count(categoryCounts, categories: [.praise, .forgiveness, .general]),
                tone: .dhikrs
            ),
            FeaturedHomeCollection(
                title: "Evening Dhikrs",
                category: .evening,
                count: categoryCounts[.evening] ?? 0,
                tone: .evening
            ),
            FeaturedHomeCollection(
                title: "After Prayer",
                category: .afterSalah,
                count: categoryCounts[.afterSalah] ?? 0,
                tone: .prayer
            )
        ]
    }

    private static func count(
        _ categoryCounts: [DhikrCategory: Int],
        categories: [DhikrCategory]
    ) -> Int {
        categories.reduce(0) { total, category in
            total + (categoryCounts[category] ?? 0)
        }
    }
}

private struct FeaturedCollectionCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let collection: FeaturedHomeCollection
    let language: AppLanguage

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        ZStack(alignment: .topLeading) {
            AwradBundleImage(name: imageName)
                .scaledToFill()
                .frame(width: 154, height: 154)
                .clipped()

            LinearGradient(
                colors: scrimColors,
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 8) {
                Text(collection.title)
                    .font(AwradTheme.bodyFont(.headline, weight: .bold))
                    .foregroundStyle(isDark ? Color.white.opacity(0.97) : AwradTheme.sageDark)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(AwradLocalizer.dhikrCount(collection.count, language: language))
                    .font(AwradTheme.bodyFont(.caption, weight: .semibold))
                    .foregroundStyle(isDark ? Color.white.opacity(0.76) : .secondary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(AwradTheme.bodyFont(15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background((isDark ? AwradTheme.sage : AwradTheme.sageDark).opacity(0.9), in: Circle())
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(14)
        }
        .frame(width: 154, height: 154)
        .background(AwradTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var imageName: String {
        let suffix = isDark ? "dark" : "light"
        return switch collection.tone {
        case .asmaUlHusna:
            "collection_asma_ul_husna_\(suffix)"
        case .daily:
            "collection_daily_essentials_\(suffix)"
        case .swalaths:
            "collection_swalaths_\(suffix)"
        case .dhikrs:
            "collection_dhikrs_\(suffix)"
        case .evening:
            "collection_evening_dhikrs_\(suffix)"
        case .prayer:
            "collection_after_prayer_\(suffix)"
        }
    }

    private var scrimColors: [Color] {
        if isDark {
            [
                .black.opacity(0.6),
                .black.opacity(0.27),
                .black.opacity(0.07)
            ]
        } else {
            [
                .white.opacity(0.72),
                .white.opacity(0.33),
                .white.opacity(0)
            ]
        }
    }
}

private struct TodayGoalsQueueCard: View {
    let goals: [Goal]
    let language: AppLanguage
    let titleForGoal: (Goal) -> String
    let countForGoal: (Goal) -> Int64
    let targetForGoal: (Goal) -> Int?
    let onViewAll: () -> Void
    let onGoalTap: (Goal) -> Void
    let imageName: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            AwradBundleImage(name: imageName)
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .clipped()
            LinearGradient(
                colors: [AwradTheme.surface.opacity(0.96), AwradTheme.surface.opacity(0.72), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )

            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "scope")
                        .font(AwradTheme.bodyFont(20, weight: .semibold))
                        .foregroundStyle(AwradTheme.sage)
                        .frame(width: 46, height: 46)
                        .background(AwradTheme.mint.opacity(0.22), in: Circle())
                        .overlay(Circle().stroke(AwradTheme.sage.opacity(0.26), lineWidth: 1))
                    Text("Today's goals")
                        .font(AwradTheme.displayFont(24, weight: .bold))
                        .foregroundStyle(AwradTheme.sageDark)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Spacer(minLength: 8)
                    Button(action: onViewAll) {
                        HStack(spacing: 4) {
                            Text("View all")
                            Image(systemName: "chevron.right")
                        }
                            .font(AwradTheme.bodyFont(.subheadline, weight: .bold))
                            .foregroundStyle(AwradTheme.sage)
                    }
                    .lineLimit(1)
                }

                VStack(spacing: 0) {
                    ForEach(Array(goals.enumerated()), id: \.element.id) { index, goal in
                        Button {
                            onGoalTap(goal)
                        } label: {
                            GoalQueueRow(
                                title: titleForGoal(goal),
                                count: countForGoal(goal),
                                target: targetForGoal(goal),
                                glyph: glyph(for: goal),
                                language: language
                            )
                        }
                        .buttonStyle(.plain)
                        if index != goals.count - 1 {
                            Divider()
                                .padding(.leading, 66)
                                .padding(.vertical, 10)
                        }
                    }
                }
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func glyph(for goal: Goal) -> String {
        let title = titleForGoal(goal).trimmingCharacters(in: .whitespacesAndNewlines)
        return String(title.prefix(1))
    }
}

private struct GoalQueueRow: View {
    let title: String
    let count: Int64
    let target: Int?
    let glyph: String
    let language: AppLanguage

    var body: some View {
        HStack(spacing: 12) {
            Text(glyph)
                .font(AwradTheme.arabicFont(24, weight: .semibold))
                .foregroundStyle(AwradTheme.sage)
                .frame(width: 54, height: 54)
                .background(AwradTheme.mint.opacity(0.2), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(AwradTheme.bodyFont(.headline, weight: .bold))
                    .foregroundStyle(AwradTheme.sageDark)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 8)
            Text(progressText)
                .font(AwradTheme.bodyFont(.subheadline, weight: .bold))
                .foregroundStyle(AwradTheme.sage)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Image(systemName: "chevron.right")
                .font(AwradTheme.bodyFont(.headline, weight: .bold))
                .foregroundStyle(AwradTheme.sage)
        }
        .contentShape(Rectangle())
    }

    private var progressText: String {
        guard let target else { return "\(count)" }
        return count >= target
            ? AwradLocalizer.localized("Done", language: language)
            : "\(count) / \(target)"
    }
}

private struct HomeWirdCard: View {
    let wird: Wird
    let todayPart: WirdPart?
    let summary: WirdProgressSummary
    let streak: Int
    let language: AppLanguage
    let imageName: String

    var body: some View {
        AwradCard {
            HStack(alignment: .top, spacing: 14) {
                AwradBundleImage(name: imageName)
                    .scaledToFill()
                    .frame(width: 70, height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

                VStack(alignment: .leading, spacing: 9) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(wird.displayName(language: language))
                            .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                            .foregroundStyle(AwradTheme.ink)
                            .lineLimit(2)
                        Text(wird.displayDescription(language: language))
                            .font(AwradTheme.bodyFont(.caption))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    if let todayPart {
                        VStack(alignment: .leading, spacing: 7) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(todayPart.displayTitle(language: language))
                                    .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                                    .foregroundStyle(AwradTheme.ink)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                                if summary.isComplete {
                                    HomeStatusPill(title: "Complete", symbol: "checkmark.circle.fill", tint: AwradTheme.sage)
                                }
                            }

                            if let subtitle = todayPart.displaySubtitle(language: language) {
                                Text(subtitle)
                                    .font(AwradTheme.bodyFont(.caption))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            if !summary.isComplete {
                                AwradProgressBar(value: summary.progress, height: 7)
                            }
                            Text(AwradLocalizer.readingProgress(
                                completed: summary.completedItems,
                                total: summary.totalItems,
                                language: language
                            ))
                            .font(AwradTheme.bodyFont(.caption))
                            .foregroundStyle(.secondary)
                        }
                    }

                    Label {
                        Text(AwradLocalizer.wirdStreak(streak, language: language))
                    } icon: {
                        Image(systemName: "flame.fill")
                    }
                    .font(AwradTheme.bodyFont(.caption, weight: .semibold))
                    .foregroundStyle(AwradTheme.sage)
                }

                Image(systemName: "chevron.right")
                    .font(AwradTheme.bodyFont(.caption, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
    }
}

private struct HomeStatusPill: View {
    let title: String
    let symbol: String
    let tint: Color

    var body: some View {
        Label {
            Text(LocalizedStringKey(title))
        } icon: {
            Image(systemName: symbol)
        }
        .font(AwradTheme.bodyFont(.caption2, weight: .semibold))
        .lineLimit(1)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .foregroundStyle(tint)
        .background(tint.opacity(0.14), in: Capsule())
    }
}
