import SwiftUI

/// A checkbox: a `checkbox` (20) box in the `checkbox` shape followed by its `body` label, `md` apart,
/// the whole row at least `touchTarget` tall. Unticked, the box is the `checkbox` stroke in
/// `outlineStrong`; ticked, a `primary` fill with the `onPrimary` `check` icon, which draws in from
/// the start with `spatial`.
/// VoiceOver reads it as the native toggle, with its state.
public struct AwradCheckbox: View {
    private let label: LocalizedStringResource
    @Binding private var isOn: Bool

    public init(_ label: LocalizedStringResource, isOn: Binding<Bool>) {
        self.label = label
        _isOn = isOn
    }

    public var body: some View {
        Toggle(isOn: $isOn) { Text(label) }
            .toggleStyle(AwradCheckboxStyle())
    }
}

/// The checkbox look for any `Toggle`: `.toggleStyle(AwradCheckboxStyle())`.
public struct AwradCheckboxStyle: ToggleStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: AwradSpacing.md) {
                CheckboxBox(isOn: configuration.isOn)
                configuration.label
                    .awradTextStyle(.body)
                    .foregroundStyle(AwradColors.onSurface)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: AwradSize.touchTarget)
            .contentShape(Rectangle())
            .awradDisabledAppearance()
        }
        .buttonStyle(.awradPress(.card))
        // Read exactly as the native toggle: its label, "switch button", on or off.
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }
        }
    }
}

private struct CheckboxBox: View {
    let isOn: Bool
    @Environment(\.awradMotion) private var motion

    var body: some View {
        let shape = AwradRadius.checkbox.shape
        ZStack {
            shape.fill(isOn ? AwradColors.primary : .clear)
            shape.strokeBorder(AwradColors.outlineStrong, lineWidth: AwradStroke.checkbox)
                .opacity(isOn ? 0 : 1)
            // The tick draws in from the start; with reduced motion it fades in whole.
            AwradIconImage(.check, size: AwradSize.checkbox)
                .foregroundStyle(AwradColors.onPrimary)
                .mask(alignment: .leading) {
                    Rectangle()
                        .frame(width: isOn || motion.reduceMotion ? AwradSize.checkbox : AwradSpacing.none)
                }
                .opacity(isOn ? 1 : 0)
                .animation(motion.animation(AwradMotion.Spring.spatial), value: isOn)
        }
        .frame(width: AwradSize.checkbox, height: AwradSize.checkbox)
        .awradSelectColors(value: isOn)
    }
}

/// A switch: the native `Toggle`, tinted `primary`, because iOS users expect the system switch.
/// Its label is `body` in `onSurface`, the row at least `touchTarget` tall.
public struct AwradSwitch: View {
    private let label: LocalizedStringResource
    @Binding private var isOn: Bool

    public init(_ label: LocalizedStringResource, isOn: Binding<Bool>) {
        self.label = label
        _isOn = isOn
    }

    public var body: some View {
        Toggle(isOn: $isOn) {
            Text(label)
                .awradTextStyle(.body)
                .foregroundStyle(AwradColors.onSurface)
                // The native switch draws its own disabled look; the label matches the spec's.
                .awradDisabledAppearance()
        }
        .tint(AwradColors.primary)
        .frame(minHeight: AwradSize.touchTarget)
    }
}

#Preview("Checkbox and switch") {
    @Previewable @State var isOn = true
    VStack(spacing: AwradSpacing.sm) {
        AwradCheckbox("Remind me", isOn: $isOn)
        AwradCheckbox("Remind me later", isOn: .constant(false))
        AwradSwitch("Notifications", isOn: $isOn)
    }
    .padding(AwradSpacing.pageMargin)
    .background(AwradColors.background)
}
