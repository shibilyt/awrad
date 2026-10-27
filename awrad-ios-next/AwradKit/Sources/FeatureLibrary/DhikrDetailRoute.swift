import AwradDesignSystem
import AwradDomain
import SwiftUI

/// A dhikr's screen: owns its model (and so its audio), which stops when the screen goes away and
/// pauses when the app goes to the background.
struct DhikrDetailRoute: View {
    @State private var model: DhikrDetailModel
    @Environment(\.scenePhase) private var scenePhase
    private let content: LibraryContent

    init(dhikr: Dhikr, content: LibraryContent, makePlayer: @escaping @MainActor () -> any DhikrAudioPlayer) {
        _model = State(initialValue: DhikrDetailModel(dhikr: dhikr, makePlayer: makePlayer))
        self.content = content
    }

    var body: some View {
        DhikrDetailScreen(state: model.state, content: content) { action in
            if !model.apply(action) { Task { await model.send(action) } }
        }
        .onDisappear { model.apply(.disappeared) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { model.apply(.backgrounded) }
        }
    }
}

/// Stateless: the Arabic card by kind with the audio player bar at its bottom, then the
/// transliteration, translation, tags and virtues (components.md, "Dhikr detail screen").
struct DhikrDetailScreen: View {
    let state: DhikrDetailModel.State
    let content: LibraryContent
    let send: (DhikrDetailModel.Action) -> Void
    /// Reference labels format their numbers for the screen's locale.
    @Environment(\.locale) private var locale

    private var dhikr: Dhikr { state.dhikr }
    private var display: DhikrDisplay { content.display(dhikr) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AwradSpacing.sectionGap) {
                AwradCard {
                    recitedText
                    if state.audio != .unavailable {
                        DhikrAudioBar(audio: state.audio) { send(.playPauseTapped) }
                    }
                }
                .padding(.horizontal, AwradSpacing.pageMargin)
                details
                tags
                virtues
            }
            .padding(.vertical, AwradSpacing.sm)
        }
        .background(AwradColors.background)
        .navigationTitle(Text(verbatim: display.title))
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    /// The Arabic, centred and right to left: one ayah per line with its reference for Qur'an, or a
    /// name of Allah over its meaning.
    @ViewBuilder private var recitedText: some View {
        VStack(spacing: AwradSpacing.sm) {
            switch dhikr.kind {
            case .quran:
                ForEach(Array(dhikr.arabicLines.enumerated()), id: \.offset) { _, line in
                    ArabicText(line)
                }
                ForEach(dhikr.references.filter(\.isQuran), id: \.id) { reference in
                    Text(verbatim: ReferenceLabel.text(reference, locale: locale))
                        .awradTextStyle(.caption)
                        .foregroundStyle(AwradColors.onSurfaceVariant)
                }
            case .nameOfAllah:
                ArabicText(dhikr.arabic, style: .nameOfAllah)
                Text(verbatim: display.translation)
                    .awradTextStyle(.title)
                    .foregroundStyle(AwradColors.onSurface)
                    .multilineTextAlignment(.center)
            case .dhikr, .dua, .salawat:
                ArabicText(dhikr.arabic)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// The transliteration and translation; a name of Allah has neither (its title is the
    /// transliteration and its meaning is in the card).
    @ViewBuilder private var details: some View {
        if dhikr.kind != .nameOfAllah {
            if let transliteration = display.transliteration {
                DetailSection(title: Strings.transliteration, text: transliteration)
            }
            DetailSection(title: Strings.translation, text: display.translation)
        }
    }

    @ViewBuilder private var tags: some View {
        let tags = dhikr.tags.compactMap(content.catalog.tag)
        if !tags.isEmpty {
            VStack(alignment: .leading, spacing: AwradSpacing.md) {
                AwradSectionTitle(Strings.tags)
                HStack(spacing: AwradSpacing.sm) {
                    ForEach(tags) { TagChip(title: $0.title.resolved(in: content.language)) }
                }
                .padding(.horizontal, AwradSpacing.pageMargin)
            }
        }
    }

    @ViewBuilder private var virtues: some View {
        if !dhikr.virtues.isEmpty {
            VStack(alignment: .leading, spacing: AwradSpacing.md) {
                AwradSectionTitle(Strings.virtues)
                ForEach(Array(dhikr.virtues.enumerated()), id: \.offset) { _, virtue in
                    VirtueCard(
                        text: virtue.text.resolved(in: content.language), references: dhikr.references(of: virtue),
                        locale: locale)
                }
                .padding(.horizontal, AwradSpacing.pageMargin)
            }
        }
    }
}

extension Reference {
    fileprivate var isQuran: Bool {
        if case .quran = self { true } else { false }
    }
}

/// Recited Arabic (`quran`, or `nameOfAllah` for a name), centred, right to left whatever the app
/// language.
private struct ArabicText: View {
    let text: String
    let style: AwradTextStyle

    init(_ text: String, style: AwradTextStyle = .quran) {
        self.text = text
        self.style = style
    }

    var body: some View {
        Text(verbatim: text)
            .awradTextStyle(style)
            .foregroundStyle(AwradColors.onSurface)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .environment(\.layoutDirection, .rightToLeft)
            .environment(\.locale, Locale(identifier: "ar"))
    }
}

/// A titled paragraph: the transliteration or the translation.
private struct DetailSection: View {
    let title: LocalizedStringResource
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: AwradSpacing.sm) {
            AwradSectionTitle(title)
            Text(verbatim: text)
                .awradTextStyle(.body)
                .foregroundStyle(AwradColors.onSurface)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AwradSpacing.pageMargin)
                .textSelection(.enabled)
        }
    }
}

