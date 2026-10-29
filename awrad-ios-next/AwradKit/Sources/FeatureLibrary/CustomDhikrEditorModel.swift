import AwradDomain
import Foundation
import Observation

/// The custom dhikr editor: a new dhikr or an existing one. Saving checks the document against
/// `CustomDhikrValidation` first and shows each problem on its field.
@Observable
final class CustomDhikrEditorModel {
    /// The dhikr's recording as the editor has it.
    enum Recording: Equatable, Sendable {
        case none
        /// The recording the dhikr has on this device.
        case existing(URL)
        /// The dhikr's recording is in the account but not on this device yet: the first play
        /// downloads it.
        case inAccount
        /// A recording just picked, saved with the dhikr.
        case staged(StagedAudio)

        var url: URL? {
            switch self {
            case .none, .inAccount: nil
            case .existing(let url): url
            case .staged(let staged): staged.url
            }
        }
    }

    /// How the editor ended; the route leaves the screen.
    enum Outcome: Equatable, Sendable {
        case saved(AwradID, isNew: Bool)
        case deleted

        /// What the Library does next: the new dhikr's page, back to the page it came from, or the root.
        var libraryAction: LibraryModel.Action {
            switch self {
            case .saved(let id, let isNew): .editorSaved(id, isNew: isNew)
            case .deleted: .popToRoot
            }
        }
    }

    /// The first field with a problem after a save that found some: the screen scrolls to it and
    /// VoiceOver reads its message. `attempt` tells one failed save from the next.
    struct ProblemFocus: Equatable, Sendable {
        let field: EditorField
        let problem: FieldProblem
        let attempt: Int
    }

    struct State: Equatable, Sendable {
        /// The custom dhikr being edited; `nil` for a new one.
        let existing: CustomDhikr?
        var form: CustomDhikrForm
        /// The language the title and texts show.
        var language = CatalogLanguage.en
        var errors: [EditorField: FieldProblem] = [:]
        var problemFocus: ProblemFocus?
        /// Why saving or deleting failed, when no field says it.
        var failure: EditFailure?
        /// The user's tags, to choose from.
        var personal: PersonalContent
        var recording = Recording.none
        var audio = DhikrDetailModel.Audio.unavailable
        /// Why a picked recording was refused.
        var audioFailure: EditFailure?
        var isPickingAudio = false
        var isChoosingTags = false
        /// The reference sheet, while it's open.
        var referenceDraft: ReferenceDraft?
        var isConfirmingDelete = false
        var isSaving = false
        var outcome: Outcome?

        var isNew: Bool { existing == nil }
        var canAddReference: Bool { form.references.count < CustomDhikrValidation.maxReferences }
        var chosenTags: [UserTag] { form.tagIDs.compactMap(personal.tag) }
    }

    enum Action: Sendable {
        case kindSelected(DhikrKind)
        case arabicChanged(String)
        case languageSelected(CatalogLanguage)
        case textChanged(CustomDhikrForm.TextRole, CatalogLanguage, String)

        case addReferenceTapped
        case referenceKindSelected(ReferenceDraft.Kind)
        case referenceDraftChanged(ReferenceDraft)
        case referenceAdded
        case referenceCancelled
        case referenceRemoved(Int)

        case chooseTagsChanged(Bool)
        case tagToggled(AwradID)
        case personalChanged(PersonalContent)

        case addRecordingTapped
        case pickerChanged(Bool)
        case audioPicked(URL)
        case audioPickFailed
        case recordingRemoved
        case playPauseTapped
        case disappeared
        case backgrounded

        case saveTapped
        case deleteTapped
        case deleteDismissed
        case deleteConfirmed
        case failureDismissed
    }

    var state: State
    let library: any PersonalLibrary
    let driver: AudioPlaybackDriver
    /// The ID once saved: saving again replaces the dhikr rather than adding another.
    private var savedID: AwradID?
    /// The tags the library has on the dhikr, to see whether saving changes them.
    private var appliedTagIDs: [AwradID]
    /// The recording the saved document names; saving with `.unchanged` keeps it.
    private var audio: CustomDhikrAudio?
    var removedRecording = false
    private var didLoadRecording = false

    init(
        library: any PersonalLibrary, existing: CustomDhikr? = nil, tagIDs: [AwradID] = [],
        personal: PersonalContent = .empty, makePlayer: @escaping @MainActor () -> any DhikrAudioPlayer
    ) {
        self.library = library
        let form = existing.map { CustomDhikrForm($0, tagIDs: tagIDs) } ?? CustomDhikrForm(tagIDs: tagIDs)
        state = State(existing: existing, form: form, personal: personal)
        appliedTagIDs = tagIDs
        audio = existing?.document.audio
        driver = AudioPlaybackDriver(makePlayer: makePlayer)
        driver.onStatus = { [weak self] status in self?.state.audio = .init(status) }
    }

    /// Looks up the recording the dhikr has on this device, once.
    func loadRecording() async {
        guard !didLoadRecording, let id = state.existing?.id else { return }
        didLoadRecording = true
        if let url = await library.audioURL(for: id) {
            state.recording = .existing(url)
            state.audio = .stopped
        } else if audio?.uploaded != nil {
            state.recording = .inAccount
            state.audio = .stopped
        }
    }

