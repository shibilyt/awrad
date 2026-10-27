import SwiftUI

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

/// The Awrad logo (misbaha ring and Arabic mark). Decorative, so it's hidden from accessibility.
public struct AwradLogoMark: View {
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public var body: some View {
        logo
            .resizable()
            .scaledToFit()
            .accessibilityHidden(true)
    }

    private var logo: Image {
        let name = colorScheme == .dark ? "awrad_logo_dark" : "awrad_logo_light"
        // The PNGs ship in the bundle; an empty image only if one were missing.
        let url = Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "Images")
        #if canImport(UIKit)
            return Image(uiImage: url.flatMap { UIImage(contentsOfFile: $0.path()) } ?? UIImage())
        #else
            return Image(nsImage: url.flatMap { NSImage(contentsOf: $0) } ?? NSImage())
        #endif
    }
}
