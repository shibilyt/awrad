import SwiftUI

struct CreateDhikrView: View {
    @Environment(AwradStore.self) private var store
    @Environment(AppRouter.self) private var router
    let editingDhikrID: AwradID?
    @State private var title = ""
    @State private var arabic = ""
    @State private var transliteration = ""
    @State private var translation = ""
    @State private var category: DhikrCategory = .general
    @State private var didHydrate = false

    init(editingDhikrID: AwradID? = nil) {
        self.editingDhikrID = editingDhikrID
    }

    private var canSave: Bool {
        !arabic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isEditing: Bool {
        editingDhikrID != nil
    }

    private var saveTitle: LocalizedStringKey {
        isEditing ? "Save Dhikr" : "Create Dhikr"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                textFields
                categoryPicker
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
        didHydrate = true
    }

    private func save() {
        if let editingDhikrID {
            guard let dhikr = store.updateDhikr(
                id: editingDhikrID,
                title: title,
                arabic: arabic,
                transliteration: transliteration,
                translation: translation,
                category: category
            ) else {
                return
            }
            router.replaceLast(with: .dhikrDetail(dhikr.id), in: store.selectedTab)
            return
        }

        guard let dhikr = store.createDhikr(
            title: title,
            arabic: arabic,
            transliteration: transliteration,
            translation: translation,
            category: category
        ) else {
            return
        }
        router.replaceLast(with: .dhikrDetail(dhikr.id), in: store.selectedTab)
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
