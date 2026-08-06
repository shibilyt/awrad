import SwiftUI

struct ManageTagsView: View {
    @Environment(AwradStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let dhikrID: AwradID

    @State private var newTagName = ""
    @State private var renamingTagID: AwradID?
    @State private var renameText = ""
    @State private var tagPendingDeletion: UserTag?
    @State private var errorMessage: String?

    private var dhikr: Dhikr? { store.dhikr(id: dhikrID) }

    private var assignedTagIDs: Set<AwradID> {
        Set(store.tagAssignments.filter { $0.dhikrID == dhikrID }.map(\.tagID))
    }

    private var sortedTags: [UserTag] {
        store.userTags.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(dhikr?.title ?? "Dhikr")
                        .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                        .foregroundStyle(AwradTheme.ink)
                        .accessibilityLabel("Managing tags for \(dhikr?.title ?? "dhikr")")
                }

                Section("Assigned tags") {
                    if assignedTagIDs.isEmpty {
                        Text("No tags assigned yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(sortedTags.filter { assignedTagIDs.contains($0.id) }) { tag in
                            tagRow(tag, assigned: true)
                        }
                    }
                }

                Section("All tags") {
                    ForEach(sortedTags) { tag in
                        tagRow(tag, assigned: assignedTagIDs.contains(tag.id))
                    }

                    HStack {
                        TextField("New tag", text: $newTagName)
                            .textInputAutocapitalization(.words)
                            .accessibilityLabel("New tag name")
                        Button("Add") {
                            createTag()
                        }
                        .disabled(UserTagPolicy.normalize(newTagName) == nil)
                        .accessibilityLabel("Create tag")
                    }
                }
            }
            .navigationTitle("Manage tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .accessibilityLabel("Done")
                }
            }
            .alert("Rename tag", isPresented: renamePresented) {
                TextField("Tag name", text: $renameText)
                Button("Save") { commitRename() }
                Button("Cancel", role: .cancel) {
                    renamingTagID = nil
                    renameText = ""
                }
            }
            .confirmationDialog(
                "Delete tag?",
                isPresented: deletePresented,
                titleVisibility: .visible,
                presenting: tagPendingDeletion
            ) { tag in
                Button("Delete Tag", role: .destructive) {
                    _ = store.deleteUserTag(tag.id)
                    tagPendingDeletion = nil
                }
                Button("Cancel", role: .cancel) {
                    tagPendingDeletion = nil
                }
            } message: { tag in
                Text("\"\(tag.name)\" will be removed from every dhikr. Dhikrs themselves stay.")
            }
            .alert("Could not update tags", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private func tagRow(_ tag: UserTag, assigned: Bool) -> some View {
        HStack(spacing: 12) {
            Button {
                toggleAssignment(tag)
            } label: {
                Label(tag.name, systemImage: assigned ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(assigned ? AwradTheme.sage : AwradTheme.ink)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(tag.name)
            .accessibilityValue(assigned ? "Assigned" : "Not assigned")
            .accessibilityHint(assigned ? "Removes this tag from the dhikr" : "Assigns this tag to the dhikr")

            Spacer(minLength: 8)

            Button {
                renamingTagID = tag.id
                renameText = tag.name
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Rename \(tag.name)")

            Button(role: .destructive) {
                tagPendingDeletion = tag
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Delete \(tag.name)")
        }
        .frame(minHeight: 44)
    }

    private var renamePresented: Binding<Bool> {
        Binding(
            get: { renamingTagID != nil },
            set: { if !$0 { renamingTagID = nil } }
        )
    }

    private var deletePresented: Binding<Bool> {
        Binding(
            get: { tagPendingDeletion != nil },
            set: { if !$0 { tagPendingDeletion = nil } }
        )
    }

    private func createTag() {
        guard let tag = store.createUserTag(name: newTagName) else {
            errorMessage = "That tag name is invalid or already exists."
            return
        }
        newTagName = ""
        if assignedTagIDs.count < UserTagPolicy.maxTagsPerDhikr {
            _ = store.assignTag(tag.id, to: dhikrID)
        }
    }

    private func toggleAssignment(_ tag: UserTag) {
        if assignedTagIDs.contains(tag.id) {
            _ = store.unassignTag(tag.id, from: dhikrID)
        } else if assignedTagIDs.count >= UserTagPolicy.maxTagsPerDhikr {
            errorMessage = "A dhikr can have at most \(UserTagPolicy.maxTagsPerDhikr) tags."
        } else if store.assignTag(tag.id, to: dhikrID) == nil {
            errorMessage = "Could not assign that tag."
        }
    }

    private func commitRename() {
        guard let renamingTagID else { return }
        if store.renameUserTag(id: renamingTagID, name: renameText) == nil {
            errorMessage = "That tag name is invalid or already exists."
        }
        self.renamingTagID = nil
        renameText = ""
    }
}