    /// The first play of a recording that's only in the account: download it, then play it.
    func downloadAndPlay() async {
        guard let id = state.existing?.id, state.recording == .inAccount, state.audio != .loading else { return }
        state.audio = .loading
        do {
            let url = try await library.downloadAudio(for: id)
            guard state.recording == .inAccount else { return }
            state.recording = .existing(url)
            driver.play(url)
        } catch {
            if state.recording == .inAccount { state.audio = .failed }
        }
    }

    /// Loads the recording, then follows the user's tags while the screen is up.
    func observe() async {
        await loadRecording()
        for await personal in library.updates() {
            apply(.personalChanged(personal))
        }
    }

    /// Typing and sheets apply at once; saving, deleting and picking a file are for `send`. Returns
    /// whether it handled the action.
    @discardableResult
    func apply(_ action: Action) -> Bool {
        if case .playPauseTapped = action, state.recording == .inAccount { return false }
        switch action {
        case .kindSelected, .arabicChanged, .languageSelected, .textChanged:
            edit(action)
        case .addReferenceTapped, .referenceKindSelected, .referenceDraftChanged, .referenceAdded,
            .referenceCancelled, .referenceRemoved:
            editReferences(action)
        case .chooseTagsChanged, .tagToggled, .personalChanged:
            editTags(action)
        case .addRecordingTapped, .pickerChanged, .audioPickFailed, .recordingRemoved, .playPauseTapped,
            .disappeared, .backgrounded:
            editRecording(action)
        case .deleteTapped:
            state.isConfirmingDelete = true
        case .deleteDismissed:
            state.isConfirmingDelete = false
        case .failureDismissed:
            state.failure = nil
        case .audioPicked, .saveTapped, .deleteConfirmed:
            return false
        }
        return true
    }

    /// The screen's whole interface to the model.
    func send(_ action: Action) async {
        if apply(action) { return }
        switch action {
        case .audioPicked(let url): await stage(url)
        case .playPauseTapped: await downloadAndPlay()
        case .saveTapped: await save()
        case .deleteConfirmed: await delete()
        default: break
        }
    }

    // MARK: - Writes

    /// Copies a picked file into the profile. The picker's URL is only readable while it's open.
    private func stage(_ url: URL) async {
        let isScoped = url.startAccessingSecurityScopedResource()
        defer { if isScoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let staged = try await library.stageAudio(from: url)
            driver.stop()
            state.recording = .staged(staged)
            state.audio = .stopped
            state.audioFailure = nil
        } catch {
            state.audioFailure = EditFailure(error)
        }
    }

    private var audioChange: AudioChange {
        switch state.recording {
        case .staged(let staged): .replace(staged)
        case .none: removedRecording ? .remove : .unchanged
        case .existing, .inAccount: .unchanged
        }
    }

    private func save() async {
        state.failure = nil
        state.errors = [:]
        let document = state.form.document(audio: audio)
        let problems = document.validationErrors
        guard problems.isEmpty else {
            show(problems)
            return
        }
        state.isSaving = true
        defer { state.isSaving = false }
        do {
            let change = audioChange
            let id = try await library.saveCustomDhikr(
                id: savedID ?? state.existing?.id, document: document, audio: change)
            savedID = id
            settleRecording(change)
            if state.form.tagIDs != appliedTagIDs {
                try await library.setTags(state.form.tagIDs, on: id)
                appliedTagIDs = state.form.tagIDs
            }
            driver.stop()
            state.outcome = .saved(id, isNew: state.isNew)
        } catch {
            if case .invalidDhikr(let problems) = error {
                show(problems)
            } else {
                state.failure = EditFailure(error)
            }
        }
    }

    /// After the dhikr is saved, the recording it was saved with is the one it has: a new one is
    /// local until it's uploaded.
    private func settleRecording(_ change: AudioChange) {
        if case .staged(let staged) = state.recording { state.recording = .existing(staged.url) }
        switch change {
        case .replace: audio = .localOnly
        case .remove: audio = nil
        case .unchanged: break
        }
        removedRecording = false
    }

    private func delete() async {
        state.isConfirmingDelete = false
        guard let id = savedID ?? state.existing?.id else { return }
        do {
            try await library.deleteCustomDhikr(id)
            driver.stop()
            state.outcome = .deleted
        } catch {
            state.failure = EditFailure(error)
        }
    }

    /// Puts each problem on its field, shows the first language that has one, and points the screen
    /// at the first field with a problem.
    private func show(_ problems: [SyncFieldError]) {
        let (fields, unplaced) = EditorField.problems(from: problems)
        state.errors = fields
        if !unplaced.isEmpty { state.failure = .invalidDhikr }
        let order = CatalogLanguage.allCases
        if !fields.keys.contains(where: { $0.language == state.language }),
            let language = order.first(where: { language in fields.keys.contains { $0.language == language } })
        {
            state.language = language
        }
        if let field = EditorField.first(of: fields.keys, showing: state.language), let problem = fields[field] {
            let attempt = (state.problemFocus?.attempt ?? 0) + 1
            state.problemFocus = ProblemFocus(field: field, problem: problem, attempt: attempt)
        }
    }
}
