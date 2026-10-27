import SwiftUI

// The radii and roles themselves are generated into AwradRadius.swift by
// scripts/generate-design-tokens.py. Every corner is continuous (a squircle), as the contract asks.

/// A shape role's corner: a radius on the scale, or fully rounded (a capsule).
nonisolated public enum AwradCorner: Sendable, Hashable {
    case radius(CGFloat)
    case full

    /// The radius, or `nil` when fully rounded (it then depends on the height).
    public var fixedRadius: CGFloat? {
        switch self {
        case .radius(let radius): radius
        case .full: nil
        }
    }

    /// The filled shape with this corner, continuous.
    public var shape: AwradShape { AwradShape(corner: self) }
}

/// A rectangle with continuous corners: a `RoundedRectangle(cornerRadius:style: .continuous)`, or a
/// continuous capsule for a fully rounded corner. Use it through a role: `AwradRadius.card.shape`.
nonisolated public struct AwradShape: InsettableShape {
    public let corner: AwradCorner
    private var inset: CGFloat = 0

    public init(corner: AwradCorner) {
        self.corner = corner
    }

    /// A shape with a radius from the scale (`AwradRadius.md`), for the few places without a role.
    public init(radius: CGFloat) {
        self.init(corner: .radius(radius))
    }

    public func path(in rect: CGRect) -> Path {
        let rect = rect.insetBy(dx: inset, dy: inset)
        switch corner {
        case .radius(let radius):
            return RoundedRectangle(cornerRadius: max(0, radius - inset), style: .continuous).path(in: rect)
        case .full:
            return Capsule(style: .continuous).path(in: rect)
        }
    }

    public func inset(by amount: CGFloat) -> AwradShape {
        var shape = self
        shape.inset += amount
        return shape
    }
}

extension View {
    /// Clips to a role's continuous shape: `.awradClip(AwradRadius.button)`.
    public func awradClip(_ corner: AwradCorner) -> some View {
        clipShape(corner.shape)
    }

    /// On a sheet's content: the `sheet` corner radius. iOS keeps the native sheet, which follows the
    /// finger and settles itself (the contract's `sheet` motion is Android's).
    public func awradSheet() -> some View {
        presentationCornerRadius(AwradRadius.sheet.fixedRadius)
    }
}
