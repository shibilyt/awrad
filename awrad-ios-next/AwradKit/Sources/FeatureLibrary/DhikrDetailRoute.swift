import AwradDesignSystem
import AwradDomain
import SwiftUI

/// A dhikr's screen: owns its model (and so its audio), which stops when the screen goes away and
/// pauses when the app goes to the background. `navigate` takes the Library action for Edit, Manage
/// tags and leaving after a delete.
struct DhikrDetailRoute: View {
    @State private var model: DhikrDetailModel
    @Environment(\.scenePhase) private var scenePhase
    private let content: LibraryContent
    private let navigate: (LibraryModel.Action) -> Void

    init(
        dhikr: Dhikr, content: LibraryContent, personal: PersonalContent, services: LibraryServices,
        navigate: @escaping (LibraryModel.Action) -> Void
    ) {
        _model = State(
            initialValue: DhikrDetailModel(
                dhikr: dhikr, library: services.library, personal: personal, makePlayer: services.makePlayer))
        self.content = content
        self.navigate = navigate
    }

    var body: some View {
        DhikrDetailScreen(
            state: model.state, content: content,
            send: { action in if !model.apply(action) { Task { await model.send(action) } } },
            onEdit: { navigate(.openEditor(model.state.dhikr.id)) },
            onManageTags: { navigate(.openManageTags(dhikr: model.state.dhikr.id)) }
        )
        .task { await model.observe() }
        .onDisappear { model.apply(.disappeared) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { model.apply(.backgrounded) }
        }
        .onChange(of: model.state.isRemoved) { _, isRemoved in
            if isRemoved { navigate(.popToRoot) }
        }
    }
}

/// Stateless: the conflict card, the Arabic card by kind with the audio player bar at its bottom, then
/// the transliteration, translation, tags and virtues (components.md, "Dhikr detail screen"). A custom
/// dhikr also has Edit and Delete.
struct DhikrDetailScreen: View {
    let state: DhikrDetailModel.State
    let content: LibraryContent
    let send: (DhikrDetailModel.Action) -> Void
    let onEdit: () -> Void
    let onManageTags: () -> Void
    /// Reference labels format their numbers for the screen's locale.
    @Environment(\.locale) private var locale

    private var dhikr: Dhikr { state.dhikr }
    private var display: DhikrDisplay { content.display(dhikr) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AwradSpacing.sectionGap) {
                if !state.conflicts.isEmpty {
                    ConflictCard(
                        name: nil, onKeepMine: { send(.resolveConflicts(.keepMine)) },
                        onUseTheirs: { send(.resolveConflicts(.useTheirs)) }
                    )
                    .pageInset()
                }
                AwradCard {
                    recitedText
                    if state.audio != .unavailable {
                        DhikrAudioBar(audio: state.audio) { send(.playPauseTapped) }
                    }
                }
                .pageInset()
                details
                tags
                virtues
                if state.custom != nil { deleteSection }
            }
            .padding(.vertical, AwradSpacing.sm)
        }
        .background(AwradColors.background)
        .navigationTitle(Text(verbatim: display.title))
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if state.custom != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: onEdit) { Text(Strings.edit) }
                        .tint(AwradColors.accent)
                }
            }
        }
        .awradDialog(
            isPresented: Binding(get: { state.isConfirmingDelete }, set: { if !$0 { send(.deleteDismissed) } }),
            title: Strings.deleteDhikrTitle, message: Strings.deleteDhikrMessage
        ) {
            AwradButton(Strings.cancel, variant: .text, layout: .row) { send(.deleteDismissed) }
            AwradButton(Strings.delete, variant: .error, layout: .row, role: .destructive) {
                send(.deleteConfirmed)
            }
        }
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
                if !display.translation.isEmpty {
                    Text(verbatim: display.translation)
                        .awradTextStyle(.title)
                        .foregroundStyle(AwradColors.onSurface)
                        .multilineTextAlignment(.center)
                }
            case .dhikr, .dua, .salawat:
                ArabicText(dhikr.arabic)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// The transliteration and translation, each left out when empty; a name of Allah has neither (its
    /// title is the transliteration and its meaning is in the card).
    @ViewBuilder private var details: some View {
        if dhikr.kind != .nameOfAllah {
            if let transliteration = display.transliteration, !transliteration.isEmpty {
                DetailSection(title: Strings.transliteration, text: transliteration)
            }
            if !display.translation.isEmpty {
                DetailSection(title: Strings.translation, text: display.translation)
            }
        }
    }

    /// The catalog's tags and the user's, as chips, and "Manage tags".
    private var tags: some View {
        let catalogTags = dhikr.tags.compactMap(content.catalog.tag).map {
            TagChipItem(id: $0.key, title: $0.title.resolved(in: content.language))
        }
        let userTags = state.userTags.map { TagChipItem(id: $0.id.description, title: $0.name) }
        return VStack(alignment: .leading, spacing: AwradSpacing.md) {
            AwradSectionTitle(Strings.tags)
            VStack(alignment: .leading, spacing: AwradSpacing.sm) {
                if !catalogTags.isEmpty || !userTags.isEmpty { TagChips(items: catalogTags + userTags) }
                AwradButton(Strings.manageTags, variant: .text, layout: .row, action: onManageTags)
            }
            .pageInset()
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
                .pageInset()
            }
        }
    }

    private var deleteSection: some View {
        VStack(spacing: AwradSpacing.rowGap) {
            if let failure = state.failure { FailureText(failure: failure) }
            AwradButton(Strings.deleteDhikr, variant: .error) { send(.deleteTapped) }
        }
        .pageInset()
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

#if DEBUG
    #Preview("Surah Ikhlas") {
        detailPreview("surah-ikhlas")
    }

    #Preview("Isthighfar, Malayalam") {
        detailPreview("isthighfar", language: .ml)
    }

    #Preview("Custom dhikr, conflict") {
        detailPreview(PreviewContent.custom.id.description, personal: PreviewContent.conflicted)
    }

    #Preview("Name, Arabic, dark") {
        detailPreview("asma-ul-husna-ar-rahman", language: .ar)
            .environment(\.layoutDirection, .rightToLeft)
            .preferredColorScheme(.dark)
    }

    @MainActor
    private func detailPreview(
        _ key: String, language: CatalogLanguage = .en, personal: PersonalContent = .empty
    ) -> some View {
        let catalog = (try? DhikrCatalog.bundled()) ?? .empty
        let content = LibraryContent(catalog: catalog, language: language)
        let services = LibraryServices(library: PreviewPersonalLibrary(personal)) { PreviewAudioPlayer() }
        return NavigationStack {
            if let dhikr = content.dhikr(key, in: personal) {
                DhikrDetailRoute(dhikr: dhikr, content: content, personal: personal, services: services) { _ in }
            }
        }
    }
#endif
