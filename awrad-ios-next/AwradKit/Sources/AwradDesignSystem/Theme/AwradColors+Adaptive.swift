import SwiftUI

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

// The roles themselves are generated into AwradColors.swift by scripts/generate-colors.py.
extension AwradColors {
    /// A colour that follows the system appearance. `light` and `dark` are `0xRRGGBBAA` in sRGB.
    static func adaptive(light: UInt32, dark: UInt32) -> Color {
        #if canImport(UIKit)
            Color(uiColor: platformColor(light: light, dark: dark))
        #else
            Color(nsColor: platformColor(light: light, dark: dark))
        #endif
    }

    // The provider closures are `@Sendable` and only pick between colours made up front: UIKit,
    // AppKit and SwiftUI resolve dynamic colours off the main thread, so a closure inferred as
    // main-actor isolated (this module's default) traps at runtime.
    #if canImport(UIKit)
        nonisolated static func platformColor(light: UInt32, dark: UInt32) -> UIColor {
            let lightColor = UIColor(rgba: light)
            let darkColor = UIColor(rgba: dark)
            return UIColor { @Sendable traits in
                traits.userInterfaceStyle == .dark ? darkColor : lightColor
            }
        }
    #else
        nonisolated static func platformColor(light: UInt32, dark: UInt32) -> NSColor {
            let lightColor = NSColor(rgba: light)
            let darkColor = NSColor(rgba: dark)
            return NSColor(name: nil) { @Sendable appearance in
                appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? darkColor : lightColor
            }
        }
    #endif
}

#if canImport(UIKit)
    private extension UIColor {
        nonisolated convenience init(rgba: UInt32) {
            self.init(
                red: CGFloat((rgba >> 24) & 0xFF) / 255,
                green: CGFloat((rgba >> 16) & 0xFF) / 255,
                blue: CGFloat((rgba >> 8) & 0xFF) / 255,
                alpha: CGFloat(rgba & 0xFF) / 255
            )
        }
    }
#else
    private extension NSColor {
        nonisolated convenience init(rgba: UInt32) {
            self.init(
                srgbRed: CGFloat((rgba >> 24) & 0xFF) / 255,
                green: CGFloat((rgba >> 16) & 0xFF) / 255,
                blue: CGFloat((rgba >> 8) & 0xFF) / 255,
                alpha: CGFloat(rgba & 0xFF) / 255
            )
        }
    }
#endif
