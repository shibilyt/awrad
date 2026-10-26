import SwiftUI

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

/// Semantic colour roles, the same sage palette as awrad-android-next.
/// Screens use these roles and never choose a colour by checking the colour scheme.
public enum AwradColors {
    public static let primary = adaptive(light: 0x4B7C5A, dark: 0x6B9E7A)
    public static let onPrimary = adaptive(light: 0xFFFFFF, dark: 0x2E5C3D)
    public static let primaryContainer = adaptive(light: 0xD4E8DA, dark: 0x2E5C3D)
    public static let onPrimaryContainer = adaptive(light: 0x1A3D26, dark: 0xD4E8DA)
    public static let background = adaptive(light: 0xF0F2F0, dark: 0x121412)
    public static let surface = adaptive(light: 0xFFFFFF, dark: 0x121412)
    public static let onSurface = adaptive(light: 0x1A1C1A, dark: 0xE3E5E3)
    public static let onSurfaceVariant = adaptive(light: 0x5D5F5D, dark: 0xABADAB)
    public static let outlineVariant = adaptive(light: 0xC7C9C7, dark: 0x454745)
    public static let error = adaptive(light: 0xBA1A1A, dark: 0xFFB4AB)

    // The provider closures are `@Sendable` and only pick between colours made up front: UIKit and
    // SwiftUI resolve dynamic colours off the main thread, so a closure inferred as main-actor
    // isolated (this module's default) traps at runtime.
    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        #if canImport(UIKit)
            let lightColor = UIColor(rgb: light)
            let darkColor = UIColor(rgb: dark)
            return Color(
                uiColor: UIColor { @Sendable traits in
                    traits.userInterfaceStyle == .dark ? darkColor : lightColor
                }
            )
        #else
            let lightColor = NSColor(rgb: light)
            let darkColor = NSColor(rgb: dark)
            return Color(
                nsColor: NSColor(name: nil) { @Sendable appearance in
                    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? darkColor : lightColor
                }
            )
        #endif
    }
}

#if canImport(UIKit)
    private extension UIColor {
        convenience init(rgb: UInt32) {
            self.init(
                red: CGFloat((rgb >> 16) & 0xFF) / 255,
                green: CGFloat((rgb >> 8) & 0xFF) / 255,
                blue: CGFloat(rgb & 0xFF) / 255,
                alpha: 1
            )
        }
    }
#else
    private extension NSColor {
        convenience init(rgb: UInt32) {
            self.init(
                srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255,
                green: CGFloat((rgb >> 8) & 0xFF) / 255,
                blue: CGFloat(rgb & 0xFF) / 255,
                alpha: 1
            )
        }
    }
#endif
