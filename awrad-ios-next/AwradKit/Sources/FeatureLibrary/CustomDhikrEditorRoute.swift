import AwradDesignSystem
import AwradDomain
import SwiftUI
import UniformTypeIdentifiers

/// The custom dhikr editor, pushed from the Library. `existing` is the dhikr being edited, or `nil`
/// for a new one. `navigate` takes the Library action that follows saving or deleting.
struct CustomDhikrEditorRoute: View {
    @State private var model: CustomDhikrEditorModel
    @Environment(\.scenePhase) private var scenePhase
    private let navigate: (LibraryModel.Action) -> Void

    init(
        existing: CustomDhikr?, personal: PersonalContent, services: LibraryServices,
        navigate: @escaping (LibraryModel.Action) -> Void
    ) {
        _model = State(
            initialValue: CustomDhikrEditorModel(
                library: services.library, existing: existing,
                tagIDs: existing.flatMap { personal.tagsByDhikr[$0.id] } ?? [], personal: personal,
                makePlayer: services.makePlayer))
        self.navigate = navigate
    }

    var body: some View {
        CustomDhikrEditorScreen(
            state: model.state,
            send: { action in
                if action.endsEditing { awradEndEditing() }
                if !model.apply(action) { Task { await model.send(action) } }
            },
            onManageTags: { navigate(.openManageTags(dhikr: nil)) }
        )
        .task { await model.observe() }
        .onDisappear { model.apply(.disappeared) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { model.apply(.backgrounded) }
        }
        .onChange(of: model.state.outcome) { _, outcome in
            if let outcome { navigate(outcome.libraryAction) }
        }
    }
}

extension CustomDhikrEditorModel.Action {
    /// Whether typing is over: Save, or a sheet, picker or dialog opening over the form. The route
    /// ends text editing first. Otherwise, when the tag chooser closes, the field typed in last
    /// takes focus back and the form scrolls to it, so a tap meant for Save misses or lands while
    /// the screen moves.
    var endsEditing: Bool {
        switch self {
        case .saveTapped, .chooseTagsChanged(true), .addReferenceTapped, .addRecordingTapped, .deleteTapped: true
        default: false
        }
    }
}

/// Stateless: the form, its sheets and the recording picker.
struct CustomDhikrEditorScreen: View {
    let state: CustomDhikrEditorModel.State
    let send: EditorSend
    let onManageTags: () -> Void
    @Environment(\.awradMotion) private var motion

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: AwradSpacing.sectionGap) {
                    EditorTextSections(state: state, send: send)
                    EditorReferencesSection(state: state, send: send)
                        .id(EditorAnchor.references)
                    EditorTagsSection(state: state, send: send)
                    EditorRecordingSection(state: state, send: send)
                    actions
                }
                .padding(.vertical, AwradSpacing.sm)
            }
            // A save that found problems brings the first one into view and reads it out.
            .onChange(of: state.problemFocus) { _, focus in
                guard let focus else { return }
                motion.animate(AwradMotion.Spring.spatial.animation) {
                    proxy.scrollTo(focus.field.anchor, anchor: .top)
                }
                AccessibilityNotification.Announcement(
                    String(localized: Strings.message(for: focus.problem, field: focus.field))
                ).post()
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AwradColors.background)
        .navigationTitle(Text(state.isNew ? Strings.newDhikrTitle : Strings.editDhikrTitle))
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .awradBottomSheet(
            isPresented: Binding(
                get: { state.referenceDraft != nil }, set: { if !$0 { send(.referenceCancelled) } }),
            detents: [.large]
        ) {
            if let draft = state.referenceDraft { ReferenceSheet(draft: draft, send: send) }
        }
        .awradBottomSheet(isPresented: Binding(get: { state.isChoosingTags }, set: { send(.chooseTagsChanged($0)) })) {
            TagChooserSheet(
                personal: state.personal, chosen: state.form.tagIDs, send: send, onManageTags: onManageTags)
        }
        .fileImporter(
            isPresented: Binding(get: { state.isPickingAudio }, set: { send(.pickerChanged($0)) }),
            allowedContentTypes: [.mp3, .mpeg4Audio]
        ) { result in
            switch result {
            case .success(let url): send(.audioPicked(url))
            case .failure(let error): if (error as? CocoaError)?.code != .userCancelled { send(.audioPickFailed) }
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

    /// Save, a failure's message, and Delete for a dhikr that exists.
    private var actions: some View {
        VStack(spacing: AwradSpacing.rowGap) {
            if let failure = state.failure { FailureText(failure: failure) }
            AwradButton(Strings.save, isLoading: state.isSaving) { send(.saveTapped) }
            if !state.isNew {
                AwradButton(Strings.deleteDhikr, variant: .error) { send(.deleteTapped) }
            }
        }
        .pageInset()
    }
}

#if DEBUG
    private func editorPreview(_ existing: CustomDhikr? = nil) -> some View {
        let personal = PreviewContent.personal
        let services = LibraryServices(library: PreviewPersonalLibrary(personal)) { PreviewAudioPlayer() }
        return NavigationStack {
            CustomDhikrEditorRoute(existing: existing, personal: personal, services: services) { _ in }
        }
    }

    #Preview("New dhikr") {
        editorPreview()
    }

    #Preview("Edit, Arabic, dark") {
        editorPreview(PreviewContent.personal.customDhikrs.first)
            .environment(\.locale, Locale(identifier: "ar"))
            .environment(\.layoutDirection, .rightToLeft)
            .preferredColorScheme(.dark)
    }
#endif
