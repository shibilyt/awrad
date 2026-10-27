import SwiftUI

/// A checkbox: a `checkbox` (20) box in the `checkbox` shape followed by its `body` label, `md` apart,
/// the whole row at least `touchTarget` tall. Unticked, the box is the `checkbox` stroke in
/// `outlineStrong`; ticked, a `primary` fill with an `onPrimary` tick that draws in with `spatial`.
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
            // The tick draws in; with reduced motion it fades in whole.
            TickShape()
                .trim(from: 0, to: isOn || motion.reduceMotion ? 1 : 0)
                .stroke(
                    AwradColors.onPrimary,
                    style: StrokeStyle(lineWidth: AwradStroke.checkbox, lineCap: .round, lineJoin: .round)
                )
                .opacity(isOn ? 1 : 0)
                .padding(AwradSpacing.xs)
                .animation(motion.animation(AwradMotion.Spring.spatial), value: isOn)
        }
        .frame(width: AwradSize.checkbox, height: AwradSize.checkbox)
        .awradSelectColors(value: isOn)
    }
}

/// A tick from the lower start, down to the bottom, up to the top end, in a unit square.
private struct TickShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.55))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.maxY - rect.height * 0.1))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.12))
        }
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
