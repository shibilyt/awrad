import SwiftUI

/// Two to four mutually exclusive views (Active / History) as `chip` pills, `touchTarget` tall and
/// `sm` apart. The selected one is `primary` with an `onPrimary` label and a `tabIndicator` bar
/// `xs` under it; the others are `secondaryContainer` (`background` on a surface, `secondaryFill`).
/// The fill and bar move to the new pill with
/// `segmentIndicator` (a cross-fade with reduced motion). VoiceOver reads them as tabs.
public struct AwradSegmentedPills<Value: Hashable>: View {
    public struct Option {
        public let value: Value
        public let title: LocalizedStringResource

        public init(_ value: Value, title: LocalizedStringResource) {
            self.value = value
            self.title = title
        }
    }

    @Binding private var selection: Value
    private let options: [Option]
    @Namespace private var namespace
    @Environment(\.awradMotion) private var motion
    @Environment(\.awradContainer) private var container

    public init(selection: Binding<Value>, options: [Option]) {
        _selection = selection
        self.options = options
    }

    public var body: some View {
        HStack(alignment: .top, spacing: AwradSpacing.sm) {
            ForEach(options, id: \.value) { option in
                pill(option, isSelected: option.value == selection)
            }
        }
        .animation(motion.animation(AwradMotion.SegmentIndicator.spring), value: selection)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isTabBar)
    }

    /// Selects `value` unless it's already selected.
    func select(_ value: Value) {
        guard value != selection else { return }
        selection = value
    }

    /// What VoiceOver reads beyond a tab's button: whether it's the selected one.
    static func traits(isSelected: Bool) -> AccessibilityTraits {
        isSelected ? .isSelected : []
    }

    private func pill(_ option: Option, isSelected: Bool) -> some View {
        Button {
            select(option.value)
        } label: {
            VStack(spacing: AwradSpacing.xs) {
                Text(option.title)
                    .awradTextStyle(.button)
                    .foregroundStyle(isSelected ? AwradColors.onPrimary : container.onSecondaryFill)
                    .padding(.horizontal, AwradSpacing.lg)
                    .frame(minHeight: AwradSize.touchTarget)
                    .background {
                        ZStack {
                            AwradRadius.chip.shape.fill(container.secondaryFill)
                            if isSelected {
                                AwradRadius.chip.shape.fill(AwradColors.primary)
                                    .moving(id: "fill", in: namespace, unless: motion.reduceMotion)
                            }
                        }
                    }
                ZStack {
                    if isSelected {
                        AwradRadius.tabIndicator.shape.fill(AwradColors.primary)
                            .moving(id: "bar", in: namespace, unless: motion.reduceMotion)
                    }
                }
                .frame(width: AwradSize.tabIndicatorWidth, height: AwradSize.tabIndicatorHeight)
            }
            .contentShape(Rectangle())
            .awradDisabledAppearance()
        }
        .buttonStyle(.awradPress(.button))
        .accessibilityAddTraits(Self.traits(isSelected: isSelected))
    }
}

extension View {
    /// Moves between places sharing `id` (`matchedGeometryEffect`); with reduced motion it doesn't
    /// move, so it cross-fades instead.
    @ViewBuilder fileprivate func moving(id: String, in namespace: Namespace.ID, unless reduced: Bool) -> some View {
        if reduced {
            transition(.opacity)
        } else {
            matchedGeometryEffect(id: id, in: namespace)
        }
    }
}

#Preview("Segmented pills") {
    @Previewable @State var selection = 0
    AwradSegmentedPills(
        selection: $selection, options: [.init(0, title: "Active"), .init(1, title: "History")]
    )
    .padding(AwradSpacing.pageMargin)
    .background(AwradColors.background)
}
