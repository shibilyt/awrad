import SwiftUI
import Testing

@testable import AwradDesignSystem

/// The no-outlines fill rule (contracts/design-tokens/v1/README.md): a control is filled with
/// `surface` on a `background` and with `background` on a `surface` card.
struct AwradContainerTests {
    private static func resolved(_ color: Color, _ scheme: ColorScheme) -> Color.Resolved {
        var environment = EnvironmentValues()
        environment.colorScheme = scheme
        return color.resolve(in: environment)
    }

    @Test func aScreenIsABackgroundUntilACardSaysOtherwise() {
        #expect(EnvironmentValues().awradContainer == .background)
    }

    @Test(arguments: [ColorScheme.light, .dark])
    func controlsAreFilledWithTheOtherSurface(scheme: ColorScheme) {
        #expect(
            Self.resolved(AwradContainer.background.controlFill, scheme) == Self.resolved(AwradColors.surface, scheme))
        #expect(
            Self.resolved(AwradContainer.surface.controlFill, scheme) == Self.resolved(AwradColors.background, scheme))
    }
}
