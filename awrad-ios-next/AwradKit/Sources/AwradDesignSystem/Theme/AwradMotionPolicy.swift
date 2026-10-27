import SwiftUI

// The motion values themselves are generated into AwradMotion.swift by
// scripts/generate-design-tokens.py; the helpers that use them are in AwradMotion+Helpers.swift.

/// A cubic-bézier easing (motion.json `easing`): two control points.
nonisolated public struct AwradCurve: Sendable, Hashable {
    public let x1: Double
    public let y1: Double
    public let x2: Double
    public let y2: Double

    public init(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) {
        self.x1 = x1
        self.y1 = y1
        self.x2 = x2
        self.y2 = y2
    }

    /// This easing over `duration` seconds.
    public func animation(duration: TimeInterval) -> Animation {
        .timingCurve(x1, y1, x2, y2, duration: duration)
    }
}

/// A spring (motion.json `spring`), already converted for SwiftUI: response = 2π / √stiffness and
/// dampingFraction = dampingRatio, with mass 1.
nonisolated public struct AwradSpring: Sendable, Hashable {
    public let response: Double
    public let dampingFraction: Double

    /// The spring as an animation.
    public var animation: Animation {
        .spring(response: response, dampingFraction: dampingFraction)
    }

    /// The spring for keyframes (`SpringKeyframe`).
    public var spring: Spring {
        Spring(response: response, dampingRatio: dampingFraction)
    }
}

/// How motion plays here: as designed, or, when the system asks for reduced motion, every
/// movement, scale and spring as the `reducedMotion` cross-fade. Haptics stay either way.
///
/// Screens read it from the environment (`@Environment(\.awradMotion)`) and pass their animation
/// through it, so no screen branches on reduced motion itself.
nonisolated public struct AwradMotionPolicy: Sendable, Equatable {
    public let reduceMotion: Bool

    public init(reduceMotion: Bool) {
        self.reduceMotion = reduceMotion
    }

    /// The reduced-motion replacement: a cross-fade over `reducedMotion.duration` on its easing (linear).
    public static let crossFade = AwradMotion.ReducedMotion.easing.animation(
        duration: AwradMotion.ReducedMotion.duration)

    /// A movement's animation, or the cross-fade when motion is reduced.
    public func animation(_ animation: Animation) -> Animation {
        reduceMotion ? Self.crossFade : animation
    }

    /// A spring's animation, or the cross-fade when motion is reduced.
    public func animation(_ spring: AwradSpring) -> Animation {
        animation(spring.animation)
    }

    /// A scale to animate to: itself, or 1 (no scaling) when motion is reduced.
    public func scale(_ scale: CGFloat) -> CGFloat {
        reduceMotion ? 1 : scale
    }

    /// An offset to animate from: itself, or 0 (no movement) when motion is reduced.
    public func offset(_ offset: CGFloat) -> CGFloat {
        reduceMotion ? 0 : offset
    }

    /// A transition: itself, or a plain fade when motion is reduced.
    @MainActor public func transition(_ transition: AnyTransition) -> AnyTransition {
        reduceMotion ? .opacity : transition
    }

    /// Runs `body` inside `withAnimation`, with the animation (or the cross-fade) this policy allows.
    /// Change animated values here, such as a count, so a `contentTransition` animates.
    @MainActor public func animate<Result>(_ animation: Animation, _ body: () throws -> Result) rethrows -> Result {
        try withAnimation(self.animation(animation), body)
    }
}

extension EnvironmentValues {
    /// The motion policy for the views here, from the system's reduce-motion setting.
    nonisolated public var awradMotion: AwradMotionPolicy {
        AwradMotionPolicy(reduceMotion: accessibilityReduceMotion)
    }
}
