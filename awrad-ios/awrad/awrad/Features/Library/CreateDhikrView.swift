import SwiftUI
import UniformTypeIdentifiers

struct CreateDhikrView: View {
    @Environment(AwradStore.self) private var store
    @Environment(AppRouter.self) private var router
    let editingDhikrID: AwradID?
    @State private var title = ""
    @State private var arabic = ""
    @State private var transliteration = ""
    @State private var translation = ""
    @State private var category: DhikrCategory = .general
    @State private var audioCountPerPlay = 1
    @State private var selectedTagIDs: Set<AwradID> = []
    @State private var newTagName = ""
    @State private var tagErrorMessage: String?
    @State private var stagedAudio: StagedOwnedDhikrAudio?
    @State private var removeExistingAudio = false
    @State private var importErrorKey: String?
    @State private var isImporterPresented = false
    @State private var isSaving = false
    @State private var didHydrate = false

    init(editingDhikrID: AwradID? = nil) {
        self.editingDhikrID = editingDhikrID
    }

    private var canSave: Bool {
        !arabic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving
    }

    private var isEditing: Bool {
        editingDhikrID != nil
    }

    private var saveTitle: LocalizedStringKey {
        isEditing ? "Save Dhikr" : "Create Dhikr"
    }

    private var existingAsset: DhikrAudioAsset? {
        guard let editingDhikrID else { return nil }
        return store.audioAsset(for: editingDhikrID)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                textFields
                categoryPicker
                audioSection
                tagsSection
                saveButton
            }
            .padding(20)
            .padding(.bottom, 96)
        }
        .background(AwradTheme.background)
        .navigationTitle(isEditing ? "Edit Dhikr" : "Create Dhikr")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    save()
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                }
                .disabled(!canSave)
                .accessibilityLabel(saveTitle)
            }
        }
        .onAppear(perform: hydrateIfNeeded)
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [
                UTType(filenameExtension: "m4a") ?? .audio,
                UTType(filenameExtension: "aac") ?? .audio,
                UTType(filenameExtension: "mp3") ?? .audio,
                UTType(filenameExtension: "wav") ?? .audio,
                .mpeg4Audio,
                .wav,
            ],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .alert("Audio import failed", isPresented: Binding(
            get: { importErrorKey != nil },
            set: { if !$0 { importErrorKey = nil } }
        )) {
            Button("OK", role: .cancel) { importErrorKey = nil }
        } message: {
            if let importErrorKey {
                Text(LocalizedStringKey(importErrorKey))
            }
        }
    }

    private var textFields: some View {
        VStack(alignment: .leading, spacing: 14) {
            DhikrInputField(
                title: "Arabic text",
                placeholder: "Write the dhikr in Arabic",
                text: $arabic,
                axis: .vertical,
                font: AwradTheme.arabicFont(26),
                lineLimit: 3...8,
                textAlignment: .trailing
            )
            .environment(\.layoutDirection, .rightToLeft)

            DhikrInputField(
                title: "Title",
                placeholder: "Optional title",
                text: $title
            )

            DhikrInputField(
                title: "Transliteration",
                placeholder: "Optional transliteration",
                text: $transliteration
            )

            DhikrInputField(
                title: "Translation",
                placeholder: "Optional translation",
                text: $translation,
                axis: .vertical,
                lineLimit: 2...5
            )
        }
    }

    private var categoryPicker: some View {
        AwradCard {
            VStack(alignment: .leading, spacing: 14) {
                Label("Category", systemImage: "square.grid.2x2.fill")
                    .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                    .foregroundStyle(AwradTheme.ink)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                    ForEach(DhikrCategory.allCases) { option in
                        Button {
                            category = option
                        } label: {
                            Label {
                                Text(LocalizedStringKey(option.title))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.82)
                            } icon: {
                                Image(systemName: option.symbol)
                            }
                            .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                            .frame(maxWidth: .infinity, minHeight: 42)
                            .padding(.horizontal, 12)
                            .foregroundStyle(category == option ? .white : AwradTheme.sage)
                            .background(
                                category == option ? AwradTheme.sage : AwradTheme.mint.opacity(0.18),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var audioSection: some View {
        AwradCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Audio", systemImage: "waveform")
                    .font(AwradTheme.bodyFont(.headline, weight: .semibold))

                Text("Upload AAC/M4A, MP3, or WAV under 10 MB and 10 minutes. Audio stays on this device.")
                    .font(AwradTheme.bodyFont(.caption))
                    .foregroundStyle(.secondary)

                if let stagedAudio {
                    Text(
                        String.localizedStringWithFormat(
                            String(localized: String.LocalizationValue(OwnedDhikrAudioImportCopy.readyToAttachKey)),
                            stagedAudio.byteSize
                        )
                    )
                    .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                    Button(LocalizedStringKey(OwnedDhikrAudioImportCopy.removeStagedKey), role: .destructive) {
                        try? store.ownedAudioStore.discardStaged(stagedAudio)
                        self.stagedAudio = nil
                    }
                } else if existingAsset != nil, !removeExistingAudio {
                    let playable = existingAsset.flatMap { store.ownedAudioStore.resolvePlayableURL(for: $0) } != nil
                    Text(playable ? "Owned audio attached" : "Audio missing — reattach or remove")
                        .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                    HStack {
                        Button("Replace audio") { isImporterPresented = true }
                        Button("Remove audio", role: .destructive) {
                            removeExistingAudio = true
                        }
                    }
                } else {
                    Button("Upload audio") { isImporterPresented = true }
                        .accessibilityLabel("Upload audio")
                }

                Stepper(value: $audioCountPerPlay, in: 1...99) {
                    Text("Counts per playback: \(audioCountPerPlay)")
                }
                .accessibilityLabel("Counts per playback")
            }
        }
    }

    private var tagsSection: some View {
        AwradCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Tags", systemImage: "tag.fill")
                        .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                    Spacer()
                    Text("\(selectedTagIDs.count)/\(UserTagPolicy.maxTagsPerDhikr)")
                        .font(AwradTheme.bodyFont(.caption, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("\(selectedTagIDs.count) of \(UserTagPolicy.maxTagsPerDhikr) tags selected")
                }

                if store.userTags.isEmpty {
                    Text("Create a tag to organize this dhikr.")
                        .font(AwradTheme.bodyFont(.caption))
                        .foregroundStyle(.secondary)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                        ForEach(sortedAssignableTags) { tag in
                            let selected = selectedTagIDs.contains(tag.id)
                            Button {
                                toggleTagAssignment(tag.id)
                            } label: {
                                Text(tag.name)
                                    .font(AwradTheme.bodyFont(.caption, weight: .semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .foregroundStyle(selected ? .white : AwradTheme.sage)
                                    .background(
                                        selected ? AwradTheme.sage : AwradTheme.mint.opacity(0.18),
                                        in: Capsule()
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(tag.name)
                            .accessibilityValue(selected ? "Assigned" : "Not assigned")
                            .accessibilityHint(
                                selected
                                    ? "Removes this tag from the dhikr"
                                    : "Assigns this tag to the dhikr"
                            )
                            .accessibilityAddTraits(selected ? .isSelected : [])
                        }
                    }
                }

                HStack {
                    TextField("New tag", text: $newTagName)
                        .textInputAutocapitalization(.words)
                        .accessibilityLabel("New tag name")
                    Button("Add") {
                        createAndAssignTag()
                    }
                    .disabled(UserTagPolicy.normalize(newTagName) == nil)
                    .accessibilityLabel("Create tag")
                }

                if selectedTagIDs.count >= UserTagPolicy.maxTagsPerDhikr {
                    Text("A dhikr can have at most \(UserTagPolicy.maxTagsPerDhikr) tags.")
                        .font(AwradTheme.bodyFont(.caption))
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Tag limit reached")
                }
            }
        }
        .alert("Could not update tags", isPresented: Binding(
            get: { tagErrorMessage != nil },
            set: { if !$0 { tagErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { tagErrorMessage = nil }
        } message: {
            Text(tagErrorMessage ?? "")
        }
    }

    private var sortedAssignableTags: [UserTag] {
        store.userTags.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private func toggleTagAssignment(_ tagID: AwradID) {
        if selectedTagIDs.contains(tagID) {
            selectedTagIDs.remove(tagID)
        } else if selectedTagIDs.count < UserTagPolicy.maxTagsPerDhikr {
            selectedTagIDs.insert(tagID)
        } else {
            tagErrorMessage = "A dhikr can have at most \(UserTagPolicy.maxTagsPerDhikr) tags."
        }
    }

    private func createAndAssignTag() {
        guard let tag = store.createUserTag(name: newTagName) else {
            tagErrorMessage = "That tag name is invalid or already exists."
            return
        }
        newTagName = ""
        if selectedTagIDs.count < UserTagPolicy.maxTagsPerDhikr {
            selectedTagIDs.insert(tag.id)
        } else {
            tagErrorMessage = "Tag created. A dhikr can have at most \(UserTagPolicy.maxTagsPerDhikr) tags."
        }
    }

    private var saveButton: some View {
        Button {
            save()
        } label: {
            Label(saveTitle, systemImage: "checkmark.circle.fill")
                .frame(maxWidth: .infinity)
        }
        .awradPrimaryButton()
        .disabled(!canSave)
        .opacity(canSave ? 1 : 0.55)
        .accessibilityHint(canSave ? "" : "Arabic text is required")
    }

    private func hydrateIfNeeded() {
        guard !didHydrate, let editingDhikrID, let dhikr = store.dhikr(id: editingDhikrID), dhikr.isCustom else {
            didHydrate = true
            return
        }

        title = dhikr.title
        arabic = dhikr.arabic
        transliteration = dhikr.transliteration
        translation = dhikr.translation
        category = dhikr.category
        audioCountPerPlay = max(dhikr.audioCountPerPlay, 1)
        selectedTagIDs = Set(
            store.tagAssignments.filter { $0.dhikrID == editingDhikrID }.map(\.tagID)
        )
        didHydrate = true
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure:
            break
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed { url.stopAccessingSecurityScopedResource() }
            }
            do {
                if let stagedAudio {
                    try store.ownedAudioStore.discardStaged(stagedAudio)
                }
                let staged = try store.ownedAudioStore.stageImport(
                    from: url,
                    suggestedExtension: url.pathExtension
                )
                stagedAudio = staged
                removeExistingAudio = false
            } catch let error as OwnedDhikrAudioError {
                importErrorKey = OwnedDhikrAudioImportCopy.messageKey(for: error)
            } catch {
                importErrorKey = OwnedDhikrAudioImportCopy.messageKey(for: .corruptMedia)
            }
        }
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        let dhikr: Dhikr?
        if let editingDhikrID, let existing = store.dhikr(id: editingDhikrID) {
            dhikr = store.updateDhikr(
                id: editingDhikrID,
                title: title,
                arabic: arabic,
                transliteration: transliteration,
                translation: translation,
                category: category,
                audioURL: existing.audioURL,
                audioFileName: existing.audioFileName,
                quranRef: existing.quranRef,
                audioCountPerPlay: audioCountPerPlay
            )
        } else {
            dhikr = store.createDhikr(
                title: title,
                arabic: arabic,
                transliteration: transliteration,
                translation: translation,
                category: category
            )
            if let created = dhikr {
                _ = store.updateDhikr(
                    id: created.id,
                    title: created.title,
                    arabic: created.arabic,
                    transliteration: created.transliteration,
                    translation: created.translation,
                    category: created.category,
                    audioURL: created.audioURL,
                    audioFileName: created.audioFileName,
                    quranRef: created.quranRef,
                    audioCountPerPlay: audioCountPerPlay
                )
            }
        }
        guard let savedID = dhikr?.id, let saved = store.dhikr(id: savedID) else { return }

        if removeExistingAudio {
            _ = store.removeOwnedAudio(from: saved.id)
        }
        if let stagedAudio {
            let attached = store.attachOwnedAudio(stagedAudio, to: saved.id) != nil
            let outcome = CreateDhikrAudioAttachmentPolicy.outcome(
                attachSucceeded: attached,
                staged: stagedAudio
            )
            if outcome.clearStaged {
                if !attached {
                    try? store.ownedAudioStore.discardStaged(stagedAudio)
                }
                self.stagedAudio = nil
            }
            if let messageKey = outcome.messageKey {
                importErrorKey = messageKey
            }
            if outcome.keepEditing {
                return
            }
        }

        let currentAssignments = Set(store.tagAssignments.filter { $0.dhikrID == saved.id }.map(\.tagID))
        for tagID in currentAssignments.subtracting(selectedTagIDs) {
            _ = store.unassignTag(tagID, from: saved.id)
        }
        for tagID in selectedTagIDs.subtracting(currentAssignments) {
            _ = store.assignTag(tagID, to: saved.id)
        }

        router.replaceLast(with: .dhikrDetail(saved.id), in: store.selectedTab)
    }
}

private struct DhikrInputField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var axis: Axis = .horizontal
    var font: Font = .body
    var closedLineLimit: ClosedRange<Int>?
    var textAlignment: TextAlignment = .leading

    init(
        title: String,
        placeholder: String,
        text: Binding<String>,
        axis: Axis = .horizontal,
        font: Font = .body,
        lineLimit: ClosedRange<Int>? = nil,
        textAlignment: TextAlignment = .leading
    ) {
        self.title = title
        self.placeholder = placeholder
        self._text = text
        self.axis = axis
        self.font = font
        self.closedLineLimit = lineLimit
        self.textAlignment = textAlignment
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStringKey(title))
                .font(AwradTheme.bodyFont(.caption, weight: .semibold))
                .foregroundStyle(.secondary)

            TextField(
                LocalizedStringKey(title),
                text: $text,
                prompt: Text(LocalizedStringKey(placeholder)),
                axis: axis
            )
            .font(font)
            .multilineTextAlignment(textAlignment)
            .modifier(OptionalLineLimitModifier(limit: closedLineLimit))
            .textInputAutocapitalization(.sentences)
            .autocorrectionDisabled()
            .accessibilityIdentifier("dhikr-input-\(title)")
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AwradTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

private struct OptionalLineLimitModifier: ViewModifier {
    var limit: ClosedRange<Int>?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let limit {
            content.lineLimit(limit)
        } else {
            content
        }
    }
}
