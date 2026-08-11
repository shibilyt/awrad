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
            category: nil,
            language: language,
            selectedTagIDs: selectedTagIDs,
            tags: store.userTags,
            assignments: store.tagAssignments
        )
    }

    private var featuredCollections: [LibraryFeaturedCollection] {
        LibraryFeaturedCollection.allCases
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
        .background(AwradTheme.background.ignoresSafeArea(edges: .bottom))
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
            category: nil,
            collectionScope: .all,
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
                selectedTagIDs = []
                searchText = ""
                isSearchVisible = false
                isSearchFocused = false
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(featuredCollections) { collection in
                        Button {
                            router.navigate(.libraryCollection(collection), in: .library)
                        } label: {
                            LibraryFeaturedCollectionCard(
                                collection: collection,
                                count: collection.dhikrs(in: store.dhikrs).count,
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
        "All dhikrs"
    }

    private func clearFilters() {
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

private struct LibraryFeaturedCollectionCard: View {
    let collection: LibraryFeaturedCollection
    let count: Int
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

                Text(AwradLocalizer.dhikrCount(count, language: language))
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
        switch collection {
        case .asmaUlHusna:
            return "collection_asma_ul_husna_\(suffix)"
        case .dailyEssentials:
            return "collection_daily_essentials_\(suffix)"
        case .swalaths:
            return "collection_swalaths_\(suffix)"
        case .dhikrs:
            return "collection_dhikrs_\(suffix)"
        case .yourDhikrs:
            return "collection_your_dhikrs_\(suffix)"
        case .eveningDhikrs:
            return "collection_evening_dhikrs_\(suffix)"
        case .afterPrayer:
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

struct LibraryCollectionView: View {
    @Environment(AwradStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(AppServices.self) private var services
    let collection: LibraryFeaturedCollection
    @State private var showAudioError = false
    private var language: AppLanguage { store.preferences.appLanguage }

    private var collectionDhikrs: [Dhikr] {
        collection.dhikrs(in: store.dhikrs)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeader(
                    title: collection.title,
                    subtitle: AwradLocalizer.dhikrCount(collectionDhikrs.count, language: language),
                    actionTitle: nil,
                    action: nil
                )

                if collectionDhikrs.isEmpty {
                    EmptyStateView(
                        symbol: collection.symbol,
                        title: collection == .yourDhikrs ? "No personal dhikrs yet" : "No dhikrs in library",
                        message: collection == .yourDhikrs
                            ? "Create a dhikr with your own text and optional imported audio."
                            : "Audio files will appear here when available."
                    )

                    if collection == .yourDhikrs {
                        Button {
                            router.navigate(.createDhikr, in: .library)
                        } label: {
                            Label("Create Dhikr", systemImage: "plus.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .awradPrimaryButton()
                        .accessibilityLabel("Create Dhikr")
                    }
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(collectionDhikrs) { dhikr in
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
        .navigationTitle(LocalizedStringKey(collection.title))
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
    @Environment(\.dismiss) private var dismiss
    let dhikrID: AwradID
    let onDownloadedAudioRemoved: ((AwradID) -> Bool)?
    @State private var isDownloadingAudio = false
    @State private var audioErrorMessage: String?
    @State private var showAudioError = false
    @State private var showDeleteConfirmation = false
    @State private var showRemoveAudioConfirmation = false
    @State private var showManageTags = false
    @State private var showActions = false
    @State private var audioCacheRevision = 0
    @State private var pendingSuggestedGoal: DhikrSuggestedGoal?
    @State private var selectedDetailTab: DhikrDetailTab = .about
    @State private var selectedStatsRange: DhikrStatsRange = .thirtyDays

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
                VStack(alignment: .leading, spacing: 16) {
                    quranAwareTextCard(for: dhikr)

                    DhikrDetailTabs(selection: $selectedDetailTab)

                    if selectedDetailTab == .insights {
                        let goalIDs = Set(store.allGoals(for: dhikrID).map(\.id))
                        let dailyCounts = DhikrStatsCalculator.aggregateGoalCounts(
                            goalIDs: goalIDs,
                            countEntries: store.countEntries
                        )
                        let stats = DhikrStatsCalculator.calculate(
                            dailyCounts: dailyCounts,
                            effectiveToday: store.todayKey,
                            range: selectedStatsRange
                        )
                        DhikrStatsOverview(
                            stats: stats,
                            effectiveTodayKey: store.todayKey,
                            selectedRange: $selectedStatsRange,
                            language: language
                        )
                    } else {
                        aboutContent(for: dhikr, language: language)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 96)
            } else {
                EmptyStateView(symbol: "exclamationmark.triangle", title: "Not Found", message: "This dhikr is no longer available.")
                    .padding(20)
                    .padding(.bottom, 96)
            }
        }
        .background(AwradTheme.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.backward")
                        .font(AwradTheme.bodyFont(16, weight: .bold))
                        .frame(width: 40, height: 40)
                        .background(AwradTheme.surface, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
            }

            ToolbarItem(placement: .principal) {
                Text(navigationTitle)
                    .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            if let dhikr = store.dhikr(id: dhikrID) {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        createGoal(for: dhikr)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("Goal")
                        }
                            .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Create Goal")

                    Button {
                        showActions = true
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(AwradTheme.bodyFont(17, weight: .bold))
                            .frame(width: 40, height: 40)
                            .background(AwradTheme.surface, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dhikr actions")
                }
            }
        }
        .confirmationDialog("Dhikr actions", isPresented: $showActions, titleVisibility: .visible) {
            if let dhikr = store.dhikr(id: dhikrID) {
                Button("Manage tags", systemImage: "tag.fill") {
                    showManageTags = true
                }
                if dhikr.isCustom {
                    Button("Edit Dhikr", systemImage: "pencil", action: editDhikr)
                    Button("Delete Dhikr", systemImage: "trash", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
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
    private func quranAwareTextCard(for dhikr: Dhikr) -> some View {
        let reference = dhikr.quranRef.flatMap { QuranDhikrReadingPolicy.isValid($0) ? $0 : nil }
        let splitText = QuranDhikrReadingPolicy.splitBismillah(dhikr.arabic)
        let rendersFully = reference.map {
            QuranDhikrReadingPolicy.shouldRenderFullyInline(reference: $0, arabic: dhikr.arabic)
        } ?? true

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
                    .font(AwradTheme.arabicFont(reference == nil ? 29 : 27))
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
            .padding(.vertical, 18)
        }
        .accessibilityIdentifier("dhikr_arabic_text")
    }

    @ViewBuilder
    private func aboutContent(for dhikr: Dhikr, language: AppLanguage) -> some View {
        let translation = dhikr.displayTranslation(language: language)
        let guidance = DhikrGuidanceRegistry.guidance(for: dhikr, language: language)

        VStack(alignment: .leading, spacing: 16) {
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

            if audioAvailability(for: dhikr) != .unavailable {
                audioPreviewCard(for: dhikr)
            }

            if !guidance.suggestedGoals.isEmpty {
                suggestedGoalsCard(for: dhikr, suggestions: guidance.suggestedGoals)
            }
        }
    }

    private func createGoal(for dhikr: Dhikr) {
        router.navigate(.createGoal(dhikrID: dhikr.id), in: store.selectedTab)
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
            _ = await services.refreshNotifications(
                store: store,
                change: .init(goalIDs: Set(removedGoalIDs), reason: .goalMutation)
            )
        }
        router.popToRoot(in: store.selectedTab)
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

private enum DhikrDetailTab: String, CaseIterable, Identifiable {
    case about = "About"
    case insights = "Insights"

    var id: String { rawValue }
}

private struct DhikrDetailTabs: View {
    @Binding var selection: DhikrDetailTab

    var body: some View {
        Picker("Dhikr detail section", selection: $selection) {
            ForEach(DhikrDetailTab.allCases) { tab in
                Text(LocalizedStringKey(tab.rawValue)).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("dhikr_detail_tabs")
    }
}

private struct DhikrStatsOverview: View {
    let stats: DhikrPracticeStats
    let effectiveTodayKey: String
    @Binding var selectedRange: DhikrStatsRange
    let language: AppLanguage

    private var activeDateKeys: Set<String> {
        Set(stats.dailyCounts.lazy.filter { $0.count > 0 }.map(\.dateKey))
    }

    private var rhythmRangeLabel: String {
        switch selectedRange {
        case .thirtyDays: "Last 30 days"
        case .ninetyDays: "Last 90 days"
        case .allTime: "All time"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DhikrStatsRangeSelector(
                selectedRange: $selectedRange,
                language: language
            )

            DhikrStatsPatternSummary(stats: stats, language: language)
            DhikrStatsSummaryPanel(stats: stats, language: language)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: AwradLocalizer.localized("Daily rhythm", language: language))
                        .font(AwradTheme.bodyFont(.subheadline, weight: .bold))
                    Spacer(minLength: 8)
                    Text(verbatim: AwradLocalizer.localized(rhythmRangeLabel, language: language))
                        .font(AwradTheme.bodyFont(.caption2))
                        .foregroundStyle(.secondary)
                }
                DhikrStatsBarChart(dailyCounts: stats.dailyCounts)
            }
            .padding(16)
            .background(AwradTheme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            VStack(alignment: .leading, spacing: 12) {
                Text(verbatim: AwradLocalizer.localized("Consistency", language: language))
                    .font(AwradTheme.bodyFont(.subheadline, weight: .bold))
                DhikrStatsCalendar(
                    currentStreak: stats.currentStreak,
                    activeDateKeys: activeDateKeys,
                    todayKey: effectiveTodayKey,
                    earliestDateKey: stats.dailyCounts.first?.dateKey,
                    language: language
                )
            }
            .padding(16)
            .background(AwradTheme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .accessibilityIdentifier("dhikr_stats_overview")
    }
}

private struct DhikrStatsRangeSelector: View {
    @Binding var selectedRange: DhikrStatsRange
    let language: AppLanguage

    var body: some View {
        HStack(spacing: 6) {
            Text(verbatim: AwradLocalizer.localized("Practice window", language: language))
                .font(AwradTheme.bodyFont(.caption, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
            ForEach(DhikrStatsRange.allCases) { range in
                Button {
                    selectedRange = range
                } label: {
                    Text(verbatim: AwradLocalizer.localized(label(for: range), language: language))
                        .font(AwradTheme.bodyFont(.caption, weight: selectedRange == range ? .bold : .semibold))
                        .foregroundStyle(selectedRange == range ? Color.white : AwradTheme.ink)
                        .padding(.horizontal, 11)
                        .frame(minHeight: 34)
                        .background(
                            selectedRange == range ? AwradTheme.sage : AwradTheme.surface,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedRange == range ? .isSelected : [])
            }
        }
    }

    private func label(for range: DhikrStatsRange) -> String {
        switch range {
        case .thirtyDays: "30D"
        case .ninetyDays: "90D"
        case .allTime: "All"
        }
    }
}

private struct DhikrStatsPatternSummary: View {
    let stats: DhikrPracticeStats
    let language: AppLanguage

    private var title: String {
        AwradLocalizer.localized(
            stats.activeDays > 0 ? "Your rhythm with this dhikr" : "Your practice starts here",
            language: language
        )
    }

    private var description: String {
        guard stats.activeDays > 0 else {
            return AwradLocalizer.localized(
                "Counts for this dhikr will appear here after your first active day.",
                language: language
            )
        }
        let key = stats.activeDays == 1
            ? "You practiced this dhikr on %d day in the selected period."
            : "You practiced this dhikr on %d days in the selected period."
        return AwradLocalizer.format(key, language: language, stats.activeDays)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Circle()
                    .fill(AwradTheme.sage)
                    .frame(width: 8, height: 8)
                Text(verbatim: AwradLocalizer.localized("PRACTICE PATTERN", language: language))
                    .font(AwradTheme.bodyFont(.caption2, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(AwradTheme.sage)
            }
            Text(verbatim: title)
                .font(AwradTheme.displayFont(.title3, weight: .semibold))
                .foregroundStyle(AwradTheme.ink)
            Text(verbatim: description)
                .font(AwradTheme.bodyFont(.caption))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(AwradTheme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct DhikrStatsSummaryPanel: View {
    let stats: DhikrPracticeStats
    let language: AppLanguage

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                DhikrMetricCell(
                    label: localized("Recorded total"),
                    value: formatted(stats.totalCount),
                    detail: localized("Across every goal"),
                    highlight: true
                )
                Divider().frame(height: 82)
                DhikrMetricCell(
                    label: localized("Average on active days"),
                    value: formatted(stats.activeDayAverage),
                    detail: localized("On days you practiced")
                )
            }
            Divider().padding(.horizontal, 14)
            HStack(spacing: 0) {
                DhikrMetricCell(
                    label: localized("Days counted"),
                    value: formatted(Int64(stats.activeDays)),
                    detail: AwradLocalizer.format(
                        "%d%% of this window",
                        language: language,
                        stats.presencePercent
                    )
                )
                Divider().frame(height: 82)
                DhikrMetricCell(
                    label: localized("Current streak"),
                    value: AwradLocalizer.format(
                        stats.currentStreak == 1 ? "%d day" : "%d days",
                        language: language,
                        stats.currentStreak
                    ),
                    detail: localized("Follows your practice day")
                )
            }
        }
        .background(AwradTheme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func localized(_ key: String) -> String {
        AwradLocalizer.localized(key, language: language)
    }

    private func formatted(_ value: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: language.localeIdentifier)
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}

private struct DhikrMetricCell: View {
    let label: String
    let value: String
    let detail: String
    var highlight = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: label)
                .font(AwradTheme.bodyFont(.caption2, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Text(verbatim: value)
                .font(AwradTheme.displayFont(.title3, weight: .bold))
                .foregroundStyle(highlight ? AwradTheme.sage : AwradTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(verbatim: detail)
                .font(AwradTheme.bodyFont(10))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}

private struct DhikrStatsBarChart: View {
    let dailyCounts: [DhikrDailyCount]

    var body: some View {
        Canvas { context, size in
            guard !dailyCounts.isEmpty else { return }
            let maxCount = max(dailyCounts.map(\.count).max() ?? 0, 1)
            let spacing: CGFloat = dailyCounts.count > 60 ? 0.5 : 2
            let availableWidth = size.width - (spacing * CGFloat(max(dailyCounts.count - 1, 0)))
            let barWidth = max(availableWidth / CGFloat(dailyCounts.count), 0.25)

            for (index, day) in dailyCounts.enumerated() {
                let fraction = day.count <= 0
                    ? 0.025
                    : max(CGFloat(day.count) / CGFloat(maxCount), 0.08)
                let height = max(size.height * fraction, 2)
                let rect = CGRect(
                    x: CGFloat(index) * (barWidth + spacing),
                    y: size.height - height,
                    width: barWidth,
                    height: height
                )
                let color = index >= dailyCounts.count - 7
                    ? AwradTheme.sage
                    : AwradTheme.sage.opacity(0.38)
                context.fill(
                    Path(roundedRect: rect, cornerRadius: min(3, barWidth / 2)),
                    with: .color(color)
                )
            }
        }
        .frame(height: 88)
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Daily rhythm")
    }
}

private struct DhikrStatsCalendar: View {
    let currentStreak: Int
    let activeDateKeys: Set<String>
    let todayKey: String
    let earliestDateKey: String?
    let language: AppLanguage
    @State private var displayedMonth: Date

    init(
        currentStreak: Int,
        activeDateKeys: Set<String>,
        todayKey: String,
        earliestDateKey: String?,
        language: AppLanguage
    ) {
        self.currentStreak = currentStreak
        self.activeDateKeys = activeDateKeys
        self.todayKey = todayKey
        self.earliestDateKey = earliestDateKey
        self.language = language
        let today = DhikrStatsCalculator.date(for: todayKey) ?? Date()
        _displayedMonth = State(initialValue: Self.monthStart(for: today))
    }

    private var calendar: Calendar { Self.calendar }
    private var today: Date { DhikrStatsCalculator.date(for: todayKey) ?? Date() }
    private var currentMonth: Date { Self.monthStart(for: today) }
    private var earliestMonth: Date? {
        guard let earliestDateKey,
              let earliestDate = DhikrStatsCalculator.date(for: earliestDateKey) else {
            return nil
        }
        return Self.monthStart(for: earliestDate)
    }
    private var canGoBack: Bool { earliestMonth.map { displayedMonth > $0 } ?? true }
    private var canGoForward: Bool { displayedMonth < currentMonth }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if currentStreak > 0 {
                HStack(spacing: 10) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(AwradTheme.gold, in: Circle())
                    Text(
                        verbatim: AwradLocalizer.format(
                            currentStreak == 1 ? "%d day streak" : "%d day streak",
                            language: language,
                            currentStreak
                        )
                    )
                    .font(AwradTheme.bodyFont(.subheadline, weight: .bold))
                }
            }

            VStack(spacing: 4) {
                HStack {
                    monthButton(symbol: "chevron.backward", enabled: canGoBack) {
                        displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth)
                            ?? displayedMonth
                    }
                    Spacer()
                    Text(verbatim: monthTitle)
                        .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                    Spacer()
                    monthButton(symbol: "chevron.forward", enabled: canGoForward) {
                        displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth)
                            ?? displayedMonth
                    }
                }

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7),
                    spacing: 4
                ) {
                    ForEach(Array(dayLabels.enumerated()), id: \.offset) { _, label in
                        Text(verbatim: label)
                            .font(AwradTheme.bodyFont(9, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }

                    ForEach(Array(monthCells.enumerated()), id: \.offset) { _, date in
                        calendarCell(for: date)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(AwradTheme.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .onChange(of: todayKey) { _, newValue in
            guard let date = DhikrStatsCalculator.date(for: newValue) else { return }
            displayedMonth = Self.monthStart(for: date)
        }
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: language.localeIdentifier)
        formatter.setLocalizedDateFormatFromTemplate(
            calendar.component(.year, from: displayedMonth) == calendar.component(.year, from: today)
                ? "MMMM"
                : "MMMM yyyy"
        )
        return formatter.string(from: displayedMonth)
    }

    private var dayLabels: [String] {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: language.localeIdentifier)
        let sundayFirst = formatter.veryShortStandaloneWeekdaySymbols ?? formatter.veryShortWeekdaySymbols ?? []
        guard sundayFirst.count == 7 else { return ["M", "T", "W", "T", "F", "S", "S"] }
        return Array(sundayFirst[1...6]) + [sundayFirst[0]]
    }

    private var monthCells: [Date?] {
        guard let dayRange = calendar.range(of: .day, in: .month, for: displayedMonth),
              let firstWeekday = calendar.dateComponents([.weekday], from: displayedMonth).weekday else {
            return Array(repeating: nil, count: 42)
        }
        let mondayOffset = (firstWeekday + 5) % 7
        return (0..<42).map { index in
            let day = index - mondayOffset + 1
            guard dayRange.contains(day) else { return nil }
            return calendar.date(byAdding: .day, value: day - 1, to: displayedMonth)
        }
    }

    @ViewBuilder
    private func calendarCell(for date: Date?) -> some View {
        if let date {
            let key = DhikrStatsCalculator.dateKey(for: date)
            let isActive = activeDateKeys.contains(key)
            let isFuture = date > today
            let isToday = key == todayKey
            let fill = isFuture
                ? AwradTheme.trackFill.opacity(0.35)
                : isActive ? AwradTheme.gold : AwradTheme.trackFill
            let textColor: Color = isFuture
                ? .secondary.opacity(0.35)
                : isActive ? .white : .secondary

            Text(verbatim: String(calendar.component(.day, from: date)))
                .font(AwradTheme.bodyFont(9, weight: .medium))
                .foregroundStyle(textColor)
                .frame(width: 26, height: 26)
                .background(fill, in: Circle())
                .overlay {
                    if isToday {
                        Circle().stroke(AwradTheme.gold.opacity(0.8), lineWidth: 1)
                    }
                }
                .frame(maxWidth: .infinity)
                .accessibilityLabel(key)
                .accessibilityValue(
                    Text(
                        verbatim: AwradLocalizer.localized(
                            isActive ? "Practiced" : "No practice",
                            language: language
                        )
                    )
                )
        } else {
            Circle()
                .fill(AwradTheme.trackFill.opacity(0.18))
                .frame(width: 26, height: 26)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
        }
    }

    private func monthButton(
        symbol: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(AwradTheme.bodyFont(12, weight: .bold))
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
    }

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private static func monthStart(for date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
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
