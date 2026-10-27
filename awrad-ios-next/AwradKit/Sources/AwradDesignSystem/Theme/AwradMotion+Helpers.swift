import SwiftUI

// Ready-made named motions (motion.json `motions`). Each reads `awradMotion` from the environment,
// so reduced motion turns movement into the cross-fade without the screen branching. Page pushes
// stay the native NavigationStack push.

extension AwradMotion.Press {
    /// Pressing down: `pressDuration` on `pressEasing`.
    public static var pressIn: Animation { pressEasing.animation(duration: pressDuration) }
}

extension AwradMotion.ContentSwap {
    /// The old content fades out over `fadeOut`, the new fades in over `fadeIn`, both on `easing`
    /// (linear: a fade has nothing to accelerate).
    @MainActor public static var transition: AnyTransition {
        .asymmetric(
            insertion: .opacity.animation(easing.animation(duration: fadeIn)),
            removal: .opacity.animation(easing.animation(duration: fadeOut)))
    }
}

// MARK: - Press

/// Press feedback for cards and buttons: scales down while pressed (`press.cardScale` or
/// `press.buttonScale`) and springs back with `spatialFast`. Draws nothing else: the label keeps
/// its own fill.
public struct AwradPressStyle: ButtonStyle {
    public enum Kind: Sendable {
        case card
        case button

        var scale: CGFloat {
            switch self {
            case .card: AwradMotion.Press.cardScale
            case .button: AwradMotion.Press.buttonScale
            }
        }
    }

    let kind: Kind

    public init(_ kind: Kind) {
        self.kind = kind
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label.awradPressed(configuration.isPressed, kind: kind)
    }
}

extension ButtonStyle where Self == AwradPressStyle {
    /// A card or button that presses in: `.buttonStyle(.awradPress(.card))`.
    public static func awradPress(_ kind: AwradPressStyle.Kind) -> AwradPressStyle {
        AwradPressStyle(kind)
    }
}

extension View {
    /// The press feedback for a view that tracks its own pressed state, such as a custom ButtonStyle.
    public func awradPressed(_ isPressed: Bool, kind: AwradPressStyle.Kind) -> some View {
        modifier(PressModifier(isPressed: isPressed, scale: kind.scale))
    }
}

private struct PressModifier: ViewModifier {
    let isPressed: Bool
    let scale: CGFloat
    @Environment(\.awradMotion) private var motion

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? motion.scale(scale) : 1)
            .animation(
                isPressed ? AwradMotion.Press.pressIn : AwradMotion.Press.releaseSpring.animation, value: isPressed)
    }
}

// MARK: - Haptics

extension View {
    /// Plays a haptic (`tick`, `threshold`, `success`) when `trigger` changes. Haptics stay when
    /// motion is reduced.
    public func awradHaptic<Trigger: Equatable>(_ haptic: AwradHaptic, trigger: Trigger) -> some View {
        sensoryFeedback(haptic.feedback, trigger: trigger)
    }

    /// Plays a haptic when `trigger` changes and `condition(old, new)` holds, such as reaching a target.
    public func awradHaptic<Trigger: Equatable>(
        _ haptic: AwradHaptic, trigger: Trigger, condition: @escaping (Trigger, Trigger) -> Bool
    ) -> some View {
        sensoryFeedback(haptic.feedback, trigger: trigger, condition: condition)
    }
}

// MARK: - Named motions

extension View {
    /// `navPill`, on the selected tab's pill: it grows in from `pillScaleFrom` with `bouncySoft`
    /// and fades out when the tab is deselected.
    public func awradNavPill(isSelected: Bool) -> some View {
        modifier(NavPillModifier(isSelected: isSelected))
    }

    /// `navPill`, on a tab's icon: a `bouncy` pop to `iconScale` when the tab becomes selected.
    public func awradNavIcon(isSelected: Bool) -> some View {
        modifier(
            PopModifier(
                scale: AwradMotion.NavPill.iconScale, spring: AwradMotion.NavPill.iconSpring, trigger: isSelected))
    }

    /// `countTap`, on the counting number (`AwradTextStyle.counter`): the number rolls to its next
    /// value, pops to `popScale` with `bouncy`, and ticks. Change `value` inside
    /// `motion.animate(AwradMotion.CountTap.spring.animation) { … }` so the roll animates.
    public func awradCountTap(value: Int) -> some View {
        modifier(CountTapModifier(value: value))
    }

    /// `ringFill`, on a progress ring or bar: value changes animate with the `spatial` spring.
    public func awradRingFill<Value: Equatable>(value: Value) -> some View {
        modifier(SpringOnChange(spring: AwradMotion.RingFill.spring, value: value))
    }

