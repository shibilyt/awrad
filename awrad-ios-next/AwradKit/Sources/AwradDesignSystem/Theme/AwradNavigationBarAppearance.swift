import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

/// The native navigation bar's titles in the interface font. SwiftUI's `navigationTitle` draws with
/// the system font and takes no font of its own, so the app sets it once, through UIKit's appearance
/// proxy, at launch: the large title in `largeTitle`, the inline title in `rowTitle` (the compact
/// bar's 16 pt semibold; `title`'s 22 pt is too big for it). Both are scaled with `UIFontMetrics` for
/// the Dynamic Type size at launch, relative to each style's text style. Colours stay the system's.
public enum AwradNavigationBarAppearance {
    /// The inline (compact) title's style.
    static let inlineTitle = AwradTextStyle.rowTitle
    /// The large title's style.
    static let largeTitle = AwradTextStyle.largeTitle

    /// Registers the fonts if needed and sets the navigation bar title fonts. Call once, at app launch.
    public static func apply() {
        AwradFonts.register()
        #if canImport(UIKit)
            let bar = UINavigationBar.appearance()
            bar.titleTextAttributes = [.font: uiFont(inlineTitle)]
            bar.largeTitleTextAttributes = [.font: uiFont(largeTitle)]
        #endif
    }

    #if canImport(UIKit)
        /// A style's face at its size, scaled for Dynamic Type relative to its text style.
        static func uiFont(_ style: AwradTextStyle) -> UIFont {
            let base =
                UIFont(name: style.face.postScriptName, size: style.size)
                ?? .systemFont(ofSize: style.size, weight: .semibold)
            return UIFontMetrics(forTextStyle: uiTextStyle(style.relativeTo)).scaledFont(for: base)
        }

        /// SwiftUI's text style as UIKit's, for `UIFontMetrics`.
        static func uiTextStyle(_ style: Font.TextStyle) -> UIFont.TextStyle {
            switch style {
            case .largeTitle: .largeTitle
            case .title: .title1
            case .title2: .title2
            case .title3: .title3
            case .headline: .headline
            case .subheadline: .subheadline
            case .callout: .callout
            case .footnote: .footnote
            case .caption: .caption1
            case .caption2: .caption2
            default: .body
            }
        }
    #endif
}
