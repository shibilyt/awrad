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
    @State private var selectedCategories: [DhikrCategory] = [.general]
    @State private var categorySearchQuery = ""
    @State private var tagSearchQuery = ""
    @State private var audioCountPerPlay = 1
    @State private var selectedTagIDs: Set<AwradID> = []
    @State private var tagErrorMessage: String?
    @State private var stagedAudio: StagedOwnedDhikrAudio?
    @State private var removeExistingAudio = false
    @State private var importErrorKey: String?
    @State private var isImporterPresented = false
    @State private var isOptionalDetailsPresented = false
    @State private var isCategorySelectorPresented = false
    @State private var isTagSelectorPresented = false
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

    private var category: DhikrCategory {
        selectedCategories.first ?? .general
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
                composerIntro
                essentialFields
                optionalDetailsLauncher
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .background(AwradTheme.background)
        .navigationTitle(isEditing ? "Edit Dhikr" : "Create Dhikr")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                createDhikrBackButton
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 6) {
                saveButton
                Label("Saved privately on this device", systemImage: "lock.fill")
                    .font(AwradTheme.bodyFont(.caption2, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
        .sheet(isPresented: $isOptionalDetailsPresented) {
            optionalDetailsSheet
        }
        .sheet(isPresented: $isCategorySelectorPresented, onDismiss: reopenOptionalDetails) {
            categorySelectorSheet
        }
        .sheet(isPresented: $isTagSelectorPresented, onDismiss: reopenOptionalDetails) {
            tagSelectorSheet
        }
        .onAppear(perform: hydrateIfNeeded)
        .alert("Audio import failed", isPresented: Binding(
            get: { importErrorKey != nil && !isOptionalDetailsPresented },
            set: { if !$0 { importErrorKey = nil } }
        )) {
            Button("OK", role: .cancel) { importErrorKey = nil }
        } message: {
            if let importErrorKey {
                Text(LocalizedStringKey(importErrorKey))
            }
        }
    }

    @ViewBuilder
    private var createDhikrBackButton: some View {
        if #available(iOS 26.0, *) {
            backButton
                .buttonStyle(.glass)
        } else {
            backButton
                .buttonStyle(.plain)
                .background(.ultraThinMaterial, in: Circle())
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.16), lineWidth: 0.75)
                }
                .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        }
    }

    private var backButton: some View {
        Button {
            router.pop(in: store.selectedTab)
        } label: {
            Image(systemName: "chevron.backward")
                .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                .foregroundStyle(AwradTheme.sage)
                .frame(width: 38, height: 38)
                .contentShape(Circle())
        }
        .accessibilityLabel("Back")
        .accessibilityIdentifier("dhikr-create-back-button")
    }

    private var composerIntro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Begin with the words")
                .font(AwradTheme.displayFont(.title2, weight: .semibold))
                .foregroundStyle(AwradTheme.ink)

            Text("Arabic text is the only required field. Add the rest now or later.")
                .font(AwradTheme.bodyFont(.subheadline))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var essentialFields: some View {
        VStack(alignment: .leading, spacing: 14) {
            DhikrInputField(
                title: "Arabic text",
                placeholder: "Write the dhikr in Arabic",
                text: $arabic,
                axis: .vertical,
                font: AwradTheme.arabicFont(30),
                lineLimit: 4...9,
                textAlignment: .trailing,
                isRequired: true
            )
            .environment(\.layoutDirection, .rightToLeft)

            DhikrInputField(
                title: "Title",
                placeholder: "Optional title",
                text: $title
            )
        }
    }

    private var optionalDetailsLauncher: some View {
        Button {
            isOptionalDetailsPresented = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "plus")
                    .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                    .foregroundStyle(AwradTheme.sage)
                    .frame(width: 44, height: 44)
                    .background(AwradTheme.mint.opacity(0.32), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("Optional details")
                        .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                        .foregroundStyle(AwradTheme.ink)
                    Text("Translation, category, tags and audio")
                        .font(AwradTheme.bodyFont(.caption))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.forward")
                    .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(AwradTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AwradTheme.outline, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("dhikr-optional-details")
    }

    private var optionalDetailsSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Everything here is optional. You can come back at any time.")
                        .font(AwradTheme.bodyFont(.subheadline))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    optionalTextFields
                    categoryPicker
                    tagsSection
                    audioSection
                }
                .padding(20)
                .padding(.bottom, 24)
            }
            .background(AwradTheme.background)
            .navigationTitle("Optional details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isOptionalDetailsPresented = false
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
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

    private var optionalTextFields: some View {
        VStack(alignment: .leading, spacing: 14) {

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
        selectorLauncher(
            title: "Categories",
            summary: String.localizedStringWithFormat(
                String(localized: "Selected categories: %lld"),
                selectedCategories.count
            ),
            systemImage: "square.grid.2x2.fill"
        ) {
            categorySearchQuery = ""
            presentSelector(afterClosingOptional: $isCategorySelectorPresented)
        }
    }

    private var categorySelectorSheet: some View {
        searchableSelectorSheet(
            title: "Choose categories",
            searchPrompt: "Search categories",
            searchText: $categorySearchQuery
        ) {
            ForEach(filteredCategories) { option in
                selectorRow(
                    title: String(localized: String.LocalizationValue(option.title)),
                    systemImage: option.symbol,
                    isSelected: selectedCategories.contains(option)
                ) {
                    toggleCategory(option)
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
        selectorLauncher(
            title: "Tags",
            summary: selectedTagIDs.isEmpty
                ? String(localized: "No tags selected")
                : String.localizedStringWithFormat(String(localized: "Selected tags: %lld"), selectedTagIDs.count),
            systemImage: "tag.fill"
        ) {
            tagSearchQuery = ""
            presentSelector(afterClosingOptional: $isTagSelectorPresented)
        }
    }

    private var tagSelectorSheet: some View {
        searchableSelectorSheet(
            title: "Tags",
            searchPrompt: "Search or add tags",
            searchText: $tagSearchQuery
        ) {
            if canCreateSearchedTag, let candidate = UserTagPolicy.normalize(tagSearchQuery) {
                selectorRow(
                    title: String.localizedStringWithFormat(String(localized: "Add “%@”"), candidate.displayName),
                    systemImage: "plus",
                    isSelected: false
                ) {
                    createAndAssignTag(from: tagSearchQuery)
                }
            }
            ForEach(filteredAssignableTags) { tag in
                selectorRow(
                    title: tag.name,
                    systemImage: "tag",
                    isSelected: selectedTagIDs.contains(tag.id)
                ) {
                    toggleTagAssignment(tag.id)
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

    private var filteredAssignableTags: [UserTag] {
        store.userTags.filter {
            tagSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                $0.name.localizedCaseInsensitiveContains(tagSearchQuery)
        }.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private var canCreateSearchedTag: Bool {
        guard let candidate = UserTagPolicy.normalize(tagSearchQuery) else { return false }
        return !store.userTags.contains { $0.normalizedName == candidate.normalizedName }
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

    private func createAndAssignTag(from rawName: String) {
        guard let tag = store.createUserTag(name: rawName) else {
            tagErrorMessage = "That tag name is invalid or already exists."
            return
        }
        tagSearchQuery = ""
        if selectedTagIDs.count < UserTagPolicy.maxTagsPerDhikr {
            selectedTagIDs.insert(tag.id)
        } else {
            tagErrorMessage = "Tag created. A dhikr can have at most \(UserTagPolicy.maxTagsPerDhikr) tags."
        }
    }

    private var filteredCategories: [DhikrCategory] {
        let query = categorySearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return DhikrCategory.allCases.filter {
            query.isEmpty || String(localized: String.LocalizationValue($0.title))
                .localizedCaseInsensitiveContains(query)
        }
    }

    private func toggleCategory(_ option: DhikrCategory) {
        if let index = selectedCategories.firstIndex(of: option) {
            guard selectedCategories.count > 1 else { return }
            selectedCategories.remove(at: index)
        } else {
            selectedCategories.append(option)
        }
    }

    private func presentSelector(afterClosingOptional selector: Binding<Bool>) {
        isOptionalDetailsPresented = false
        Task { @MainActor in
            await Task.yield()
            selector.wrappedValue = true
        }
    }

    private func reopenOptionalDetails() {
        guard !isCategorySelectorPresented, !isTagSelectorPresented else { return }
        isOptionalDetailsPresented = true
    }

    private func selectorLauncher(
        title: LocalizedStringKey,
        summary: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .foregroundStyle(AwradTheme.sage)
                    .frame(width: 42, height: 42)
                    .background(AwradTheme.mint.opacity(0.28), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                        .foregroundStyle(AwradTheme.ink)
                    Text(summary)
                        .font(AwradTheme.bodyFont(.caption))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.forward")
                    .foregroundStyle(.secondary)
            }
            .padding(15)
            .background(AwradTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AwradTheme.outline, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func searchableSelectorSheet<Content: View>(
        title: LocalizedStringKey,
        searchPrompt: LocalizedStringKey,
        searchText: Binding<String>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    TextField(searchPrompt, text: searchText)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .padding(.bottom, 4)
                    content()
                }
                .padding(20)
                .padding(.bottom, 24)
            }
            .background(AwradTheme.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isCategorySelectorPresented = false
                        isTagSelectorPresented = false
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func selectorRow(
        title: String,
        systemImage: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .frame(width: 24)
                    .foregroundStyle(AwradTheme.sage)
                Text(title)
                    .font(AwradTheme.bodyFont(.body, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(AwradTheme.ink)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AwradTheme.sage)
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 54)
            .background(
                isSelected ? AwradTheme.mint.opacity(0.32) : AwradTheme.surface,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
        }
        .buttonStyle(.plain)
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
        selectedCategories = dhikr.categories
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
                categories: selectedCategories,
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
                category: category,
                categories: selectedCategories
            )
            if let created = dhikr {
                _ = store.updateDhikr(
                    id: created.id,
                    title: created.title,
                    arabic: created.arabic,
                    transliteration: created.transliteration,
                    translation: created.translation,
                    category: created.category,
                    categories: created.categories,
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
    var isRequired = false

    init(
        title: String,
        placeholder: String,
        text: Binding<String>,
        axis: Axis = .horizontal,
        font: Font = .body,
        lineLimit: ClosedRange<Int>? = nil,
        textAlignment: TextAlignment = .leading,
        isRequired: Bool = false
    ) {
        self.title = title
        self.placeholder = placeholder
        self._text = text
        self.axis = axis
        self.font = font
        self.closedLineLimit = lineLimit
        self.textAlignment = textAlignment
        self.isRequired = isRequired
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(LocalizedStringKey(title))
                    .font(AwradTheme.bodyFont(.caption, weight: .semibold))
                    .foregroundStyle(.secondary)
                if isRequired {
                    Text("Required")
                        .font(AwradTheme.bodyFont(.caption2, weight: .semibold))
                        .foregroundStyle(AwradTheme.sage)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(AwradTheme.mint.opacity(0.28), in: Capsule())
                }
            }

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
