import AwradDesignSystem
import AwradDomain
import SwiftUI

/// A dhikr's screen: owns its model (and so its audio), which stops when the screen goes away.
struct DhikrDetailRoute: View {
    @State private var model: DhikrDetailModel
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
    }
}

/// Stateless: the text by kind (slice 3a brief, "Rendering by kind"), the audio button, the tags
/// and the virtues with their references.
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
                        DhikrAudioControl(audio: state.audio) { send(.playPauseTapped) }
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

    /// The Arabic, centred and right to left: one ayah per line with its reference for Qur'an.
    @ViewBuilder private var recitedText: some View {
        VStack(spacing: AwradSpacing.sm) {
            switch dhikr.kind {
            case .quran:
                ForEach(Array(dhikr.arabicLines.enumerated()), id: \.offset) { _, line in
                    ArabicText(line)
                }
                ForEach(dhikr.references.filter(\.isQuran), id: \.id) { reference in
                    Text(verbatim: ReferenceLabel.text(reference, locale: locale))
                        .awradTextStyle(.label)
                        .foregroundStyle(AwradColors.accent)
                }
            case .nameOfAllah, .dhikr, .dua, .salawat:
                ArabicText(dhikr.arabic)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// What follows the text: the meaning of a name, or a dhikr's transliteration and translation.
    @ViewBuilder private var details: some View {
        switch dhikr.kind {
        case .quran:
            EmptyView()
        case .nameOfAllah:
            DetailSection(title: Strings.meaning, text: display.translation)
        case .dhikr, .dua, .salawat:
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

/// Recited Arabic in the `quran` style, centred, right to left whatever the app language.
private struct ArabicText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(verbatim: text)
            .awradTextStyle(.quran)
            .foregroundStyle(AwradColors.onSurface)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .environment(\.layoutDirection, .rightToLeft)
            .environment(\.locale, Locale(identifier: "ar"))
    }
}

/// A titled paragraph: transliteration, translation or a name's meaning.
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

/// The play/pause round button with the elapsed time, or why it can't play.
private struct DhikrAudioControl: View {
    let audio: DhikrDetailModel.Audio
    let action: () -> Void

    var body: some View {
        HStack(spacing: AwradSpacing.md) {
            AwradRoundButton(
                icon: audio.isActive ? .pause : .play, label: audio.isActive ? Strings.pause : Strings.play,
                action: action)
            if let elapsed = audio.elapsed {
                Text(elapsed, format: .time(pattern: .minuteSecond))
                    .awradTextStyle(.label)
                    .monospacedDigit()
                    .foregroundStyle(AwradColors.onSurfaceVariant)
            } else if audio == .loading {
                ProgressView()
                    .tint(AwradColors.progress)
            } else if audio == .failed {
                Text(Strings.audioFailed)
                    .awradTextStyle(.caption)
                    .foregroundStyle(AwradColors.error)
            }
        }
        .frame(maxWidth: .infinity)
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
