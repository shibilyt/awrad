import CoreText
import Foundation
import SwiftUI

/// Bundled fonts (contracts/design-tokens/v1/fonts): Google Sans Flex Rounded for interface text,
/// Noto Naskh Arabic for Qur'anic and dhikr text. Sizes follow Dynamic Type through `relativeTo:`,
/// and each weight is its own font file, never a synthetic bold.
///
/// Google Sans Flex has no Arabic or Malayalam glyphs. Core Text falls back per glyph to the
/// system font for those scripts, so interface text in ar and ml uses the system font.
public enum AwradFonts {
    private static var registered = false

    /// Registers the bundled fonts with the process. Call once, at app launch.
    public static func register() {
        guard !registered else { return }
        registered = true
        for url in bundledFontURLs {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    /// The font files in the package bundle.
    static var bundledFontURLs: [URL] {
        Bundle.module.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") ?? []
    }

    /// A named text style (typography.json) as a font: the face for its weight at its size, scaled
    /// with Dynamic Type relative to its `iosTextStyle`, with tabular digits where it asks for them.
    /// Use `awradTextStyle(_:)` on text that can wrap, so its lines also sit `lineHeight` apart.
    public static func font(_ style: AwradTextStyle) -> Font {
        let font = Font.custom(style.face.postScriptName, size: style.size, relativeTo: style.relativeTo)
        return style.tabularNumbers ? font.monospacedDigit() : font
    }

    /// Qur'anic and dhikr text only; interface text in Arabic uses the interface styles. The type
    /// tokens have no Qur'anic style yet, so the size is the caller's until they do.
    public static func arabic(_ size: CGFloat = 28) -> Font {
        .custom(Face.naskhRegular.postScriptName, size: size, relativeTo: .title)
    }

    /// Every bundled font face, by its file and PostScript name.
    nonisolated enum Face: CaseIterable, Sendable {
        case interfaceRegular, interfaceMedium, interfaceSemiBold, interfaceBold
        case naskhRegular, naskhMedium, naskhSemiBold, naskhBold

        var postScriptName: String {
            switch self {
            case .interfaceRegular: "GoogleSansFlexRounded-Regular"
            case .interfaceMedium: "GoogleSansFlexRounded-Medium"
            case .interfaceSemiBold: "GoogleSansFlexRounded-SemiBold"
            case .interfaceBold: "GoogleSansFlexRounded-Bold"
            case .naskhRegular: "NotoNaskhArabic-Regular"
            case .naskhMedium: "NotoNaskhArabic-Medium"
            case .naskhSemiBold: "NotoNaskhArabic-SemiBold"
            case .naskhBold: "NotoNaskhArabic-Bold"
            }
        }

        /// Ascent, descent and leading at `size`: the line height before any `lineSpacing`.
        func naturalLineHeight(size: CGFloat) -> CGFloat {
            let font = CTFontCreateWithName(postScriptName as CFString, size, nil)
            return CTFontGetAscent(font) + CTFontGetDescent(font) + CTFontGetLeading(font)
        }

        var fileName: String {
            switch self {
            case .interfaceRegular: "googlesansflexrounded_regular.ttf"
            case .interfaceMedium: "googlesansflexrounded_medium.ttf"
            case .interfaceSemiBold: "googlesansflexrounded_semibold.ttf"
            case .interfaceBold: "googlesansflexrounded_bold.ttf"
            case .naskhRegular: "notonaskharabic_regular.ttf"
            case .naskhMedium: "notonaskharabic_medium.ttf"
            case .naskhSemiBold: "notonaskharabic_semibold.ttf"
            case .naskhBold: "notonaskharabic_bold.ttf"
            }
        }
    }
}
