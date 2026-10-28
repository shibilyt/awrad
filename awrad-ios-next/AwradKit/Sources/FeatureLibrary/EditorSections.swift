import AwradDesignSystem
import AwradDomain
import SwiftUI

typealias EditorSend = (CustomDhikrEditorModel.Action) -> Void

extension View {
    /// The page margin on both sides.
    func pageInset() -> some View {
        padding(.horizontal, AwradSpacing.pageMargin)
    }
}

extension Strings {
    /// What a field's problem says.
    static func message(for problem: FieldProblem, field: EditorField) -> LocalizedStringResource {
        switch problem {
        case .tooLong(let limit): tooLong(limit)
        case .tooMany(let limit): tooManyReferences(limit)
        case .titleRequired: titleRequired
        case .blank: field == .arabic ? arabicBlank : message(.invalidDhikr)
        case .invalid:
            if case .reference = field { referenceInvalid } else { message(.invalidDhikr) }
        }
    }
}

/// The Arabic text, kind and the per-language title, transliteration and translation.
struct EditorTextSections: View {
    let state: CustomDhikrEditorModel.State
    let send: EditorSend

    var body: some View {
        VStack(alignment: .leading, spacing: AwradSpacing.sectionGap) {
            LabeledField(
                label: Strings.arabicField, text: state.form.arabic, onChange: { send(.arabicChanged($0)) },
                error: error(.arabic), kind: .multiline, isArabic: true
            )
            .pageInset()
            kindSection
            languageSection
        }
    }

    private var kindSection: some View {
        VStack(alignment: .leading, spacing: AwradSpacing.md) {
            AwradSectionTitle(Strings.kindField)
            VStack(spacing: AwradSpacing.rowGap) {
                ForEach(DhikrKind.allCases, id: \.self) { kind in
                    AwradOptionRow(Strings.kindName(kind), isSelected: state.form.kind == kind) {
                        send(.kindSelected(kind))
                    }
                }
            }
            .pageInset()
        }
    }

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: AwradSpacing.md) {
            ScrollView(.horizontal, showsIndicators: false) {
                AwradSegmentedPills(
                    selection: Binding(get: { state.language }, set: { send(.languageSelected($0)) }),
                    options: CatalogLanguage.allCases.map { .init($0, title: Strings.languageName($0)) }
                )
                .pageInset()
            }
            VStack(spacing: AwradSpacing.lg) {
                textField(.title, label: Strings.titleField)
                if CustomDhikrForm.TextRole.transliteration.isOffered(in: state.language) {
                    textField(.transliteration, label: Strings.transliteration)
                }
                textField(.translation, label: Strings.translation)
            }
            .pageInset()
        }
    }

    private func textField(_ role: CustomDhikrForm.TextRole, label: LocalizedStringResource) -> some View {
        let language = state.language
        let field: EditorField
        switch role {
        case .title: field = .titleText(language)
        case .transliteration: field = .transliteration(language)
        case .translation: field = .translation(language)
        }
        return LabeledField(
            label: label, text: state.form[role][language], onChange: { send(.textChanged(role, language, $0)) },
            error: error(field) ?? (role == .title ? error(.title) : nil), kind: .multiline,
            isArabic: language == .ar && role != .transliteration
        )
        // A new language starts empty and unfocused, not with the last one's cursor.
        .id("\(role)-\(language.rawValue)")
    }

    private func error(_ field: EditorField) -> LocalizedStringResource? {
        state.errors[field].map { Strings.message(for: $0, field: field) }
    }
}

/// The references with their labels and a remove button each, then "Add reference".
struct EditorReferencesSection: View {
    let state: CustomDhikrEditorModel.State
    let send: EditorSend
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: AwradSpacing.md) {
            AwradSectionTitle(Strings.references)
            VStack(alignment: .leading, spacing: AwradSpacing.rowGap) {
                ForEach(Array(state.form.references.enumerated()), id: \.element.id) { index, reference in
                    row(reference, at: index)
                }
                if let problem = state.errors[.references] {
                    Text(Strings.message(for: problem, field: .references))
                        .awradTextStyle(.caption)
                        .foregroundStyle(AwradColors.error)
                }
                AwradButton(Strings.addReference, variant: .secondary, icon: .add) { send(.addReferenceTapped) }
                    .disabled(!state.canAddReference)
            }
            .pageInset()
        }
    }

    private func row(_ reference: Reference, at index: Int) -> some View {
        AwradCard(AwradRadius.tile) {
            HStack(spacing: AwradSpacing.md) {
                Text(verbatim: ReferenceLabel.text(reference, locale: locale))
                    .awradTextStyle(.body)
                    .foregroundStyle(AwradColors.onSurface)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    send(.referenceRemoved(index))
                } label: {
                    AwradIconImage(.close, size: AwradSize.iconSmall)
                        .foregroundStyle(AwradColors.onSurfaceVariant)
                        .frame(width: AwradSize.touchTarget, height: AwradSize.touchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.awradPress(.button))
                .accessibilityLabel(Text(Strings.removeReference))
                .accessibilityValue(Text(verbatim: ReferenceLabel.text(reference, locale: locale)))
            }
            if let problem = state.errors[.reference(index)] {
                Text(Strings.message(for: problem, field: .reference(index)))
                    .awradTextStyle(.caption)
                    .foregroundStyle(AwradColors.error)
            }
        }
    }
}

/// The chosen tags as chips and "Choose tags".
struct EditorTagsSection: View {
    let state: CustomDhikrEditorModel.State
    let send: EditorSend

    var body: some View {
        VStack(alignment: .leading, spacing: AwradSpacing.md) {
            AwradSectionTitle(Strings.tags)
            VStack(alignment: .leading, spacing: AwradSpacing.md) {
                if !state.chosenTags.isEmpty {
                    TagChips(items: state.chosenTags.map { TagChipItem(id: $0.id.description, title: $0.name) })
                }
                AwradButton(Strings.chooseTags, variant: .secondary) { send(.chooseTagsChanged(true)) }
            }
            .pageInset()
        }
    }
}

/// The local recording: the player bar with Replace and Remove, or "Add recording".
struct EditorRecordingSection: View {
    let state: CustomDhikrEditorModel.State
    let send: EditorSend

    var body: some View {
        VStack(alignment: .leading, spacing: AwradSpacing.md) {
            AwradSectionTitle(Strings.recording)
            AwradCard {
                if state.recording != .none {
                    DhikrAudioBar(audio: state.audio) { send(.playPauseTapped) }
                    HStack(spacing: AwradSpacing.sm) {
                        AwradButton(Strings.replaceRecording, variant: .secondary, layout: .row) {
                            send(.addRecordingTapped)
                        }
                        AwradButton(Strings.removeRecording, variant: .text, layout: .row, role: .destructive) {
                            send(.recordingRemoved)
                        }
                    }
                } else {
                    AwradButton(Strings.addRecording, variant: .secondary, icon: .add) { send(.addRecordingTapped) }
                }
                Text(Strings.audioHint)
                    .awradTextStyle(.caption)
                    .foregroundStyle(AwradColors.onSurfaceVariant)
                if let failure = state.audioFailure { FailureText(failure: failure) }
            }
            .pageInset()
        }
    }
}
