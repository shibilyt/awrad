import AwradData
import AwradDesignSystem
import AwradDomain
import FeatureLibrary
import SwiftUI

/// The app after onboarding: Home and Library under the floating bottom bar. The shell owns the
/// Library's model, so Home's collection tiles open a collection in the Library tab.
struct AppShell: View {
    enum Tab: Hashable {
        case home, library
    }

    private static let items = [
        AwradBottomBarItem(Tab.home, title: "tab.home", icon: .home),
        AwradBottomBarItem(Tab.library, title: "tab.library", icon: .library),
    ]

    let composition: AppComposition
    let onShowAccount: () -> Void
    let onRestartOnboarding: () -> Void
    @State private var tab: Tab
    @State private var library: LibraryModel

    init(composition: AppComposition, onShowAccount: @escaping () -> Void, onRestartOnboarding: @escaping () -> Void) {
        self.composition = composition
        self.onShowAccount = onShowAccount
        self.onRestartOnboarding = onRestartOnboarding
        let library = LibraryModel(
            catalog: composition.catalog, language: composition.language, library: composition.profiles)
        var tab = Tab.home
        #if DEBUG
            LibraryLaunchState.apply(to: library, tab: &tab)
        #endif
        _library = State(initialValue: library)
        _tab = State(initialValue: tab)
    }

    var body: some View {
        Group {
            switch tab {
            case .home:
                HomeView(
                    content: library.content,
                    onOpenCollection: { collection in
                        library.apply(.openCollection(key: collection.key))
                        tab = .library
                    },
                    onViewAll: {
                        library.apply(.showRoot)
                        tab = .library
                    },
                    onShowAccount: onShowAccount,
                    onRestartOnboarding: onRestartOnboarding)
            case .library:
                LibraryRoute(model: library, makePlayer: composition.makeAudioPlayer)
            }
        }
        .awradTabSwitch(value: tab)
        // Only on the tab roots: a pushed collection or dhikr page hides it.
        .awradBottomBar(
            selection: $tab, items: Self.items, isPresented: tab == .home || library.state.path.isEmpty
        )
        .background(AwradColors.background)
    }
}

/// Home: the placeholder content from earlier slices, then the featured dhikr collections.
struct HomeView: View {
    let content: LibraryContent
    let onOpenCollection: (DhikrCollection) -> Void
    let onViewAll: () -> Void
    let onShowAccount: () -> Void
    let onRestartOnboarding: () -> Void
    #if DEBUG
        @State private var showsGallery = false
    #endif

    var body: some View {
        ScrollView {
            VStack(spacing: AwradSpacing.xl3) {
                placeholder
                FeaturedCollections(content: content, onOpen: onOpenCollection, onViewAll: onViewAll)
            }
            .padding(.vertical, AwradSpacing.xl3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AwradColors.background)
    }

    private var placeholder: some View {
        VStack(spacing: AwradSpacing.rowGap) {
            Text("home.placeholder.title")
                .awradTextStyle(.title)
                .foregroundStyle(AwradColors.onSurface)
            Text("home.placeholder.body")
                .awradTextStyle(.body)
                .foregroundStyle(AwradColors.onSurfaceVariant)
                .multilineTextAlignment(.center)
            AwradButton("home.placeholder.account", action: onShowAccount)
                .padding(.top, AwradSpacing.xl2)
            AwradButton("home.placeholder.restart", variant: .text, action: onRestartOnboarding)
                .padding(.top, AwradSpacing.md)
            #if DEBUG
                AwradButton("home.placeholder.gallery", variant: .text) { showsGallery = true }
                    .fullScreenCover(isPresented: $showsGallery) { AwradComponentGallery() }
            #endif
        }
        .padding(.horizontal, AwradSpacing.pageMargin)
    }
}

#if DEBUG
    /// Launch arguments that open the Library in a given state, for simulator screenshots (debug
    /// builds only): `-AwradTab library`, `-AwradLibrarySearch <query>`,
    /// `-AwradLibraryCollection <key>`, `-AwradLibraryDhikr <key>` (pushed on the collection, if any;
    /// a custom dhikr's key is its ID), `-AwradLibraryYourDhikrs YES`, `-AwradLibraryEditor new|<id>`,
    /// `-AwradLibraryManageTags all|<dhikr id>` and `-AwradLibraryFilter <tag id>`.
    enum LibraryLaunchState {
        static func apply(to library: LibraryModel, tab: inout AppShell.Tab, defaults: UserDefaults = .standard) {
            if defaults.string(forKey: "AwradTab") == "library" { tab = .library }
            if let query = defaults.string(forKey: "AwradLibrarySearch") {
                tab = .library
                library.apply(.queryChanged(query))
            }
            if let key = defaults.string(forKey: "AwradLibraryCollection") {
                tab = .library
                library.apply(.openCollection(key: key))
            }
            if defaults.bool(forKey: "AwradLibraryYourDhikrs") {
                tab = .library
                library.apply(.openYourDhikrs)
            }
            if let key = defaults.string(forKey: "AwradLibraryDhikr") {
                tab = .library
                library.apply(.openDhikr(key: key))
            }
            applyPersonal(to: library, tab: &tab, defaults: defaults)
        }

        private static func applyPersonal(to library: LibraryModel, tab: inout AppShell.Tab, defaults: UserDefaults) {
            if let tag = defaults.string(forKey: "AwradLibraryFilter").flatMap(AwradID.init) {
                tab = .library
                library.apply(.toggleTagFilter(tag))
            }
            if let editor = defaults.string(forKey: "AwradLibraryEditor") {
                tab = .library
                library.apply(.openEditor(AwradID(editor)))
            }
            if let dhikr = defaults.string(forKey: "AwradLibraryManageTags") {
                tab = .library
                library.apply(.openManageTags(dhikr: AwradID(dhikr)))
            }
        }
    }

    /// `-AwradSampleData YES` fills an empty active profile with sample custom dhikrs, tags and a
    /// conflict before the app starts (debug builds only, for screenshots).
    enum SampleLaunchState {
        static func seedIfAsked(_ profiles: LocalProfileStore, defaults: UserDefaults = .standard) async {
            guard defaults.bool(forKey: "AwradSampleData") else { return }
            await profiles.seedSample()
        }
    }
#endif
