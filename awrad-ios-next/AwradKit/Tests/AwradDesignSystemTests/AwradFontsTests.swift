import CoreText
import Foundation
import Testing

@testable import AwradDesignSystem

/// The bundled fonts (contracts/design-tokens/v1/fonts/README.md): every file registers and resolves
/// by its PostScript name, and interface text in Arabic or Malayalam falls back to the system font.
struct AwradFontsTests {
    init() {
        AwradFonts.register()
    }

    @Test func theBundleHoldsExactlyTheContractFonts() {
        let bundled = Set(AwradFonts.bundledFontURLs.map(\.lastPathComponent))
        #expect(bundled == Set(AwradFonts.Face.allCases.map(\.fileName)))
    }

    @Test(arguments: AwradFonts.Face.allCases)
    func everyFontResolvesByItsPostScriptName(face: AwradFonts.Face) throws {
        let url = try #require(AwradFonts.bundledFontURLs.first { $0.lastPathComponent == face.fileName })
        let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor] ?? []
        let names = descriptors.compactMap { CTFontDescriptorCopyAttribute($0, kCTFontNameAttribute) as? String }
        #expect(names == [face.postScriptName])

        // CTFontCreateWithName substitutes a fallback for an unknown name, so check what it returned.
        let font = CTFontCreateWithName(face.postScriptName as CFString, 17, nil)
        #expect(CTFontCopyPostScriptName(font) as String == face.postScriptName)
    }

    @Test(arguments: [
        ("ar", "الإعدادات"),
        ("ml", "ക്രമീകരണങ്ങൾ"),
    ])
    func interfaceTextInOtherScriptsFallsBackToTheSystemFont(language: String, text: String) {
        let interface = CTFontCreateWithName(AwradFonts.Face.interfaceRegular.postScriptName as CFString, 17, nil)
        let fallback = CTFontCreateForString(
            interface, text as CFString, CFRange(location: 0, length: text.utf16.count))
        let name = CTFontCopyPostScriptName(fallback) as String
        #expect(!name.hasPrefix("GoogleSansFlexRounded"), "\(language) text has no glyphs in the interface font")
        #expect(!name.hasPrefix("NotoNaskhArabic"), "\(language) interface text must not use the Qur'an font")
    }
}
