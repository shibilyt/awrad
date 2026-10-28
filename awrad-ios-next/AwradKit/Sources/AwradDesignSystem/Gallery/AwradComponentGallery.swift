#if DEBUG
    import SwiftUI

    /// The component gallery (contracts/design-system/v1/components.md): every component in every
    /// state, with light/dark and left-to-right/Arabic right-to-left switches on the gallery itself.
    /// Debug builds only; the app opens it from a debug-only entry point.
    ///
    /// Launch arguments set its starting state, for screenshots: `-AwradGalleryDark YES`,
    /// `-AwradGalleryRTL YES`, `-AwradGallerySection <containers|buttons|inputs|library|navigation>`,
    /// `-AwradGalleryTab <home|goals|library|community>`, `-AwradGallerySheet YES`.
    public struct AwradComponentGallery: View {
        @State private var isDark: Bool
        @State private var isRightToLeft: Bool
        @State private var tab: GalleryTab
        @State private var showsSheet: Bool
        @State private var showsDialog = false
        private let startSection: GallerySection?

        public init(defaults: UserDefaults = .standard) {
            _isDark = State(initialValue: defaults.bool(forKey: "AwradGalleryDark"))
            _isRightToLeft = State(initialValue: defaults.bool(forKey: "AwradGalleryRTL"))
            _tab = State(initialValue: defaults.string(forKey: "AwradGalleryTab").flatMap(GalleryTab.init) ?? .home)
            _showsSheet = State(initialValue: defaults.bool(forKey: "AwradGallerySheet"))
            startSection = defaults.string(forKey: "AwradGallerySection").flatMap(GallerySection.init)
        }

        public var body: some View {
            NavigationStack {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: AwradSpacing.xl4) {
                            VStack(spacing: AwradSpacing.none) {
                                AwradSwitch(GalleryStrings.dark, isOn: $isDark)
                                AwradSwitch(GalleryStrings.rightToLeft, isOn: $isRightToLeft)
                            }
                            .padding(.horizontal, AwradSpacing.pageMargin)
                            GalleryContainers(showsSheet: $showsSheet, showsDialog: $showsDialog)
                                .id(GallerySection.containers)
                            GalleryButtons().id(GallerySection.buttons)
                            GalleryInputs().id(GallerySection.inputs)
                            GalleryLibrary().id(GallerySection.library)
                            GalleryNavigation(tab: tab).id(GallerySection.navigation)
                        }
                        .padding(.vertical, AwradSpacing.lg)
                    }
                    .task {
                        guard let startSection else { return }
                        // After the first layout, so the section has a position to scroll to.
                        try? await Task.sleep(for: .milliseconds(300))
                        proxy.scrollTo(startSection, anchor: .top)
                    }
                }
                .background(AwradColors.background)
                .awradLargeTitle(GalleryStrings.title)
                .awradBottomBar(selection: $tab, items: GalleryTab.items)
            }
            .galleryDialog(isPresented: $showsDialog)
            .tint(AwradColors.accent)
            .environment(\.layoutDirection, isRightToLeft ? .rightToLeft : .leftToRight)
            .environment(\.locale, isRightToLeft ? Locale(identifier: "ar") : Locale(identifier: "en"))
            .preferredColorScheme(isDark ? .dark : .light)
        }
    }

    /// The action of a sample that does nothing when tapped.
    func galleryNoAction() {}

    enum GallerySection: String, Hashable {
        case containers, buttons, inputs, library, navigation
    }

    enum GalleryTab: String, Hashable, CaseIterable {
        case home, goals, library, community

        static let items: [AwradBottomBarItem<GalleryTab>] = [
            AwradBottomBarItem(.home, title: GalleryStrings.home, icon: .home),
            AwradBottomBarItem(.goals, title: GalleryStrings.goals, icon: .goals),
            AwradBottomBarItem(.library, title: GalleryStrings.library, icon: .library),
            AwradBottomBarItem(.community, title: GalleryStrings.community, icon: .community),
        ]

        var title: LocalizedStringResource {
            Self.items.first { $0.tab == self }?.title ?? GalleryStrings.home
        }
    }

    /// A gallery section: its name as a large header, then its components, `sectionGap` apart.
    struct GalleryGroup<Content: View>: View {
        let title: String
        @ViewBuilder let content: Content

        var body: some View {
            VStack(alignment: .leading, spacing: AwradSpacing.sectionGap) {
                Text(verbatim: title)
                    .awradTextStyle(.title)
                    .foregroundStyle(AwradColors.onSurface)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.horizontal, AwradSpacing.pageMargin)
                content
            }
        }
    }

    /// One component in the gallery: an English caption naming it and its states, then the samples.
    struct GalleryItem<Content: View>: View {
        let caption: String
        var isInset = true
        @ViewBuilder let content: Content

        var body: some View {
            VStack(alignment: .leading, spacing: AwradSpacing.sm) {
                Text(verbatim: caption)
                    .awradTextStyle(.caption)
                    .foregroundStyle(AwradColors.onSurfaceVariant)
                    .padding(.horizontal, AwradSpacing.pageMargin)
                VStack(alignment: .leading, spacing: AwradSpacing.rowGap) { content }
                    .padding(.horizontal, isInset ? AwradSpacing.pageMargin : AwradSpacing.none)
            }
        }
    }

    #Preview("Gallery") {
        AwradComponentGallery()
    }
#endif
