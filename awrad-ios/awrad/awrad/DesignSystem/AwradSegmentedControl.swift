import SwiftUI

struct AwradSegmentedControl<Selection: Hashable, Label: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @Binding private var selection: Selection
    private let options: [Selection]
    private let label: (Selection) -> Label

    init(
        selection: Binding<Selection>,
        options: [Selection],
        @ViewBuilder label: @escaping (Selection) -> Label
    ) {
        _selection = selection
        self.options = options
        self.label = label
    }

    var body: some View {
        Group {
            if #available(iOS 26.0, *), !reduceTransparency {
                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        buttons(useGlass: true)
                    }
                }
            } else {
                HStack(spacing: 4) {
                    buttons(useGlass: false)
                }
                .padding(4)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(AwradTheme.sage.opacity(0.16), lineWidth: 1)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func buttons(useGlass: Bool) -> some View {
        ForEach(options, id: \.self) { option in
            let isSelected = selection == option
            Button {
                guard !isSelected else { return }
                if reduceMotion {
                    selection = option
                } else {
                    withAnimation(.snappy(duration: 0.28)) {
                        selection = option
                    }
                }
            } label: {
                label(option)
                    .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                    .foregroundStyle(isSelected ? AwradTheme.sage : .secondary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .background {
                if useGlass {
                    if #available(iOS 26.0, *) {
                        Color.clear
                            .glassEffect(
                                .regular
                                    .tint(
                                        isSelected
                                            ? AwradTheme.sage.opacity(0.28)
                                            : AwradTheme.surface.opacity(0.16)
                                    )
                                    .interactive(true),
                                in: .capsule
                            )
                    }
                } else if isSelected {
                    Capsule()
                        .fill(AwradTheme.sage.opacity(0.16))
                }
            }
        }
    }
}
