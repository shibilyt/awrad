import SwiftUI

/// The top bar: `topBar` (56) tall, `pageMargin` from the screen edges, no fill and no divider. An
/// optional back button at the start, an optional middle (a title or the step indicator), and up to
/// two icon buttons or a text button at the end. It mirrors in right-to-left.
public struct AwradTopBar<Middle: View, Trailing: View>: View {
    private let onBack: (() -> Void)?
    private let middle: Middle
    private let trailing: Trailing

    public init(
        onBack: (() -> Void)? = nil, @ViewBuilder middle: () -> Middle, @ViewBuilder trailing: () -> Trailing
    ) {
        self.onBack = onBack
        self.middle = middle()
        self.trailing = trailing()
    }

    public var body: some View {
        ZStack {
            middle
                // Clear of a back button and up to two end buttons.
                .padding(.horizontal, AwradSize.touchTarget * 2)
            HStack(spacing: AwradSpacing.none) {
                if let onBack {
                    AwradIconButton.back(action: onBack)
                }
                Spacer(minLength: AwradSpacing.none)
                HStack(spacing: AwradSpacing.none) { trailing }
            }
        }
        .frame(maxWidth: .infinity, minHeight: AwradSize.topBar)
        .padding(.horizontal, AwradSpacing.pageMargin)
    }
}

extension AwradTopBar where Trailing == EmptyView {
    public init(onBack: (() -> Void)? = nil, @ViewBuilder middle: () -> Middle) {
        self.init(onBack: onBack, middle: middle) { EmptyView() }
    }
}

extension AwradTopBar where Middle == AwradTopBarTitle {
    /// A top bar with a `title`-style title in the middle.
    public init(
        _ title: LocalizedStringResource, onBack: (() -> Void)? = nil, @ViewBuilder trailing: () -> Trailing
    ) {
        self.init(onBack: onBack, middle: { AwradTopBarTitle(title) }, trailing: trailing)
    }
}

extension AwradTopBar where Middle == AwradTopBarTitle, Trailing == EmptyView {
    public init(_ title: LocalizedStringResource, onBack: (() -> Void)? = nil) {
        self.init(onBack: onBack, middle: { AwradTopBarTitle(title) }, trailing: { EmptyView() })
    }
}

/// A top bar's title: `title` style, `onSurface`, one line, a header for VoiceOver.
public struct AwradTopBarTitle: View {
    private let title: LocalizedStringResource

    public init(_ title: LocalizedStringResource) {
        self.title = title
    }

    public var body: some View {
        Text(title)
            .awradTextStyle(.title)
            .foregroundStyle(AwradColors.onSurface)
            .lineLimit(1)
            .accessibilityAddTraits(.isHeader)
    }
}

/// The position in a fixed flow (onboarding): `stepDot` squares `xs` apart, `onSurface` up to and
/// including the current step, `outline` ahead. Read as one element, "Step 2 of 7". It mirrors in
/// right-to-left.
public struct AwradStepIndicator: View {
    /// The current step, from 1.
    public let current: Int
    public let total: Int

    /// `current` is clamped to `1...total`; `total` is at least 1.
    public init(current: Int, total: Int) {
        self.total = max(1, total)
        self.current = min(max(1, current), self.total)
    }

    /// Whether `step` (from 1) is done or current, so it's filled.
    public func isReached(_ step: Int) -> Bool {
        step <= current
    }

    /// What VoiceOver reads: "Step 2 of 7".
    public var accessibilityLabel: LocalizedStringResource {
        AwradStrings.step(current, of: total)
    }

    public var body: some View {
        HStack(spacing: AwradSpacing.xs) {
            ForEach(1...total, id: \.self) { step in
                AwradRadius.stepDot.shape
                    .fill(isReached(step) ? AwradColors.onSurface : AwradColors.outline)
                    .frame(width: AwradSize.stepDot, height: AwradSize.stepDot)
            }
        }
        .awradSelectColors(value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityLabel))
    }
}

/// The top of a main tab (My Goals) outside a `NavigationStack`: the title in `largeTitle` at the
/// start and an optional action (a round button) at the end, aligned with it. The content sheet or
/// segmented pills follow `lg` below. In a `NavigationStack`, use the native large title instead
/// (`awradLargeTitle(_:)`), which scrolls away into a compact bar.
public struct AwradLargeTitleHeader<Action: View>: View {
    private let title: LocalizedStringResource
    private let action: Action

    public init(_ title: LocalizedStringResource, @ViewBuilder action: () -> Action) {
        self.title = title
        self.action = action()
    }

    public var body: some View {
        HStack(alignment: .center, spacing: AwradSpacing.md) {
            Text(title)
                .awradTextStyle(.largeTitle)
                .foregroundStyle(AwradColors.onSurface)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
            action
        }
        .padding(.horizontal, AwradSpacing.pageMargin)
    }
}

extension AwradLargeTitleHeader where Action == EmptyView {
    public init(_ title: LocalizedStringResource) {
        self.init(title) { EmptyView() }
    }
}

extension View {
    /// The native large title on a screen in a `NavigationStack` (the spec's iOS large-title
    /// header): it scrolls away into the compact bar. Put the + in the toolbar.
    public func awradLargeTitle(_ title: LocalizedStringResource) -> some View {
        modifier(LargeTitle(title: title))
    }
}

private struct LargeTitle: ViewModifier {
    let title: LocalizedStringResource

    func body(content: Content) -> some View {
        #if os(iOS)
            content
                .navigationTitle(Text(title))
                .navigationBarTitleDisplayMode(.large)
        #else
            content.navigationTitle(Text(title))
        #endif
    }
}

private func previewNoAction() {}

#Preview("Top bars") {
    VStack(spacing: AwradSpacing.lg) {
        AwradTopBar("Settings", onBack: previewNoAction) { AwradIconButton.more {} }
        AwradTopBar(onBack: previewNoAction) { AwradStepIndicator(current: 2, total: 7) }
        AwradLargeTitleHeader("My Goals") { AwradRoundButton(systemImage: "plus", label: "Add") {} }
    }
    .background(AwradColors.background)
}
