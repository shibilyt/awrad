import SwiftUI

struct LibraryView: View {
    private enum Segment: String, CaseIterable, Identifiable {
        case dhikrs = "Dhikrs"
        case wirds = "Wirds"

        var id: String { rawValue }
    }

    @Environment(AwradStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(AppServices.self) private var services
    @Environment(\.colorScheme) private var colorScheme
    @State private var searchText = ""
    @State private var selectedCategory: DhikrCategory?
    @State private var collectionScope: LibraryCollectionScope = .all
    @State private var selectedTagIDs: Set<AwradID> = []
    @State private var selectedSegment: Segment = .dhikrs
    @State private var pagerPosition: CGFloat = 0
    @State private var isSearchVisible = false
    @State private var showAudioError = false
    @FocusState private var isSearchFocused: Bool
    private var language: AppLanguage { store.preferences.appLanguage }

    private var filteredDhikrs: [Dhikr] {
        LibraryCatalogPolicy.filtered(
            store.dhikrs,
            query: searchText,
            category: selectedCategory,
            language: language,
            collectionScope: collectionScope,
            selectedTagIDs: selectedTagIDs,
            tags: store.userTags,
            assignments: store.tagAssignments
        )
    }

    private var customDhikrCount: Int {
        store.dhikrs.filter(\.isCustom).count
    }

    private var categoryCounts: [DhikrCategory: Int] {
        Dictionary(grouping: store.dhikrs, by: \.category)
            .mapValues(\.count)
    }

    private var featuredCollections: [FeaturedDhikrCollection] {
        FeaturedDhikrCollection.collections(
            categoryCounts: categoryCounts,
            customCount: customDhikrCount
        )
    }

    private var shouldShowSearchField: Bool {
        isSearchVisible || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var segmentSelection: Binding<Segment> {
        Binding(
            get: { selectedSegment },
            set: { segment in
                selectedSegment = segment
                if segment == .wirds {
                    isSearchFocused = false
                }
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                libraryHeader
                AwradPagerTabs(
                    selection: segmentSelection,
                    options: Segment.allCases,
                    position: pagerPosition,
                    title: { $0.rawValue }
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .background(AwradTheme.surface)

            AwradPager(
                selection: segmentSelection,
                options: Segment.allCases,
                position: $pagerPosition,
                accessibilityIdentifier: "library.pager"
            ) { segment in
                switch segment {
                case .dhikrs:
                    dhikrPane
                case .wirds:
                    WirdListView(showsCreateButton: false)
                        .refreshable {
                            await refreshProgressFromCloud()
                        }
                }
            }
            .background(AwradTheme.background)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
        }
        .background(AwradTheme.surface)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .bottomTrailing) {
            if selectedSegment == .wirds {
                Button {
                    router.navigate(.createWird, in: .library)
                } label: {
                    Image(systemName: "plus")
                        .font(AwradTheme.bodyFont(21, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(AwradTheme.sage, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Create wird")
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            } else if selectedSegment == .dhikrs {
                Button {
                    router.navigate(.createDhikr, in: .library)
                } label: {
                    Image(systemName: "plus")
                        .font(AwradTheme.bodyFont(21, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(AwradTheme.sage, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Create Dhikr")
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
        }
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

    private var dhikrPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if shouldShowSearchField {
                    librarySearchField
                }
                tagFilterSection
                featuredCollectionSection
                dhikrList
            }
            .padding(20)
            .padding(.bottom, 96)
        }
        .refreshable {
            await refreshProgressFromCloud()
        }
        .background(AwradTheme.background)
    }

    private func refreshProgressFromCloud() async {
        guard services.auth.isLoggedIn else { return }
        await services.progressSync.synchronize(store: store)
    }

    private var libraryHeader: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Library")
                    .font(AwradTheme.displayFont(34, weight: .bold))
                    .foregroundStyle(AwradTheme.ink)
                    .lineLimit(1)
            }
            Spacer(minLength: 12)
            Button {
                withAnimation(.snappy(duration: 0.22)) {
                    selectedSegment = .dhikrs
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

    private var catalogFilters: LibraryCatalogFilters {
        LibraryCatalogFilters(
            query: searchText,
            category: selectedCategory,
            collectionScope: collectionScope,
            selectedTagIDs: selectedTagIDs
        )
    }

    private var sortedUserTags: [UserTag] {
        store.userTags.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    @ViewBuilder
    private var tagFilterSection: some View {
        if !sortedUserTags.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Filter by tags")
                    .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                    .foregroundStyle(AwradTheme.ink)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(sortedUserTags) { tag in
                            let selected = selectedTagIDs.contains(tag.id)
                            Button {
                                var filters = catalogFilters
                                LibraryTagFilterControls.toggle(tag.id, in: &filters)
                                selectedTagIDs = filters.selectedTagIDs
                                hideSearchIfEmpty()
                            } label: {
                                Label {
                                    Text(tag.name)
                                } icon: {
                                    Image(systemName: selected ? "tag.fill" : "tag")
                                }
                                .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .foregroundStyle(selected ? .white : AwradTheme.sage)
                                .background(selected ? AwradTheme.sage : AwradTheme.surface, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(tag.name)
                            .accessibilityValue(selected ? "Selected" : "Not selected")
                            .accessibilityHint("Filters library with AND tag semantics")
                            .accessibilityAddTraits(selected ? .isSelected : [])
                        }
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(
                LibraryFilterAccessibility.summary(
                    filters: catalogFilters,
                    tags: sortedUserTags
                )
            )
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
                collectionScope = .all
                selectedTagIDs = []
                searchText = ""
                isSearchVisible = false
                isSearchFocused = false
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(featuredCollections) { collection in
                        Button {
                            if collection.isYourDhikrs {
                                collectionScope = .yourDhikrs
                                selectedCategory = nil
                            } else {
                                collectionScope = .all
                                selectedCategory = collection.category
                            }
                            searchText = ""
                            selectedTagIDs = []
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

    private var dhikrList: some View {
        VStack(alignment: .leading, spacing: 12) {
            LibraryDhikrListHeader(
                title: listTitle,
                count: AwradLocalizer.dhikrCount(filteredDhikrs.count, language: language)
            )

            if collectionScope == .yourDhikrs, customDhikrCount == 0 {
                EmptyStateView(
                    symbol: "sparkles",
                    title: "No personal dhikrs yet",
                    message: "Create a dhikr with your own text and optional imported audio."
                )
                Button {
                    router.navigate(.createDhikr, in: .library)
                } label: {
                    Label("Create Dhikr", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .awradPrimaryButton()
                .accessibilityLabel("Create Dhikr")
            } else if store.dhikrs.isEmpty {
                EmptyStateView(
                    symbol: "text.book.closed",
                    title: "No dhikrs in library",
                    message: "Your library is empty. Add a personal dhikr or restart after content setup."
                )
            } else if filteredDhikrs.isEmpty {
                EmptyStateView(
                    symbol: "text.magnifyingglass",
                    title: "No matches found",
                    message: "Try another title, translation, transliteration, Arabic phrase, or clear filters."
                )
                Button {
                    clearFilters()
                } label: {
                    Label("Clear filters", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .awradPrimaryButton()
                .opacity(0.9)
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

    private var listTitle: String {
        if collectionScope == .yourDhikrs {
            return "Your Dhikrs"
        }
        return selectedCategory?.title ?? "All dhikrs"
    }

    private func clearFilters() {
        selectedCategory = nil
        collectionScope = .all
        selectedTagIDs = []
        searchText = ""
        isSearchVisible = false
        isSearchFocused = false
    }

    private func hideSearchIfEmpty() {
        guard searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isSearchVisible = false
        isSearchFocused = false
    }
}

private struct FeaturedDhikrCollection: Identifiable {
    enum Tone {
        case asmaUlHusna
        case daily
        case swalaths
        case dhikrs
        case evening
        case prayer
        case custom
    }

    let title: String
    let category: DhikrCategory?
    let count: Int
    let tone: Tone
    var isYourDhikrs: Bool = false

    var id: String { title }

    static func collections(
        categoryCounts: [DhikrCategory: Int],
        customCount: Int
    ) -> [FeaturedDhikrCollection] {
        let dailyCategory: DhikrCategory = (categoryCounts[.morning] ?? 0) > 0 ? .morning : .praise
        let dailyCount = (categoryCounts[.morning] ?? 0) > 0
            ? (categoryCounts[.morning] ?? 0)
            : count(categoryCounts, categories: [.praise, .forgiveness, .quran])

        return [
            FeaturedDhikrCollection(
                title: "Your Dhikrs",
                category: nil,
                count: customCount,
                tone: .custom,
                isYourDhikrs: true
            ),
            FeaturedDhikrCollection(
                title: String(
                    localized: "category.asma_ul_husna",
                    defaultValue: "Asma-ul Husna"
                ),
                category: .asmaUlHusna,
                count: categoryCounts[.asmaUlHusna] ?? 0,
                tone: .asmaUlHusna
            ),
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
        case .asmaUlHusna:
            return "collection_asma_ul_husna_\(suffix)"
        case .daily:
            return "collection_daily_essentials_\(suffix)"
        case .swalaths:
            return "collection_swalaths_\(suffix)"
        case .dhikrs:
            return "collection_dhikrs_\(suffix)"
        case .custom:
            return "collection_your_dhikrs_\(suffix)"
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
        LibraryCatalogPolicy.filtered(
            store.dhikrs,
            query: "",
            category: category,
            language: language
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeader(
                    title: category.title,
                    subtitle: AwradLocalizer.dhikrCount(categoryDhikrs.count, language: language),
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
    let onDownloadedAudioRemoved: ((AwradID) -> Bool)?
    @State private var isDownloadingAudio = false
    @State private var audioErrorMessage: String?
    @State private var showAudioError = false
    @State private var showDeleteConfirmation = false
    @State private var showRemoveAudioConfirmation = false
    @State private var showManageTags = false
    @State private var audioCacheRevision = 0
    @State private var pendingSuggestedGoal: DhikrSuggestedGoal?

    private var language: AppLanguage { store.preferences.appLanguage }

    private var navigationTitle: String {
        store.dhikr(id: dhikrID)?.displayTitle(language: language)
            ?? AwradLocalizer.localized("Dhikr", language: language)
    }

    init(
        dhikrID: AwradID,
        onDownloadedAudioRemoved: ((AwradID) -> Bool)? = nil
    ) {
        self.dhikrID = dhikrID
        self.onDownloadedAudioRemoved = onDownloadedAudioRemoved
    }

    var body: some View {
        ScrollView {
            if let dhikr = store.dhikr(id: dhikrID) {
                let language = store.preferences.appLanguage
                let guidance = DhikrGuidanceRegistry.guidance(for: dhikr, language: language)
                VStack(alignment: .leading, spacing: 20) {
                    quranAwareTextCard(for: dhikr, language: language)

                    audioPreviewCard(for: dhikr)

                    if !guidance.benefits.isEmpty {
                        benefitsCard(guidance.benefits)
                    }

                    if !guidance.suggestedGoals.isEmpty {
                        suggestedGoalsCard(for: dhikr, suggestions: guidance.suggestedGoals)
                    }

                    tagsSummaryCard(for: dhikr)

                    Button {
                        showManageTags = true
                    } label: {
                        Label("Manage tags", systemImage: "tag.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(AwradTheme.sage)
                    .accessibilityLabel("Manage tags")

                    Button {
                        if let goal = store.goals(for: dhikr.id).first {
                            router.navigate(.counting(goalID: goal.id, slotID: nil), in: store.selectedTab)
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
        .navigationTitle(navigationTitle)
        .toolbar {
            if let dhikr = store.dhikr(id: dhikrID) {
                ToolbarItem(placement: .topBarTrailing) {
                    if dhikr.isCustom {
                        Menu {
                            Button("Manage tags", systemImage: "tag.fill") {
                                showManageTags = true
                            }
                            Button("Edit Dhikr", systemImage: "pencil", action: editDhikr)
                            Button("Delete Dhikr", systemImage: "trash", role: .destructive) {
                                showDeleteConfirmation = true
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .accessibilityLabel("Dhikr actions")
                    } else {
                        Button {
                            showManageTags = true
                        } label: {
                            Image(systemName: "tag.fill")
                        }
                        .accessibilityLabel("Manage tags")
                    }
                }
            }
        }
        .sheet(isPresented: $showManageTags) {
            ManageTagsView(dhikrID: dhikrID)
                .environment(store)
        }
        .confirmationDialog("Delete Dhikr", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Dhikr and Goals", role: .destructive, action: deleteDhikr)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(CustomDhikrDeletionCopy.warningResource)
        }
        .confirmationDialog("Remove downloaded audio?", isPresented: $showRemoveAudioConfirmation, titleVisibility: .visible) {
            Button("Remove Download", role: .destructive, action: removeDownloadedAudio)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The recitation can still stream while you are online.")
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

    @ViewBuilder
    private func quranAwareTextCard(for dhikr: Dhikr, language: AppLanguage) -> some View {
        let reference = dhikr.quranRef.flatMap { QuranDhikrReadingPolicy.isValid($0) ? $0 : nil }
        let splitText = QuranDhikrReadingPolicy.splitBismillah(dhikr.arabic)
        let rendersFully = reference.map {
            QuranDhikrReadingPolicy.shouldRenderFullyInline(reference: $0, arabic: dhikr.arabic)
        } ?? true

        VStack(alignment: .leading, spacing: 16) {
            AwradCard {
                VStack(spacing: 12) {
                    if let bismillah = splitText.bismillah {
                        Text(bismillah)
                            .font(AwradTheme.arabicFont(25))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .environment(\.layoutDirection, .rightToLeft)
                    }

                    Text(splitText.body)
                        .font(AwradTheme.arabicFont(reference == nil ? 34 : 29))
                        .multilineTextAlignment(.center)
                        .lineSpacing(8)
                        .lineLimit(rendersFully ? nil : 4)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity)
                        .environment(\.layoutDirection, .rightToLeft)

                    if reference != nil, !rendersFully {
                        Button("See full") {
                            router.navigate(
                                .quranDhikrReader(dhikrID: dhikr.id, goalID: nil, slotID: nil),
                                in: store.selectedTab
                            )
                        }
                        .buttonStyle(.bordered)
                        .tint(AwradTheme.sage)
                        .accessibilityHint("Opens the Quran reader")
                    }
                }
                .padding(.vertical, 16)
            }

            if !dhikr.transliteration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text("TRANSLITERATION")
                        .font(AwradTheme.bodyFont(.caption2, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(AwradTheme.sage)
                    Text(dhikr.transliteration)
                        .font(AwradTheme.bodyFont(.body))
                        .italic()
                        .foregroundStyle(AwradTheme.ink)
                }
            }

            let translation = dhikr.displayTranslation(language: language)
            if !translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               translation != dhikr.displayTitle(language: language),
               translation != dhikr.transliteration {
                VStack(alignment: .leading, spacing: 5) {
                    Text("MEANING")
                        .font(AwradTheme.bodyFont(.caption2, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(AwradTheme.gold)
                    Text(translation)
                        .font(AwradTheme.bodyFont(.body))
                        .foregroundStyle(.secondary)
                }
            }
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

    private func tagsSummaryCard(for dhikr: Dhikr) -> some View {
        let assigned = store.userTags
            .filter { tag in
                store.tagAssignments.contains { $0.dhikrID == dhikr.id && $0.tagID == tag.id }
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        return AwradCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Tags", systemImage: "tag.fill")
                    .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                if assigned.isEmpty {
                    Text("No tags assigned yet.")
                        .font(AwradTheme.bodyFont(.subheadline))
                        .foregroundStyle(.secondary)
                } else {
                    FlowTagChips(names: assigned.map(\.name))
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            assigned.isEmpty
                ? "No tags assigned yet"
                : "Tags: \(assigned.map(\.name).joined(separator: ", "))"
        )
    }

    private func deleteDhikr() {
        services.audio.stop()
        guard let removedGoalIDs = store.deleteCustomDhikr(dhikrID) else { return }
        Task {
            _ = await services.refreshNotifications(
                store: store,
                change: .init(goalIDs: Set(removedGoalIDs), reason: .goalMutation)
            )
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
                                router.navigate(.counting(goalID: existingGoal.id, slotID: nil), in: store.selectedTab)
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
        router.navigate(.counting(goalID: goal.id, slotID: nil), in: store.selectedTab)
    }

    private func audioPreviewCard(for dhikr: Dhikr) -> some View {
        let availability = audioAvailability(for: dhikr)
        return AwradCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: audioStatusSymbol(availability))
                        .font(AwradTheme.bodyFont(26))
                        .foregroundStyle(audioStatusColor(availability))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Audio")
                            .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                        Text(audioStatusTitle(availability))
                            .font(AwradTheme.bodyFont(.caption))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                if availability == .unavailable {
                    Text("This dhikr does not have a recitation yet. Reading and goal creation remain available.")
                        .font(AwradTheme.bodyFont(.caption))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else if availability == .missingOwned {
                    Text("Owned audio is missing on this device. Reattach a file or remove the broken attachment.")
                        .font(AwradTheme.bodyFont(.caption))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 12) {
                        Button {
                            router.navigate(.editDhikr(dhikr.id), in: store.selectedTab)
                        } label: {
                            Label("Reattach audio", systemImage: "square.and.arrow.down")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AwradTheme.sage)
                        .accessibilityLabel("Reattach audio")

                        Button(role: .destructive) {
                            _ = store.removeOwnedAudio(from: dhikr.id)
                            audioCacheRevision += 1
                        } label: {
                            Label("Remove audio", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Remove missing owned audio")
                    }
                } else {
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

                        switch availability {
                        case .streaming:
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
                        case .downloaded:
                            Button(role: .destructive) {
                                if store.audioAsset(for: dhikr.id) != nil {
                                    _ = store.removeOwnedAudio(from: dhikr.id)
                                    audioCacheRevision += 1
                                } else {
                                    showRemoveAudioConfirmation = true
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .frame(width: 46, height: 46)
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel("Remove downloaded audio")
                        case .missingOwned, .unavailable:
                            EmptyView()
                        }
                    }
                }
            }
        }
    }

    private func audioAvailability(for dhikr: Dhikr) -> LibraryAudioAvailability {
        _ = audioCacheRevision
        let catalogLocalExists = dhikr.audioFileName.flatMap { services.audio.localAudioURL(fileName: $0) } != nil
        return LibraryCatalogPolicy.resolvedLibraryAudioAvailability(
            dhikr: dhikr,
            ownedAsset: store.audioAsset(for: dhikr.id),
            resolveOwnedURL: store.ownedAudioStore.resolvePlayableURL(for:),
            catalogLocalExists: catalogLocalExists
        )
    }

    private func audioStatusTitle(_ availability: LibraryAudioAvailability) -> LocalizedStringKey {
        switch availability {
        case .downloaded: "Available offline"
        case .streaming: "Streams until downloaded"
        case .missingOwned: "Owned audio missing"
        case .unavailable: "Audio unavailable"
        }
    }

    private func audioStatusSymbol(_ availability: LibraryAudioAvailability) -> String {
        switch availability {
        case .downloaded: "checkmark.circle.fill"
        case .streaming: "waveform.circle.fill"
        case .missingOwned: "exclamationmark.triangle.fill"
        case .unavailable: "speaker.slash.circle.fill"
        }
    }

    private func audioStatusColor(_ availability: LibraryAudioAvailability) -> Color {
        switch availability {
        case .downloaded: AwradTheme.sage
        case .streaming: AwradTheme.gold
        case .missingOwned: .orange
        case .unavailable: .secondary
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
                guard store.markDhikrAudioDownloaded(dhikrID: dhikr.id, fileName: fileName) else {
                    if let message = store.persistenceRecovery?.message {
                        audioErrorMessage = message
                        showAudioError = true
                    }
                    isDownloadingAudio = false
                    return
                }
            } catch {
                audioErrorMessage = error.localizedDescription
                showAudioError = true
            }
            isDownloadingAudio = false
        }
    }

    private func removeDownloadedAudio() {
        guard let dhikr = store.dhikr(id: dhikrID),
              let fileName = dhikr.audioFileName,
              let localURL = services.audio.localAudioURL(fileName: fileName) else {
            return
        }

        if services.audio.isPreviewing(dhikrID) {
            services.audio.stop()
        }
        guard onDownloadedAudioRemoved?(dhikrID) != false else {
            if let message = store.persistenceRecovery?.message {
                audioErrorMessage = message
                showAudioError = true
            }
            return
        }
        do {
            try LibraryAudioCache.removeDownloadedFile(at: localURL)
            audioCacheRevision &+= 1
        } catch {
            audioErrorMessage = error.localizedDescription
            showAudioError = true
        }
    }
}

private struct DhikrCard: View {
    @Environment(AwradStore.self) private var store
    @Environment(AppServices.self) private var services
    let dhikr: Dhikr
    let language: AppLanguage
    let action: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Button(action: action) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dhikr.displayTitle(language: language))
                        .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                        .foregroundStyle(AwradTheme.ink)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(AwradTheme.bodyFont(.caption))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text(AwradLocalizer.localized(dhikr.category.title, language: language))
                        .font(AwradTheme.bodyFont(.caption2, weight: .semibold))
                        .foregroundStyle(isPlaying ? AwradTheme.gold : AwradTheme.sage)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(AwradLocalizer.format("Open %@", language: language, dhikr.displayTitle(language: language)))

            Button {
                if canPreviewAudio {
                    services.audio.togglePreview(for: dhikr, title: dhikr.displayTitle(language: language))
                }
            } label: {
                Image(systemName: previewButtonSymbol)
                    .font(AwradTheme.bodyFont(18, weight: .bold))
                    .foregroundStyle(isPlaying ? .white : canPreviewAudio ? AwradTheme.sage : .secondary)
                    .frame(width: 44, height: 44)
                    .background(
                        isPlaying ? AwradTheme.sage : AwradTheme.mint.opacity(canPreviewAudio ? 0.28 : 0.12),
                        in: Circle()
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canPreviewAudio)
            .accessibilityLabel(Text(LocalizedStringKey(
                canPreviewAudio
                    ? (isPlaying ? "Pause audio preview" : "Play audio preview")
                    : "Audio unavailable"
            )))
        }
        .padding(.leading, 18)
        .padding(.trailing, 12)
        .frame(maxWidth: .infinity)
        .frame(height: 84)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AwradTheme.surface)
                .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 6)
        }
    }

    private var subtitle: String {
        let translation = dhikr.displayTranslation(language: language)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return translation.isEmpty
            ? AwradLocalizer.localized(dhikr.category.title, language: language)
            : translation
    }

    private var isPlaying: Bool {
        isPreviewing && services.audio.isPlaying
    }

    private var canPreviewAudio: Bool {
        audioAvailability == .downloaded || audioAvailability == .streaming
    }

    private var audioAvailability: LibraryAudioAvailability {
        let catalogLocalExists = dhikr.audioFileName.flatMap { services.audio.localAudioURL(fileName: $0) } != nil
        return LibraryCatalogPolicy.resolvedLibraryAudioAvailability(
            dhikr: dhikr,
            ownedAsset: store.audioAsset(for: dhikr.id),
            resolveOwnedURL: store.ownedAudioStore.resolvePlayableURL(for:),
            catalogLocalExists: catalogLocalExists
        )
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

private struct FlowTagChips: View {
    let names: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(names, id: \.self) { name in
                Text(name)
                    .font(AwradTheme.bodyFont(.caption, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .foregroundStyle(AwradTheme.sage)
                    .background(AwradTheme.mint.opacity(0.18), in: Capsule())
            }
        }
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
        case .asmaUlHusna:
            String(
                localized: "category.asma_ul_husna.description",
                defaultValue: "The beautiful names of Allah."
            )
        case .ramadan:
            "Seasonal remembrances for Ramadan."
        case .quran:
            "Quranic recitations and short surahs."
        }
    }
}
