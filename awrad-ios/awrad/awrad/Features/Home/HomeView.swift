import Combine
import SwiftUI

struct HomeView: View {
    @Environment(AwradStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(AppServices.self) private var services
    @Environment(\.colorScheme) private var colorScheme
    @State private var now = Date()
    @State private var isEnablingPrayerTimes = false

    private var dueGoals: [Goal] { store.todayGoals() }
    private var dailyWirds: [Wird] {
        HomeParityModel.activeFeaturedWirds(store.sortedWirds, on: effectiveDate)
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
        HomeParityModel.primaryGoal(from: dueGoals)
    }
    private var visibleGoals: [Goal] {
        HomeParityModel.visibleGoals(from: dueGoals)
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
                    featuredCollectionsSection
                    dailyWird
                }
                .frame(width: contentWidth, alignment: .leading)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 20)
                .padding(.bottom, 96)
            }
            .refreshable {
                await refreshProgressFromCloud()
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

    private func refreshProgressFromCloud() async {
        guard services.auth.isLoggedIn else { return }
        await services.progressSync.synchronize(store: store)
    }

    private var hero: some View {
        Group {
            if let primaryGoal {
                Button {
                    router.navigate(.counting(goalID: primaryGoal.id, slotID: nil), in: .home)
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
                .accessibilityIdentifier("home.continueGoal")
            } else {
                Button {
                    router.navigate(.createGoal(dhikrID: nil), in: .home)
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
            Button {
                router.navigate(.settings, in: .home)
            } label: {
                HomePrayerRhythmCard(
                    nextPrayer: nextPrayer,
                    cityName: store.preferences.cityName,
                    now: now,
                    language: language
                )
            }
            .buttonStyle(.plain)
        } else {
            Button(action: enablePrayerTimes) {
                HomePrayerPromptCard(isLoading: isEnablingPrayerTimes)
            }
            .buttonStyle(.plain)
            .disabled(isEnablingPrayerTimes)
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
                    progressForGoal: { store.progress(for: $0) },
                    streakForGoal: {
                        GoalProgressCalculator.streak(
                            for: $0,
                            entries: store.countEntries,
                            todayKey: store.todayKey
                        )
                    },
                    onViewAll: {
                        store.selectedTab = .goals
                        router.popToRoot(in: .goals)
                    },
                    onGoalTap: { goal in
                        router.navigate(.counting(goalID: goal.id, slotID: nil), in: .home)
                    },
                    imageName: homeImages.goalsImageName
                )
            }
        }
    }

    @ViewBuilder
    private var dailyWird: some View {
        if !dailyWirds.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Featured Wirds", subtitle: nil, actionTitle: "View All") {
                    store.selectedTab = .library
                    router.navigate(.wirdList, in: .library)
                }
                LazyVStack(spacing: 12) {
                    ForEach(dailyWirds) { wird in
                        let todayPart = store.todayPrimaryPart(for: wird, now: effectiveDate)
                        let summary = store.progressSummary(for: wird, now: effectiveDate)
                        let streak = store.wirdStreak(for: wird)

                        Button {
                            if let todayPart {
                                router.navigate(
                                    .wirdReader(wirdID: wird.id, partID: todayPart.id),
                                    in: .home
                                )
                            }
                        } label: {
                            WirdCatalogCard(
                                wird: wird,
                                summary: summary,
                                isActiveToday: todayPart != nil,
                                language: language
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("home.wird.\(wird.id.uuidString)")
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
            SectionHeader(title: "Featured dhikr collections", subtitle: nil, actionTitle: "View All") {
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

    private func enablePrayerTimes() {
        guard !isEnablingPrayerTimes else { return }
        isEnablingPrayerTimes = true
        Task {
            defer { isEnablingPrayerTimes = false }
            do {
                let result = try await services.locations.requestCurrentLocation()
                store.setPrayerLocation(result)
                refreshDayContext()
                await rescheduleGoalRemindersAfterLocationChange()
            } catch {
                // Android falls back to Settings when permission or a location
                // fix is unavailable. The iOS page keeps that recovery path
                // native by opening the existing location editor.
                router.navigate(.settings, in: .home)
            }
        }
    }

    private func rescheduleGoalRemindersAfterLocationChange() async {
        _ = await services.refreshNotifications(
            store: store,
            change: .init(goalIDs: Set(store.goals.map(\.id)), reason: .preferenceMutation)
        )
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

enum HomeParityModel {
    static func primaryGoal(from dueGoals: [Goal]) -> Goal? {
        dueGoals.first
    }

    static func visibleGoals(from dueGoals: [Goal]) -> [Goal] {
        Array(dueGoals.prefix(3))
    }

    static func activeFeaturedWirds(_ wirds: [Wird], on date: Date) -> [Wird] {
        Array(
            wirds
                .filter { !$0.isCustom && !WirdCalculator.activeParts($0, on: date).isEmpty }
                .sorted { lhs, rhs in
                    if lhs.sortOrder == rhs.sortOrder { return lhs.id.uuidString < rhs.id.uuidString }
                    return lhs.sortOrder < rhs.sortOrder
                }
                .prefix(4)
        )
    }
}

private struct HomeImageSet {
    let featuredImageName: String
    let goalsImageName: String

    init(now: Date, prayerSummary: PrayerTimesSummary?, isDarkTheme: Bool) {
        if isDarkTheme {
            featuredImageName = "home_continue_minimal_dark"
            goalsImageName = "home_goals_minimal_dark"
        } else {
            featuredImageName = "home_continue_minimal_light"
            goalsImageName = "home_goals_minimal_light"
        }
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
        ZStack {
            AwradBundleImage(name: imageName)
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 86)
                .clipped()
            LinearGradient(
                colors: [AwradTheme.surface.opacity(0.96), AwradTheme.surface.opacity(0.78), AwradTheme.surface.opacity(0.3)],
                startPoint: .leading,
                endPoint: .trailing
            )

            HStack(spacing: 12) {
                if let target {
                    HomeGoalProgressRing(
                        progress: progress,
                        count: count,
                        accessibilityTarget: target,
                        language: language,
                        size: 52,
                        lineWidth: 5
                    )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(AwradLocalizer.format("Continue %@", language: language, title))
                        .font(AwradTheme.bodyFont(.headline, weight: .bold))
                        .foregroundStyle(AwradTheme.sageDark)
                        .lineLimit(1)
                    Text(progressText)
                        .font(AwradTheme.bodyFont(.caption))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.forward")
                    .font(AwradTheme.bodyFont(.headline, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(AwradTheme.sage, in: Circle())
            }
            .padding(.horizontal, 18)
        }
        .frame(height: 86)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(title), \(progressText)"))
    }

    private var progressText: String {
        guard let target else {
            return AwradLocalizer.format("%lld today", language: language, count)
        }
        if count >= target {
            return AwradLocalizer.localized("Done", language: language)
        }
        return AwradLocalizer.format("%lld left today", language: language, max(Int64(target) - count, 0))
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
                Text("Create goal")
                    .font(AwradTheme.bodyFont(.headline, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .awradGlassSurface(
                        cornerRadius: 22,
                        tint: AwradTheme.sage,
                        interactive: true
                    )
            }
        }
    }
}

private struct HomePrayerPromptCard: View {
    let isLoading: Bool

    var body: some View {
        AwradCard(padding: 18) {
            HStack(spacing: 14) {
                Image(systemName: "location.fill")
                    .font(AwradTheme.bodyFont(20, weight: .semibold))
                    .foregroundStyle(AwradTheme.sage)
                    .frame(width: 46, height: 46)
                    .background(AwradTheme.mint.opacity(0.28), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("Enable prayer times")
                        .font(AwradTheme.bodyFont(.headline, weight: .bold))
                        .foregroundStyle(AwradTheme.sageDark)
                    Text("Use your location for the next prayer and prayer-based reminders.")
                        .font(AwradTheme.bodyFont(.footnote))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if isLoading {
                    ProgressView()
                        .tint(AwradTheme.sage)
                } else {
                    Image(systemName: "chevron.forward")
                        .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct HomePrayerRhythmCard: View {
    let nextPrayer: NextPrayerSummary
    let cityName: String
    let now: Date
    let language: AppLanguage

    var body: some View {
        AwradCard(padding: 18) {
            HStack(spacing: 14) {
                Image(systemName: "building.columns.fill")
                    .font(AwradTheme.bodyFont(20, weight: .semibold))
                    .foregroundStyle(AwradTheme.gold)
                    .frame(width: 48, height: 48)
                    .background(AwradTheme.gold.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("Next prayer")
                        .font(AwradTheme.bodyFont(.subheadline))
                        .foregroundStyle(.secondary)
                    Text(prayerAndTime)
                        .font(AwradTheme.bodyFont(.title3, weight: .bold))
                        .foregroundStyle(AwradTheme.sageDark)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(AwradLocalizer.countdown(from: now, to: nextPrayer.time, language: language))
                    .font(AwradTheme.bodyFont(.subheadline, weight: .bold))
                    .foregroundStyle(AwradTheme.gold)
                    .lineLimit(1)

                Image(systemName: "chevron.forward")
                    .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text(cityName.isEmpty ? "Open prayer time settings" : cityName))
    }

    private var prayerAndTime: String {
        let prayer = AwradLocalizer.localized(nextPrayer.prayer.title, language: language)
        let time = AwradLocalizer.formattedTime(nextPrayer.time, language: language)
        return "\(prayer) · \(time)"
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
                Text(AwradLocalizer.localized(collection.title, language: language))
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
    let progressForGoal: (Goal) -> Double
    let streakForGoal: (Goal) -> Int
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
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        headerIcon
                        headerTitle
                            .fixedSize(horizontal: true, vertical: false)
                        Spacer(minLength: 8)
                        viewAllButton
                    }

                    HStack(alignment: .top, spacing: 12) {
                        headerIcon
                        VStack(alignment: .leading, spacing: 7) {
                            headerTitle
                                .lineLimit(2)
                            viewAllButton
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
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
                                progress: progressForGoal(goal),
                                streak: streakForGoal(goal),
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

    private var headerIcon: some View {
        Image(systemName: "scope")
            .font(AwradTheme.bodyFont(20, weight: .semibold))
            .foregroundStyle(AwradTheme.sage)
            .frame(width: 46, height: 46)
            .background(AwradTheme.mint.opacity(0.22), in: Circle())
            .overlay(Circle().stroke(AwradTheme.sage.opacity(0.26), lineWidth: 1))
    }

    private var headerTitle: some View {
        Text(AwradLocalizer.localized("Today's goals", language: language))
            .font(AwradTheme.displayFont(24, weight: .bold))
            .foregroundStyle(AwradTheme.sageDark)
            .minimumScaleFactor(0.78)
    }

    private var viewAllButton: some View {
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

}

private struct GoalQueueRow: View {
    let title: String
    let count: Int64
    let target: Int?
    let progress: Double
    let streak: Int
    let language: AppLanguage

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(AwradTheme.bodyFont(.headline, weight: .bold))
                    .foregroundStyle(AwradTheme.sageDark)
                    .lineLimit(2)
                if streak > 0 {
                    Label {
                        Text(AwradLocalizer.format("%d day streak", language: language, streak))
                    } icon: {
                        Image(systemName: "flame.fill")
                    }
                    .font(AwradTheme.bodyFont(.caption, weight: .semibold))
                    .foregroundStyle(AwradTheme.gold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AwradTheme.gold.opacity(0.12), in: Capsule())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let target {
                HomeGoalProgressRing(
                    progress: progress,
                    count: count,
                    accessibilityTarget: target,
                    language: language,
                    size: 48,
                    lineWidth: 4
                )
            } else {
                Text("\(count)")
                    .font(AwradTheme.bodyFont(.subheadline, weight: .bold).monospacedDigit())
                    .foregroundStyle(AwradTheme.sage)
            }

            Image(systemName: "chevron.forward")
                .font(AwradTheme.bodyFont(.headline, weight: .bold))
                .foregroundStyle(AwradTheme.sage)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

private struct HomeGoalProgressRing: View {
    let progress: Double
    let count: Int64
    let accessibilityTarget: Int
    let language: AppLanguage
    let size: CGFloat
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(AwradTheme.mint.opacity(0.38), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(
                    AwradTheme.sage,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Text("\(count)")
                .font(AwradTheme.bodyFont(.caption, weight: .bold).monospacedDigit())
                .foregroundStyle(AwradTheme.sageDark)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .padding(5)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(AwradLocalizer.format(
            "%lld of %lld",
            language: language,
            count,
            Int64(accessibilityTarget)
        )))
        .accessibilityValue(Text(AwradLocalizer.format(
            "%d percent",
            language: language,
            Int(min(max(progress, 0), 1) * 100)
        )))
    }
}
