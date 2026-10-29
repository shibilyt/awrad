import AwradDomain
import Foundation

/// The editor's local, immediate edits: fields, references, tags and the recording's player.
extension CustomDhikrEditorModel {
    func edit(_ action: Action) {
        switch action {
        case .kindSelected(let kind):
            state.form.kind = kind
        case .arabicChanged(let text):
            state.form.arabic = text
            state.errors[.arabic] = nil
        case .languageSelected(let language):
            state.language = language
        case .textChanged(let role, let language, let text):
            state.form[role][language] = text
            switch role {
            case .title:
                state.errors[.titleText(language)] = nil
                state.errors[.title] = nil
            case .transliteration: state.errors[.transliteration(language)] = nil
            case .translation: state.errors[.translation(language)] = nil
            }
        default:
            break
        }
    }

    func editReferences(_ action: Action) {
        switch action {
        case .addReferenceTapped:
            if state.canAddReference { state.referenceDraft = ReferenceDraft() }
        case .referenceKindSelected(let kind):
            state.referenceDraft?.kind = kind
        case .referenceDraftChanged(let draft):
            state.referenceDraft = draft
        case .referenceAdded:
            guard var draft = state.referenceDraft else { return }
            if let reference = draft.reference(among: state.form.references) {
                state.form.references.append(reference)
                state.referenceDraft = nil
                state.errors[.references] = nil
            } else {
                draft.showsProblems = true
                state.referenceDraft = draft
            }
        case .referenceCancelled:
            state.referenceDraft = nil
        case .referenceRemoved(let index):
            guard state.form.references.indices.contains(index) else { return }
            state.form.references.remove(at: index)
            state.errors = state.errors.filter { key, _ in
                if case .reference = key { false } else { key != .references }
            }
        default:
            break
        }
    }

    func editTags(_ action: Action) {
        switch action {
        case .chooseTagsChanged(let isChoosing):
            state.isChoosingTags = isChoosing
        case .tagToggled(let id):
            if let index = state.form.tagIDs.firstIndex(of: id) {
                state.form.tagIDs.remove(at: index)
            } else {
                state.form.tagIDs.append(id)
            }
        case .personalChanged(let personal):
            state.personal = personal
            // A tag deleted meanwhile (on another device, or in Manage tags) leaves the choice.
            let existing = Set(personal.tags.map(\.id))
            state.form.tagIDs = state.form.tagIDs.filter(existing.contains)
        default:
            break
        }
    }

    func editRecording(_ action: Action) {
        switch action {
        case .addRecordingTapped:
            state.isPickingAudio = true
        case .pickerChanged(let isPicking):
            state.isPickingAudio = isPicking
        case .audioPickFailed:
            state.audioFailure = .audioUnreadable
        case .recordingRemoved:
            driver.stop()
            state.recording = .none
            state.recordingLength = nil
            state.audio = .unavailable
            state.audioFailure = nil
            removedRecording = true
        case .playPauseTapped:
            togglePlayback()
        case .disappeared:
            driver.stop()
            if state.audio != .unavailable { state.audio = .stopped }
        case .backgrounded:
            if state.audio.isActive { driver.pause() }
        default:
            break
        }
    }

    func togglePlayback() {
        guard let url = state.recording.url else { return }
        if state.audio.isActive {
            driver.pause()
            return
        }
        if case .paused = state.audio {} else { state.audio = .loading }
        driver.play(url)
    }
}
