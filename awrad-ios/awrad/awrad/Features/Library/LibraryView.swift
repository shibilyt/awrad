import SwiftUI

struct LibraryView: View {
    @Environment(AwradStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(AppServices.self) private var services
    @Environment(\.colorScheme) private var colorScheme
    @State private var searchText = ""
    @State private var selectedCategory: DhikrCategory?
    @State private var isSearchVisible = false
    @State private var showAudioError = false
    @FocusState private var isSearchFocused: Bool
    private var language: AppLanguage { store.preferences.appLanguage }

    private var filteredDhikrs: [Dhikr] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return sortedDhikrs(store.dhikrs.filter { dhikr in
            let categoryMatches = selectedCategory.map { $0 == dhikr.category } ?? true
            guard !query.isEmpty else { return categoryMatches }
            return categoryMatches &&
                dhikr.localizedSearchText(language: language).contains {
                    $0.localizedCaseInsensitiveContains(query)
                }
        })
    }

    private var usesGroupedDisplay: Bool {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedCategory == nil
    }

    private var populatedCategories: [DhikrCategory] {
        DhikrCategory.allCases.filter { category in
            store.dhikrs.contains { $0.category == category }
        }
    }

    private var categoryCounts: [DhikrCategory: Int] {
        Dictionary(grouping: store.dhikrs, by: \.category)
            .mapValues(\.count)
    }

    private var featuredCollections: [FeaturedDhikrCollection] {
        FeaturedDhikrCollection.collections(categoryCounts: categoryCounts)
    }

