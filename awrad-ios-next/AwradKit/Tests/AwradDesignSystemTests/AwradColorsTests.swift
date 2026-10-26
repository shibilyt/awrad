import AwradTesting
import Foundation
import SwiftUI
import Testing

@testable import AwradDesignSystem

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

/// Checks the generated `AwradColors` against contracts/design-tokens/v1/colors.json at run time:
/// every role exists and resolves to its light and dark value, alpha included. The appearance
/// provider also has to work off the main thread, where UIKit and AppKit resolve dynamic colours.
struct AwradColorsTests {
    private struct Tokens: Decodable {
        let roles: [String: TokenRole]
    }

    private static func tokens() throws -> Tokens {
        let url = try FixtureLoader.contractsDirectory(holding: "design-tokens")
            .appending(path: "design-tokens/v1/colors.json")
        return try JSONDecoder().decode(Tokens.self, from: Data(contentsOf: url))
    }

    /// `#RRGGBB` or `#RRGGBBAA` as a resolved sRGB colour.
    private static func resolved(_ hex: String) throws -> Color.Resolved {
        let digits = hex.dropFirst()
        let value = try #require(UInt32(digits, radix: 16), "\(hex) isn't hex")
        let rgba = digits.count == 6 ? value << 8 | 0xFF : value
        func channel(_ shift: UInt32) -> Float { Float((rgba >> shift) & 0xFF) / 255 }
        return Color.Resolved(
            colorSpace: .sRGB, red: channel(24), green: channel(16), blue: channel(8), opacity: channel(0))
    }

    private static func environment(_ scheme: ColorScheme) -> EnvironmentValues {
        var environment = EnvironmentValues()
        environment.colorScheme = scheme
        return environment
    }

    private static func expectClose(_ actual: Color.Resolved, _ expected: Color.Resolved, _ label: String) {
        let pairs = [
            (actual.red, expected.red), (actual.green, expected.green), (actual.blue, expected.blue),
            (actual.opacity, expected.opacity),
        ]
        #expect(pairs.allSatisfy { abs($0 - $1) < 0.002 }, "\(label): \(actual) isn't \(expected)")
    }

    @Test func everyContractRoleIsAnAwradColor() throws {
        let contract = Set(try Self.tokens().roles.keys)
        let app = Set(AwradColors.roles.map(\.key))
        #expect(app == contract)
    }

    @Test(arguments: [ColorScheme.light, .dark])
    func everyRoleResolvesToItsContractValue(scheme: ColorScheme) throws {
        let roles = try Self.tokens().roles
        for (name, color) in AwradColors.roles {
            let role = try #require(roles[name], "\(name) isn't in the contract")
            let expected = try Self.resolved(scheme == .dark ? role.dark : role.light)
            Self.expectClose(color.resolve(in: Self.environment(scheme)), expected, "\(name), \(scheme)")
        }
    }

    /// Makes and resolves a dynamic colour on the concurrent executor, never the main actor, as
    /// UIKit and AppKit do while drawing. Returns sRGB components 0–255.
    @concurrent nonisolated private static func resolveOffMain(light: UInt32, dark: UInt32) async -> [Int] {
        let color = AwradColors.platformColor(light: light, dark: dark)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        #if canImport(UIKit)
            color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
                .getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        #else
            NSAppearance(named: .darkAqua)?.performAsCurrentDrawingAppearance {
                color.usingColorSpace(.sRGB)?.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            }
        #endif
        return [red, green, blue, alpha].map { Int(($0 * 255).rounded()) }
    }

    @Test func theAppearanceProviderRunsOffTheMainThreadAndKeepsAlpha() async {
        let components = await Self.resolveOffMain(light: 0x23553CFF, dark: 0xE3E5E380)
        #expect(components == [0xE3, 0xE5, 0xE3, 0x80])
    }
}

/// One role of colors.json: its light and dark value.
private struct TokenRole: Decodable {
    let light: String
    let dark: String
}
