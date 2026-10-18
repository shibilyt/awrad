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
        guard let url = Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "Images") else {
            return Image(systemName: "circle.dotted")
        }
        #if canImport(UIKit)
            return UIImage(contentsOfFile: url.path()).map(Image.init(uiImage:)) ?? Image(systemName: "circle.dotted")
        #else
            return NSImage(contentsOf: url).map(Image.init(nsImage:)) ?? Image(systemName: "circle.dotted")
        #endif
    }
}