    /// `expand`, on the container of a section that expands, collapses or changes size: the change
    /// animates with the `spatial` spring. Mark what appears with `awradExpandingContent()`.
    public func awradExpand<Value: Equatable>(value: Value) -> some View {
        modifier(SpringOnChange(spring: AwradMotion.Expand.sizeSpring, value: value))
    }

    /// `expand`, on content that appears or leaves inside an `awradExpand` container: it fades with
    /// the `effects` spring while the container resizes.
    public func awradExpandingContent() -> some View {
        modifier(ExpandingContentModifier())
    }

    /// `expand`, on a section's chevron: it turns by `chevronRotation` when expanded.
    public func awradChevron(isExpanded: Bool) -> some View {
        modifier(ChevronModifier(isExpanded: isExpanded))
    }

    /// `listAppear`, on the item at `index` of a list: it rises `offset` and fades in over `short`,
    /// decelerating, staggered by `stagger` for the first `maxStaggered` items.
    public func awradListAppear(index: Int) -> some View {
        modifier(ListAppearModifier(index: index))
    }

    /// `contentSwap`, on content swapped in place by `value` (a `switch` or `if`): the old fades out
    /// over `fade`, the new fades in over `color`. Already a fade, so it's the same with reduced motion.
    public func awradContentSwap<Value: Equatable>(value: Value) -> some View {
        ZStack { transition(AwradMotion.ContentSwap.transition) }
            .animation(
                AwradMotion.ContentSwap.easing.animation(duration: AwradMotion.ContentSwap.fadeIn), value: value)
    }
}

private struct NavPillModifier: ViewModifier {
    let isSelected: Bool
    @Environment(\.awradMotion) private var motion

    func body(content: Content) -> some View {
        content
            .scaleEffect(isSelected ? 1 : motion.scale(AwradMotion.NavPill.pillScaleFrom))
            .opacity(isSelected ? 1 : 0)
            .animation(motion.animation(AwradMotion.NavPill.pillSpring), value: isSelected)
    }
}

/// A pop to `scale` and back, each leg a spring, whenever `trigger` changes. No pop with reduced motion.
private struct PopModifier<Trigger: Equatable & Sendable>: ViewModifier {
    let scale: CGFloat
    let spring: AwradSpring
    let trigger: Trigger
    @Environment(\.awradMotion) private var motion

    func body(content: Content) -> some View {
        let peak = motion.scale(scale)
        content.keyframeAnimator(initialValue: CGFloat(1), trigger: trigger) { view, value in
            view.scaleEffect(value)
        } keyframes: { _ in
            KeyframeTrack {
                // The rise is as quick as a press; the spring settles the way back.
                SpringKeyframe(peak, duration: AwradMotion.Press.pressDuration, spring: spring.spring)
                SpringKeyframe(1, spring: spring.spring)
            }
        }
    }
}

private struct CountTapModifier: ViewModifier {
    let value: Int
    @Environment(\.awradMotion) private var motion

    func body(content: Content) -> some View {
        content
            .contentTransition(motion.reduceMotion ? .opacity : .numericText(value: Double(value)))
            .modifier(
                PopModifier(scale: AwradMotion.CountTap.popScale, spring: AwradMotion.CountTap.spring, trigger: value)
            )
            .awradHaptic(AwradMotion.CountTap.haptic, trigger: value)
            .animation(motion.animation(AwradMotion.CountTap.spring), value: value)
    }
}

private struct SpringOnChange<Value: Equatable>: ViewModifier {
    let spring: AwradSpring
    let value: Value
    @Environment(\.awradMotion) private var motion

    func body(content: Content) -> some View {
        content.animation(motion.animation(spring), value: value)
    }
}

private struct ExpandingContentModifier: ViewModifier {
    @Environment(\.awradMotion) private var motion

    func body(content: Content) -> some View {
        content.transition(motion.transition(.opacity.animation(AwradMotion.Expand.fadeSpring.animation)))
    }
}

private struct ChevronModifier: ViewModifier {
    let isExpanded: Bool
    @Environment(\.awradMotion) private var motion

    func body(content: Content) -> some View {
        content
            .rotationEffect(isExpanded ? AwradMotion.Expand.chevronRotation : .zero)
            // A turn is movement: with reduced motion the chevron flips without turning.
            .animation(motion.reduceMotion ? nil : AwradMotion.Expand.sizeSpring.animation, value: isExpanded)
    }
}

private struct ListAppearModifier: ViewModifier {
    let index: Int
    @State private var isVisible = false
    @Environment(\.awradMotion) private var motion

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : motion.offset(AwradMotion.ListAppear.offset))
            .onAppear {
                let delay = Double(min(index, AwradMotion.ListAppear.maxStaggered)) * AwradMotion.ListAppear.stagger
                let rise = AwradMotion.ListAppear.easing.animation(duration: AwradMotion.ListAppear.duration)
                withAnimation(motion.animation(rise.delay(delay))) { isVisible = true }
            }
    }
}
