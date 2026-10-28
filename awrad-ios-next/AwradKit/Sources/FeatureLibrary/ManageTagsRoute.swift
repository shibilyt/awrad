import AwradDesignSystem
import AwradDomain
import SwiftUI

/// Manage tags, pushed from the Library. With a `dhikr`, each tag is a choice for it.
struct ManageTagsRoute: View {
    @State private var model: ManageTagsModel

    init(dhikr: AwradID?, personal: PersonalContent, library: any PersonalLibrary) {
        _model = State(initialValue: ManageTagsModel(library: library, dhikr: dhikr, personal: personal))
    }

    var body: some View {
        ManageTagsScreen(state: model.state) { action in
            if !model.apply(action) { Task { await model.send(action) } }
        }
        .task { await model.observe() }
    }
}

/// Stateless: the conflicts, the new tag field and the tags, with the rename sheet and the delete
/// confirmation.
struct ManageTagsScreen: View {
    let state: ManageTagsModel.State
    let send: (ManageTagsModel.Action) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AwradSpacing.sectionGap) {
                ForEach(state.conflicts, id: \.key) { conflict in
                    ConflictBanner(
                        name: state.personal.tag(conflict.key.id)?.name,
                        onKeepMine: { send(.resolveConflict(conflict.key, .keepMine)) },
                        onUseTheirs: { send(.resolveConflict(conflict.key, .useTheirs)) }
                    )
                    .pageInset()
                }
                newTag
                if let failure = state.failure { FailureText(failure: failure).pageInset() }
                tags
            }
            .padding(.vertical, AwradSpacing.sm)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AwradColors.background)
        .navigationTitle(Text(Strings.manageTags))
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .awradBottomSheet(
            isPresented: Binding(get: { state.renaming != nil }, set: { if !$0 { send(.renameCancelled) } }),
            detents: [.medium]
        ) {
            if let renaming = state.renaming { RenameTagSheet(renaming: renaming, send: send) }
        }
        .awradDialog(
            isPresented: Binding(get: { state.deleting != nil }, set: { if !$0 { send(.deleteCancelled) } }),
            title: Strings.deleteTagTitle, message: Strings.deleteTagMessage
        ) {
            AwradButton(Strings.cancel, variant: .text, layout: .row) { send(.deleteCancelled) }
            AwradButton(Strings.delete, variant: .error, layout: .row, role: .destructive) {
                send(.deleteConfirmed)
            }
        }
    }

    private var newTag: some View {
        AwradCard {
            LabeledField(
                label: Strings.newTagField, text: state.newName, onChange: { send(.newNameChanged($0)) },
                error: state.newNameError.map(Strings.message))
            AwradButton(Strings.add) { send(.addTapped) }
        }
        .pageInset()
    }

    @ViewBuilder private var tags: some View {
        VStack(alignment: .leading, spacing: AwradSpacing.rowGap) {
            if state.dhikr != nil, !state.tags.isEmpty {
                AwradButton(state.isEditing ? Strings.done : Strings.editTags, variant: .text, layout: .row) {
                    send(.editingToggled)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            if state.tags.isEmpty {
                Text(Strings.tagsEmpty)
                    .awradTextStyle(.body)
                    .foregroundStyle(AwradColors.onSurfaceVariant)
            }
            ForEach(state.tags) { tag in
                if state.isEditing {
                    EditableTagRow(tag: tag, send: send)
                } else {
                    AwradOptionRow(
                        Strings.verbatim(tag.name), isSelected: state.selectedIDs.contains(tag.id),
                        selection: .multiple
                    ) { send(.toggled(tag.id)) }
                }
            }
        }
        .pageInset()
    }
}

/// A tag's name with Rename and Delete.
private struct EditableTagRow: View {
    let tag: UserTag
    let send: (ManageTagsModel.Action) -> Void

    var body: some View {
        AwradCard(AwradRadius.tile) {
            Text(verbatim: tag.name)
                .awradTextStyle(.rowTitle)
                .foregroundStyle(AwradColors.onSurface)
            HStack(spacing: AwradSpacing.sm) {
                AwradButton(Strings.renameTag, variant: .text, layout: .row) { send(.renameTapped(tag)) }
                AwradButton(Strings.delete, variant: .text, layout: .row, role: .destructive) {
                    send(.deleteTapped(tag))
                }
            }
        }
    }
}

/// The rename sheet: the tag's name in a field, Save and Cancel.
private struct RenameTagSheet: View {
    let renaming: ManageTagsModel.Renaming
    let send: (ManageTagsModel.Action) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AwradSpacing.lg) {
            Text(Strings.renameTagTitle)
                .awradTextStyle(.title)
                .foregroundStyle(AwradColors.onSurface)
                .accessibilityAddTraits(.isHeader)
            LabeledField(
                label: Strings.tagName, text: renaming.name, onChange: { send(.renameNameChanged($0)) },
                error: renaming.error.map(Strings.message))
            AwradButton(Strings.save) { send(.renameConfirmed) }
            AwradButton(Strings.cancel, variant: .text) { send(.renameCancelled) }
        }
        .pageInset()
    }
}

#if DEBUG
    private func tagsPreview(dhikr: AwradID?) -> some View {
        let personal = PreviewContent.personal
        return NavigationStack {
            ManageTagsRoute(dhikr: dhikr, personal: personal, library: PreviewPersonalLibrary(personal))
        }
    }

    #Preview("Manage tags") {
        tagsPreview(dhikr: nil)
    }

    #Preview("Choose tags, Malayalam, dark") {
        tagsPreview(dhikr: PreviewContent.custom.id)
            .environment(\.locale, Locale(identifier: "ml"))
            .preferredColorScheme(.dark)
    }
#endif
