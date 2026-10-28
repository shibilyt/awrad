import AwradDesignSystem
import AwradDomain
import SwiftUI

/// "Add reference": the type, then that type's fields. Problems show once adding has been tried.
struct ReferenceSheet: View {
    let draft: ReferenceDraft
    let send: EditorSend

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AwradSpacing.lg) {
                Text(Strings.addReference)
                    .awradTextStyle(.title)
                    .foregroundStyle(AwradColors.onSurface)
                    .accessibilityAddTraits(.isHeader)
                VStack(alignment: .leading, spacing: AwradSpacing.sm) {
                    Text(Strings.referenceTypeField)
                        .awradTextStyle(.label)
                        .foregroundStyle(AwradColors.onSurface)
                    ForEach(ReferenceDraft.Kind.allCases, id: \.self) { kind in
                        AwradOptionRow(Strings.referenceKind(kind), isSelected: draft.kind == kind) {
                            send(.referenceKindSelected(kind))
                        }
                    }
                }
                fields
                AwradButton(Strings.add) { send(.referenceAdded) }
                AwradButton(Strings.cancel, variant: .text) { send(.referenceCancelled) }
            }
            .pageInset()
            .padding(.bottom, AwradSpacing.lg)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    @ViewBuilder private var fields: some View {
        switch draft.kind {
        case .quran:
            field(.surah, \.surah, number: true)
            field(.ayahStart, \.ayahStart, number: true)
            field(.ayahEnd, \.ayahEnd, number: true)
        case .hadith:
            field(.collection, \.collection)
            plain(Strings.hadithNumber, \.number)
            plain(Strings.narrator, \.narrator)
            plain(Strings.grade, \.grade)
        case .book:
            field(.bookTitle, \.bookTitle)
            plain(Strings.author, \.author)
            plain(Strings.volume, \.volume)
            plain(Strings.page, \.page)
        case .shaykh:
            field(.name, \.name)
            plain(Strings.note, \.note)
        case .other:
            field(.text, \.text)
            field(.link, \.link)
        }
    }

    /// A field that can have a problem.
    private func field(
        _ field: ReferenceDraft.Field, _ path: WritableKeyPath<ReferenceDraft, String>, number: Bool = false
    ) -> some View {
        LabeledField(
            label: Strings.referenceField(field), text: draft[keyPath: path], onChange: { edit(path, $0) },
            error: draft.showsProblems ? draft.problems[field].map(Strings.referenceProblem) : nil,
            kind: number ? .number : .line)
    }

    private func plain(
        _ label: LocalizedStringResource, _ path: WritableKeyPath<ReferenceDraft, String>
    ) -> some View {
        LabeledField(label: label, text: draft[keyPath: path], onChange: { edit(path, $0) })
    }

    private func edit(_ path: WritableKeyPath<ReferenceDraft, String>, _ text: String) {
        var edited = draft
        edited[keyPath: path] = text
        send(.referenceDraftChanged(edited))
    }
}

/// The user's tags as multiple-choice rows, then Manage tags.
struct TagChooserSheet: View {
    let personal: PersonalContent
    let chosen: [AwradID]
    let send: EditorSend
    let onManageTags: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AwradSpacing.lg) {
                Text(Strings.chooseTags)
                    .awradTextStyle(.title)
                    .foregroundStyle(AwradColors.onSurface)
                    .accessibilityAddTraits(.isHeader)
                if personal.tags.isEmpty {
                    Text(Strings.noTagsYet)
                        .awradTextStyle(.body)
                        .foregroundStyle(AwradColors.onSurfaceVariant)
                } else {
                    VStack(spacing: AwradSpacing.rowGap) {
                        ForEach(personal.tags) { tag in
                            AwradOptionRow(
                                Strings.verbatim(tag.name), isSelected: chosen.contains(tag.id),
                                selection: .multiple
                            ) { send(.tagToggled(tag.id)) }
                        }
                    }
                }
                AwradButton(Strings.manageTags, variant: .secondary) {
                    send(.chooseTagsChanged(false))
                    onManageTags()
                }
                AwradButton(Strings.done) { send(.chooseTagsChanged(false)) }
            }
            .pageInset()
            .padding(.bottom, AwradSpacing.lg)
        }
    }
}