/// A catalog tag: `label` text in a `chip`, filled like a secondary control.
private struct TagChip: View {
    let title: String
    @Environment(\.awradContainer) private var container

    var body: some View {
        Text(verbatim: title)
            .awradTextStyle(.label)
            .foregroundStyle(container.onSecondaryFill)
            .padding(.horizontal, AwradSpacing.md)
            .padding(.vertical, AwradSpacing.xs)
            .background(container.secondaryFill, in: AwradRadius.chip.shape)
    }
}

/// A virtue in a `tile` card: its text, then each reference's label (and link).
private struct VirtueCard: View {
    let text: String
    let references: [Reference]
    let locale: Locale

    var body: some View {
        AwradCard(AwradRadius.tile) {
            Text(verbatim: text)
                .awradTextStyle(.body)
                .foregroundStyle(AwradColors.onSurface)
            ForEach(references, id: \.id) { reference in
                VStack(alignment: .leading, spacing: AwradSpacing.xxs) {
                    Text(verbatim: ReferenceLabel.text(reference, locale: locale))
                        .awradTextStyle(.caption)
                        .foregroundStyle(AwradColors.onSurfaceVariant)
                    if let url = ReferenceLabel.link(reference) {
                        Link(destination: url) {
                            Text(verbatim: url.absoluteString)
                                .awradTextStyle(.caption)
                                .foregroundStyle(AwradColors.accent)
                        }
                    }
                }
            }
        }
    }
}

#Preview("Surah Ikhlas") {
    detailPreview("surah-ikhlas")
}

#Preview("Isthighfar, Malayalam") {
    detailPreview("isthighfar", language: .ml)
}

#Preview("Name, Arabic, dark") {
    detailPreview("asma-ul-husna-ar-rahman", language: .ar)
        .environment(\.layoutDirection, .rightToLeft)
        .preferredColorScheme(.dark)
}

@MainActor
private func detailPreview(_ key: String, language: CatalogLanguage = .en) -> some View {
    let catalog = (try? DhikrCatalog.bundled()) ?? .empty
    let content = LibraryContent(catalog: catalog, language: language)
    return NavigationStack {
        if let dhikr = catalog.dhikr(key) {
            DhikrDetailRoute(dhikr: dhikr, content: content) { PreviewAudioPlayer() }
        }
    }
}
