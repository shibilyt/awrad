import SwiftUI
import Testing

@testable import AwradDesignSystem

/// The generated elevations match shape.json `elevation`: SwiftUI's radius is half the blur, the
/// colour is the named role, and dark mode draws no shadow.
struct AwradElevationTests {
    @Test func everyElevationMatchesShapeJSON() throws {
        let elevation = try DesignTokenContract.object(DesignTokenContract.json("shape")["elevation"], "elevation")
        var numbers: [String: Double] = [:]
        var colors: [String: String] = [:]
        for (name, spec) in elevation {
            let shadow = try DesignTokenContract.object(spec, name)
            numbers["\(name).y"] = try DesignTokenContract.number(shadow["y"], "\(name).y")
            numbers["\(name).blur"] = try DesignTokenContract.number(shadow["blur"], "\(name).blur")
            colors["\(name).color"] = try DesignTokenContract.string(shadow["color"], "\(name).color")
        }
        #expect(DesignTokenContract.dictionary(AwradElevation.numbers) == numbers)
        #expect(DesignTokenContract.dictionary(AwradElevation.colors) == colors)
    }

    @Test func floatingIsTheShadowRoleWithHalfTheBlur() {
        #expect(AwradElevation.floating.radius == 8)
        #expect(AwradElevation.floating.y == 4)
        #expect(AwradElevation.floating.x == 0)
        #expect(Self.resolved(AwradElevation.floating.color, .light) == Self.resolved(AwradColors.shadow, .light))
    }

    @Test func darkModeHasNoShadow() {
        #expect(Self.resolved(AwradElevation.floating.color, .dark).opacity == 0)
        #expect(Self.resolved(AwradElevation.floating.color, .light).opacity > 0)
    }

    private static func resolved(_ color: Color, _ scheme: ColorScheme) -> Color.Resolved {
        var environment = EnvironmentValues()
        environment.colorScheme = scheme
        return color.resolve(in: environment)
    }
}
