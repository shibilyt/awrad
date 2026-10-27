import SwiftUI

// The elevations themselves are generated into AwradElevation.swift by
// scripts/generate-design-tokens.py.

/// A shadow from shape.json `elevation`, in SwiftUI's terms: `radius` is half the contract's blur.
/// Its colour is a colour role (`shadow`), clear in dark mode, so dark mode draws no shadow.
public struct AwradShadow: Sendable {
    public let color: Color
    public let radius: CGFloat
    public let x: CGFloat
    public let y: CGFloat
}

extension View {
    /// Casts an elevation's shadow: `.awradElevation(AwradElevation.floating)` under the bottom bar.
    public func awradElevation(_ elevation: AwradShadow) -> some View {
        shadow(color: elevation.color, radius: elevation.radius, x: elevation.x, y: elevation.y)
    }
}