    private var shouldShowSearchField: Bool {
        isSearchVisible || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                libraryHeader
                if shouldShowSearchField {
                    librarySearchField
                }
                categories
                featuredCollectionSection
                wirdCollections
                dhikrList
            }
            .padding(20)
            .padding(.bottom, 96)
        }
        .background(AwradTheme.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: services.audio.errorMessage) { _, newValue in
            showAudioError = newValue != nil
        }
        .alert("Audio Error", isPresented: $showAudioError) {
            Button("OK") {
                services.audio.stop()
            }
        } message: {
            Text(services.audio.errorMessage ?? "Audio playback failed.")
        }
    }

    private var libraryHeader: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Library")
                    .font(AwradTheme.displayFont(34, weight: .bold))
                    .foregroundStyle(AwradTheme.ink)
                    .lineLimit(1)
                Text("Explore beautiful dhikrs\nfrom the Qur’an & Sunnah")
                    .font(AwradTheme.bodyFont(.title3, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 12)
            VStack(spacing: 12) {
                Button {
                    router.navigate(.createDhikr, in: .library)
                } label: {
                    Image(systemName: "plus")
                        .font(AwradTheme.bodyFont(23, weight: .semibold))
                        .foregroundStyle(AwradTheme.sage)
                        .awradGlassIconButton(size: 58)
                }
                .accessibilityLabel("Create Dhikr")

                Button {
                    withAnimation(.snappy(duration: 0.22)) {
                        isSearchVisible.toggle()
                        if !isSearchVisible {
                            searchText = ""
                        }
                    }
                    isSearchFocused = isSearchVisible
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(AwradTheme.bodyFont(23, weight: .semibold))
                        .foregroundStyle(AwradTheme.sage)
                        .awradGlassIconButton(size: 58)
                }
                .accessibilityLabel("Search dhikr")
            }
        }
    }

    private var librarySearchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search dhikr", text: $searchText)
                .focused($isSearchFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    isSearchFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .font(AwradTheme.bodyFont(.body))
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(AwradTheme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AwradTheme.sage.opacity(0.12), lineWidth: 1)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var categories: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                CategoryChip(title: "All dhikrs", symbol: "square.grid.2x2.fill", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                    hideSearchIfEmpty()
                }
                ForEach(populatedCategories) { category in
                    CategoryChip(title: category.title, symbol: category.symbol, isSelected: selectedCategory == category) {
                        selectedCategory = category
                        hideSearchIfEmpty()
                    }
                }
            }
        }
    }

    private var featuredCollectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "Featured collections",
                subtitle: nil,
                actionTitle: "View all"
            ) {
                selectedCategory = nil
                searchText = ""
                isSearchVisible = false
                isSearchFocused = false
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(featuredCollections) { collection in
                        Button {
                            selectedCategory = collection.category
                            searchText = ""
                            isSearchVisible = false
                            isSearchFocused = false
                        } label: {
                            LibraryFeaturedCollectionCard(
                                collection: collection,
                                language: language,
                                isDark: colorScheme == .dark
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var wirdCollections: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "Wirds",
                subtitle: AwradLocalizer.collectionCount(store.wirds.count, language: language),
                actionTitle: "See all"
            ) {
                router.navigate(.wirdList, in: .library)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(store.sortedWirds) { wird in
                        Button {
                            router.navigate(.wirdDetail(wird.id), in: .library)
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                AwradBundleImage(name: "collection_daily_essentials_light")
                                    .scaledToFill()
                                    .frame(width: 176, height: 112)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                Text(wird.displayName(language: language))
                                    .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                                    .foregroundStyle(AwradTheme.ink)
                                    .lineLimit(1)
                                Text(wird.displayDescription(language: language))
                                    .font(AwradTheme.bodyFont(.caption))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            .frame(width: 176, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var dhikrList: some View {
        VStack(alignment: .leading, spacing: 12) {
            LibraryDhikrListHeader(
                title: selectedCategory?.title ?? "All dhikrs",
                count: AwradLocalizer.dhikrCount(filteredDhikrs.count, language: language)
            )

            if store.dhikrs.isEmpty {
                EmptyStateView(
                    symbol: "text.book.closed",
                    title: "No dhikrs in library",
                    message: "Your library is empty. Add a personal dhikr or restart after content setup."
                )
            } else if filteredDhikrs.isEmpty {
                EmptyStateView(
                    symbol: "text.magnifyingglass",
                    title: "No matches found",
                    message: "Try another title, translation, transliteration, or Arabic phrase."
                )
            } else if usesGroupedDisplay {
                LazyVStack(alignment: .leading, spacing: 12, pinnedViews: [.sectionHeaders]) {
                    ForEach(populatedCategories) { category in
                        let dhikrs = sortedDhikrs(store.dhikrs.filter { $0.category == category })
                        if !dhikrs.isEmpty {
                            Section {
                                ForEach(dhikrs) { dhikr in
                                    DhikrCard(dhikr: dhikr, language: language) {
                                        router.navigate(.dhikrDetail(dhikr.id), in: .library)
                                    }
                                }
                            } header: {
                                LibraryCategoryHeader(
                                    title: category.title,
                                    subtitle: AwradLocalizer.dhikrCount(dhikrs.count, language: language)
                                )
                            }
                        }
                    }
                }
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(filteredDhikrs) { dhikr in
                        DhikrCard(dhikr: dhikr, language: language) {
                            router.navigate(.dhikrDetail(dhikr.id), in: .library)
                        }
                    }
                }
            }
        }
    }

    private func sortedDhikrs(_ dhikrs: [Dhikr]) -> [Dhikr] {
        dhikrs.sorted {
            if $0.category != $1.category {
                return $0.category.sortRank < $1.category.sortRank
            }
            return $0.displayTitle(language: language).localizedCaseInsensitiveCompare($1.displayTitle(language: language)) == .orderedAscending
        }
    }

    private func hideSearchIfEmpty() {
        guard searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isSearchVisible = false
        isSearchFocused = false
    }
}

private struct FeaturedDhikrCollection: Identifiable {
    enum Tone {
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

    static func collections(categoryCounts: [DhikrCategory: Int]) -> [FeaturedDhikrCollection] {
        let dailyCategory: DhikrCategory = (categoryCounts[.morning] ?? 0) > 0 ? .morning : .praise
        let dailyCount = (categoryCounts[.morning] ?? 0) > 0
            ? (categoryCounts[.morning] ?? 0)
            : count(categoryCounts, categories: [.praise, .forgiveness, .quran])

        return [
            FeaturedDhikrCollection(
                title: "Daily Essentials",
                category: dailyCategory,
                count: dailyCount,
                tone: .daily
            ),
            FeaturedDhikrCollection(
                title: "Swalaths",
                category: .swalaths,
                count: categoryCounts[.swalaths] ?? 0,
                tone: .swalaths
            ),
            FeaturedDhikrCollection(
                title: "Dhikrs",
                category: .praise,
                count: count(categoryCounts, categories: [.praise, .forgiveness, .general]),
                tone: .dhikrs
            ),
            FeaturedDhikrCollection(
                title: "Evening Dhikrs",
                category: .evening,
                count: categoryCounts[.evening] ?? 0,
                tone: .evening
            ),
            FeaturedDhikrCollection(
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

private struct LibraryFeaturedCollectionCard: View {
    let collection: FeaturedDhikrCollection
    let language: AppLanguage
    let isDark: Bool

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
                Text(LocalizedStringKey(collection.title))
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
        switch collection.tone {
        case .daily:
            return "collection_daily_essentials_\(suffix)"
        case .swalaths:
            return "collection_swalaths_\(suffix)"
        case .dhikrs:
            return "collection_dhikrs_\(suffix)"
        case .evening:
            return "collection_evening_dhikrs_\(suffix)"
        case .prayer:
            return "collection_after_prayer_\(suffix)"
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

struct CategoryDhikrsView: View {
    @Environment(AwradStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(AppServices.self) private var services
    let category: DhikrCategory
    @State private var showAudioError = false
    private var language: AppLanguage { store.preferences.appLanguage }

    private var categoryDhikrs: [Dhikr] {
        store.dhikrs
            .filter { $0.category == category }
            .sorted { $0.displayTitle(language: language).localizedCaseInsensitiveCompare($1.displayTitle(language: language)) == .orderedAscending }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeader(
                    title: category.title,
                    subtitle: category.descriptionKey,
                    actionTitle: nil,
                    action: nil
                )

                if categoryDhikrs.isEmpty {
                    EmptyStateView(
                        symbol: category.symbol,
                        title: "No dhikrs in library",
                        message: "Audio files will appear here when available."
                    )
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(categoryDhikrs) { dhikr in
                            DhikrCard(dhikr: dhikr, language: language) {
                                router.navigate(.dhikrDetail(dhikr.id), in: .library)
                            }
                        }
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 96)
        }
        .background(AwradTheme.background)
        .navigationTitle(LocalizedStringKey(category.title))
        .onChange(of: services.audio.errorMessage) { _, newValue in
            showAudioError = newValue != nil
        }
        .alert("Audio Error", isPresented: $showAudioError) {
            Button("OK") {
                services.audio.stop()
            }
        } message: {
            Text(services.audio.errorMessage ?? "Audio playback failed.")
        }
    }
}

struct DhikrDetailView: View {
    @Environment(AwradStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(AppServices.self) private var services
    let dhikrID: AwradID
    @State private var isDownloadingAudio = false
    @State private var audioErrorMessage: String?
    @State private var showAudioError = false
    @State private var showDeleteConfirmation = false
    @State private var pendingSuggestedGoal: DhikrSuggestedGoal?

    var body: some View {
        ScrollView {
            if let dhikr = store.dhikr(id: dhikrID) {
                let language = store.preferences.appLanguage
                let guidance = DhikrGuidanceRegistry.guidance(for: dhikr, language: language)
                VStack(alignment: .leading, spacing: 20) {
                    AwradCard {
                        VStack(spacing: 18) {
                            Text(dhikr.arabic)
                                .font(AwradTheme.arabicFont(34))
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .environment(\.layoutDirection, .rightToLeft)
                            Text(dhikr.transliteration)
                                .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(AwradTheme.sage)
                            Text(dhikr.displayTranslation(language: language))
                                .font(AwradTheme.bodyFont(.body))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }

                    audioPreviewCard(for: dhikr)

                    if !guidance.benefits.isEmpty {
                        benefitsCard(guidance.benefits)
                    }

                    if !guidance.suggestedGoals.isEmpty {
                        suggestedGoalsCard(for: dhikr, suggestions: guidance.suggestedGoals)
                    }

                    Button {
                        if let goal = store.goals(for: dhikr.id).first {
                            router.navigate(.counting(goalID: goal.id), in: store.selectedTab)
                        } else {
                            router.navigate(.createGoal(dhikrID: dhikr.id), in: store.selectedTab)
                        }
                    } label: {
                        Label(store.goals(for: dhikr.id).isEmpty ? "Create Goal" : "Open Counter", systemImage: "target")
                            .frame(maxWidth: .infinity)
                    }
                    .awradPrimaryButton()
                }
                .padding(20)
                .padding(.bottom, 96)
            } else {
                EmptyStateView(symbol: "exclamationmark.triangle", title: "Not Found", message: "This dhikr is no longer available.")
                    .padding(20)
                    .padding(.bottom, 96)
            }
        }
        .background(AwradTheme.background)
        .navigationTitle("Dhikr")
        .toolbar {
            if let dhikr = store.dhikr(id: dhikrID), dhikr.isCustom {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Edit Dhikr", systemImage: "pencil", action: editDhikr)
                        Button("Delete Dhikr", systemImage: "trash", role: .destructive) {
                            showDeleteConfirmation = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Dhikr actions")
                }
            }
        }
        .confirmationDialog("Delete Dhikr", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Dhikr and Goals", role: .destructive, action: deleteDhikr)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the personal dhikr, linked goals, reminders, and counts.")
        }
        .confirmationDialog(
            "Add Suggested Goal",
            isPresented: suggestedGoalConfirmationBinding,
            titleVisibility: .visible,
            presenting: pendingSuggestedGoal
        ) { suggestion in
            Button("Add Goal") {
                addSuggestedGoal(suggestion)
            }
            Button("Cancel", role: .cancel) {
                pendingSuggestedGoal = nil
            }
        } message: { suggestion in
            Text(suggestion.description)
        }
        .onChange(of: services.audio.errorMessage) { _, newValue in
            guard services.audio.isPreviewing(dhikrID) else { return }
            audioErrorMessage = newValue
            showAudioError = newValue != nil
        }
        .alert("Audio Error", isPresented: $showAudioError) {
            Button("OK") {
                services.audio.stop()
                audioErrorMessage = nil
            }
        } message: {
            Text(audioErrorMessage ?? "Audio playback failed.")
        }
    }

    private var suggestedGoalConfirmationBinding: Binding<Bool> {
        Binding(
            get: { pendingSuggestedGoal != nil },
            set: { isPresented in
                if !isPresented {
                    pendingSuggestedGoal = nil
                }
            }
        )
    }

    private func editDhikr() {
        router.navigate(.editDhikr(dhikrID), in: store.selectedTab)
    }

    private func deleteDhikr() {
        services.audio.stop()
        guard let removedGoalIDs = store.deleteCustomDhikr(dhikrID) else { return }
        Task {
            for goalID in removedGoalIDs {
                await services.notifications.cancelGoalReminders(goalID: goalID)
            }
        }
        router.popToRoot(in: store.selectedTab)
    }

    private func benefitsCard(_ benefits: [DhikrBenefitDetail]) -> some View {
        AwradCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Benefits")
                    .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                ForEach(benefits) { benefit in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "leaf.fill")
                            .foregroundStyle(AwradTheme.sage)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(benefit.title)
                                .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                                .foregroundStyle(AwradTheme.ink)
                            Text(benefit.description)
                                .font(AwradTheme.bodyFont(.caption))
                                .foregroundStyle(.secondary)
                            if let source = benefit.source {
                                Text(source)
                                    .font(AwradTheme.bodyFont(.caption2, weight: .semibold))
                                    .foregroundStyle(AwradTheme.gold)
                            }
                        }
                    }
                }
            }
        }
    }

    private func suggestedGoalsCard(for dhikr: Dhikr, suggestions: [DhikrSuggestedGoal]) -> some View {
        AwradCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Suggested Goals")
                    .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                ForEach(suggestions) { suggestion in
                    let existingGoal = matchingGoal(for: suggestion, dhikrID: dhikr.id)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: suggestion.targetPolicy == .cumulativeTotal ? "flag.checkered" : "calendar.badge.checkmark")
                                .font(AwradTheme.bodyFont(20, weight: .semibold))
                                .foregroundStyle(AwradTheme.sage)
                                .frame(width: 34, height: 34)
                                .background(AwradTheme.sage.opacity(0.12), in: Circle())
                            VStack(alignment: .leading, spacing: 4) {
                                Text(suggestion.label)
                                    .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                                    .foregroundStyle(AwradTheme.ink)
                                Text(suggestion.description)
                                    .font(AwradTheme.bodyFont(.caption))
                                    .foregroundStyle(.secondary)
                                Text(suggestedGoalMetadata(suggestion))
                                    .font(AwradTheme.bodyFont(.caption2, weight: .semibold))
                                    .foregroundStyle(AwradTheme.gold)
                            }
                            Spacer()
                        }

                        Button {
                            if let existingGoal {
                                router.navigate(.counting(goalID: existingGoal.id), in: store.selectedTab)
                            } else {
                                pendingSuggestedGoal = suggestion
                            }
                        } label: {
                            Text(LocalizedStringKey(existingGoal == nil ? "Add Goal" : "Already Added"))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        .tint(existingGoal == nil ? AwradTheme.sage : .secondary)
                    }
                    .padding(.vertical, 4)

                    if suggestion.id != suggestions.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private func suggestedGoalMetadata(_ suggestion: DhikrSuggestedGoal) -> String {
        let language = store.preferences.appLanguage
        let recurrence = AwradLocalizer.localized(
            suggestion.targetPolicy == .cumulativeTotal ? "One-time total" : "Daily",
            language: language
        )
        let count = AwradLocalizer.format("%d recitations", language: language, suggestion.targetCount)
        return "\(recurrence) · \(count)"
    }

    private func matchingGoal(for suggestion: DhikrSuggestedGoal, dhikrID: AwradID) -> Goal? {
        store.allGoals(for: dhikrID).first { goal in
            goal.targetPolicy == suggestion.targetPolicy &&
                goal.recurrence.frequency == suggestion.frequency &&
                goal.totalTarget == suggestion.targetCount
        }
    }

    private func addSuggestedGoal(_ suggestion: DhikrSuggestedGoal) {
        guard let goal = store.createConfiguredGoal(
            dhikrID: dhikrID,
            targetPolicy: suggestion.targetPolicy,
            recurrence: GoalRecurrence(frequency: suggestion.frequency),
            slots: [
                GoalSlot(
                    slotType: .anytime,
                    targetCount: suggestion.targetCount,
                    sortOrder: 0
                )
            ],
            autoCompleteOnTarget: suggestion.targetPolicy == .cumulativeTotal
        ) else {
            pendingSuggestedGoal = nil
            return
        }

        pendingSuggestedGoal = nil
        router.navigate(.counting(goalID: goal.id), in: store.selectedTab)
    }

    private func audioPreviewCard(for dhikr: Dhikr) -> some View {
        Group {
            if dhikr.audioURL != nil || dhikr.isDownloaded {
                AwradCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: dhikr.isDownloaded ? "checkmark.circle.fill" : "waveform.circle.fill")
                                .font(AwradTheme.bodyFont(26))
                                .foregroundStyle(dhikr.isDownloaded ? AwradTheme.sage : AwradTheme.gold)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Audio")
                                    .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                                Text(dhikr.isDownloaded ? "Available offline" : "Streams until downloaded")
                                    .font(AwradTheme.bodyFont(.caption))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }

                        if services.audio.isPreviewing(dhikr.id) {
                            ProgressView(value: services.audio.progress)
                                .tint(AwradTheme.sage)
                            HStack {
                                Text(services.audio.elapsedText)
                                Spacer()
                                Text(services.audio.durationText)
                            }
                            .font(AwradTheme.bodyFont(.caption).monospacedDigit())
                            .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 12) {
                            Button {
                                services.audio.togglePreview(
                                    for: dhikr,
                                    title: dhikr.displayTitle(language: store.preferences.appLanguage)
                                )
                            } label: {
                                Label(previewButtonTitle(for: dhikr), systemImage: previewButtonSymbol(for: dhikr))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .tint(AwradTheme.sage)

                            if dhikr.audioURL != nil, !dhikr.isDownloaded {
                                Button {
                                    downloadAudio(for: dhikr)
                                } label: {
                                    if isDownloadingAudio {
                                        ProgressView()
                                            .frame(width: 46, height: 46)
                                    } else {
                                        Image(systemName: "arrow.down.circle.fill")
                                            .frame(width: 46, height: 46)
                                    }
                                }
                                .buttonStyle(.bordered)
                                .tint(AwradTheme.sage)
                                .disabled(isDownloadingAudio)
                                .accessibilityLabel("Download audio")
                            }
                        }
                    }
                }
            }
        }
    }

    private func previewButtonTitle(for dhikr: Dhikr) -> String {
        guard services.audio.isPreviewing(dhikr.id) else { return "Preview" }
        return services.audio.isPlaying ? "Pause" : "Resume"
    }

    private func previewButtonSymbol(for dhikr: Dhikr) -> String {
        guard services.audio.isPreviewing(dhikr.id) else { return "play.fill" }
        return services.audio.isPlaying ? "pause.fill" : "play.fill"
    }

    private func downloadAudio(for dhikr: Dhikr) {
        guard let url = dhikr.audioURL else { return }
        isDownloadingAudio = true
        Task {
            do {
                let fileName = try await services.audio.downloadAudio(from: url, suggestedFileName: dhikr.audioFileName)
                store.markDhikrAudioDownloaded(dhikrID: dhikr.id, fileName: fileName)
            } catch {
                audioErrorMessage = error.localizedDescription
                showAudioError = true
            }
            isDownloadingAudio = false
        }
    }
}

private struct DhikrCard: View {
    @Environment(AppServices.self) private var services
    let dhikr: Dhikr
    let language: AppLanguage
    let action: () -> Void

    var body: some View {
        AwradCard {
            VStack(spacing: 10) {
                HStack(alignment: .top, spacing: 14) {
                    Button(action: action) {
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: dhikr.category.symbol)
                                .font(AwradTheme.bodyFont(18, weight: .semibold))
                                .foregroundStyle(AwradTheme.gold)
                                .frame(width: 38, height: 38)
                                .background(AwradTheme.gold.opacity(0.14), in: Circle())
                            VStack(alignment: .leading, spacing: 6) {
                                Text(dhikr.displayTitle(language: language))
                                    .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                                    .foregroundStyle(AwradTheme.ink)
                                    .lineLimit(1)
                                if dhikr.isCustom {
                                    Label("Personal", systemImage: "person.crop.circle.fill")
                                        .font(AwradTheme.bodyFont(.caption, weight: .semibold))
                                        .foregroundStyle(AwradTheme.sage)
                                }
                                if canPreviewAudio {
                                    Label(dhikr.isDownloaded ? "Offline audio" : "Audio", systemImage: dhikr.isDownloaded ? "checkmark.circle.fill" : "waveform")
                                        .font(AwradTheme.bodyFont(.caption, weight: .semibold))
                                        .foregroundStyle(dhikr.isDownloaded ? AwradTheme.sage : AwradTheme.gold)
                                }
                                Text(dhikr.arabic)
                                    .font(AwradTheme.arabicFont(24))
                                    .foregroundStyle(AwradTheme.sageDark)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                    .environment(\.layoutDirection, .rightToLeft)
                                Text(dhikr.displayTranslation(language: language))
                                    .font(AwradTheme.bodyFont(.caption))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(AwradLocalizer.format("Open %@", language: language, dhikr.displayTitle(language: language)))

                    if canPreviewAudio {
                        Button {
                            services.audio.togglePreview(for: dhikr, title: dhikr.displayTitle(language: language))
                        } label: {
                            Image(systemName: previewButtonSymbol)
                                .font(AwradTheme.bodyFont(16, weight: .bold))
                                .foregroundStyle(isPreviewing ? .white : AwradTheme.sage)
                                .frame(width: 42, height: 42)
                                .background(isPreviewing ? AwradTheme.sage : AwradTheme.mint.opacity(0.2), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(LocalizedStringKey(isPreviewing && services.audio.isPlaying ? "Pause audio preview" : "Play audio preview")))
                    }
                }

                if isPreviewing {
                    ProgressView(value: services.audio.progress)
                        .tint(AwradTheme.sage)
                    HStack {
                        Text(services.audio.elapsedText)
                        Spacer()
                        Text(services.audio.durationText)
                    }
                    .font(AwradTheme.bodyFont(.caption).monospacedDigit())
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var canPreviewAudio: Bool {
        services.audio.sourceURL(for: dhikr) != nil
    }

    private var isPreviewing: Bool {
        services.audio.isPreviewing(dhikr.id)
    }

    private var previewButtonSymbol: String {
        guard isPreviewing else { return "play.fill" }
        return services.audio.isPlaying ? "pause.fill" : "play.fill"
    }
}

private struct LibraryCategoryHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .lastTextBaseline) {
            Text(LocalizedStringKey(title))
                .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                .foregroundStyle(AwradTheme.ink)
            Spacer()
            Text(subtitle)
                .font(AwradTheme.bodyFont(.caption))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .background(AwradTheme.background)
    }
}

private struct LibraryDhikrListHeader: View {
    let title: String
    let count: String

    var body: some View {
        HStack(alignment: .lastTextBaseline) {
            Text(LocalizedStringKey(title))
                .font(AwradTheme.displayFont(20))
                .foregroundStyle(AwradTheme.ink)
                .lineLimit(1)
            Spacer(minLength: 12)
            Text(count)
                .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                .foregroundStyle(AwradTheme.sage)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
    }
}

private struct CategoryChip: View {
    let title: String
    let symbol: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text(LocalizedStringKey(title))
            } icon: {
                Image(systemName: symbol)
            }
                .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .foregroundStyle(isSelected ? .white : AwradTheme.sage)
                .background(isSelected ? AwradTheme.sage : AwradTheme.surface, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private extension DhikrCategory {
    var sortRank: Int {
        DhikrCategory.allCases.firstIndex(of: self) ?? 0
    }

    var descriptionKey: String {
        switch self {
        case .morning:
            "Morning remembrances for starting the day."
        case .evening:
            "Evening remembrances for closing the day."
        case .afterSalah:
            "Dhikrs connected to the prayers."
        case .forgiveness:
            "Istighfar and repentance-focused remembrances."
        case .praise:
            "Tasbih, tahleel, and praise formulas."
        case .protection:
            "Protective remembrances and supplications."
        case .general:
            "General dhikrs for regular counting."
        case .swalaths:
            "Blessings and prayers upon the Prophet ﷺ."
        case .ramadan:
            "Seasonal remembrances for Ramadan."
        case .quran:
            "Quranic recitations and short surahs."
        }
    }
}
