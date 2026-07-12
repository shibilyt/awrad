import SwiftUI

/// A select control that presents its options in a bottom sheet instead of a
/// system menu/popup. Reusable across the app (Settings, goal creation, etc.).
///
/// The row shows the current selection; tapping opens a sheet listing every
/// option with a checkmark on the active one. `displayName` returns a string
/// rendered through `LocalizedStringKey`. Provide `description` to show a short
/// explanation under each option in the sheet (helps demystify jargon choices).
struct AwradBottomSheetPicker<Value: Hashable & Identifiable>: View {
    let title: LocalizedStringKey
    @Binding var selection: Value
    let options: [Value]
    var description: ((Value) -> String)? = nil
    let displayName: (Value) -> String

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack(spacing: 12) {
                Text(title)
                    .foregroundStyle(AwradTheme.ink)
                Spacer(minLength: 8)
                Text(LocalizedStringKey(displayName(selection)))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Image(systemName: "chevron.up.chevron.down")
                    .font(AwradTheme.bodyFont(.caption, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isPresented) {
            AwradBottomSheetPickerList(
                title: title,
                selection: $selection,
                options: options,
                description: description,
                displayName: displayName
            )
        }
    }
}

private struct AwradBottomSheetPickerList<Value: Hashable & Identifiable>: View {
    @Environment(\.dismiss) private var dismiss
    let title: LocalizedStringKey
    @Binding var selection: Value
    let options: [Value]
    let description: ((Value) -> String)?
    let displayName: (Value) -> String

    var body: some View {
        NavigationStack {
            List {
                ForEach(options) { option in
                    Button {
                        selection = option
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(LocalizedStringKey(displayName(option)))
                                    .font(AwradTheme.bodyFont(.body, weight: .medium))
                                    .foregroundStyle(AwradTheme.ink)
                                if let description, !description(option).isEmpty {
                                    Text(LocalizedStringKey(description(option)))
                                        .font(AwradTheme.bodyFont(.caption))
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            Spacer(minLength: 8)
                            if option == selection {
                                Image(systemName: "checkmark")
                                    .font(AwradTheme.bodyFont(.body, weight: .semibold))
                                    .foregroundStyle(AwradTheme.sage)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
