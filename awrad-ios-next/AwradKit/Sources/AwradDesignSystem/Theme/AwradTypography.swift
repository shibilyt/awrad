import CoreText
import Foundation
import SwiftUI

/// Bundled fonts: Manrope for interface text, Noto Naskh Arabic for Qur'anic and dhikr text.
/// Sizes follow Dynamic Type through `relativeTo:`.
public enum AwradFonts {
    private static var registered = false

    /// Registers the bundled fonts with the process. Call once, at app launch.
    public static func register() {
        guard !registered else { return }
        registered = true
        let urls = Bundle.module.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") ?? []
        for url in urls {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    public static func headline(_ size: CGFloat = 28) -> Font {
        .custom("Manrope-SemiBold", size: size, relativeTo: .title)
    }

    public static func title(_ size: CGFloat = 17) -> Font {
        .custom("Manrope-SemiBold", size: size, relativeTo: .headline)
    }

    public static func body(_ size: CGFloat = 16) -> Font {
        .custom("Manrope-Regular", size: size, relativeTo: .body)
    }

    public static func arabic(_ size: CGFloat = 28) -> Font {
        .custom("NotoNaskhArabic-Regular", size: size, relativeTo: .title)
    }
}
