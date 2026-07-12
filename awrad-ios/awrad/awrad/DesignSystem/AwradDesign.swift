import SwiftUI

#if os(iOS)
import UIKit
#endif

enum AwradTheme {
    static let sage = dynamicColor(light: 0x4B7C5A, dark: 0x6B9E7A)
    static let sageDark = dynamicColor(light: 0x2E5C3D, dark: 0xD4E8DA)
    static let mint = dynamicColor(light: 0xD4E8DA, dark: 0x2E5C3D)
    static let gold = dynamicColor(light: 0xD4A843, dark: 0xE8C878)
    static let ink = dynamicColor(light: 0x1A1C1A, dark: 0xE1E3E1)
    static let subdued = dynamicColor(light: 0x5D5F5D, dark: 0xAAACAA)
    static let surface = dynamicColor(light: 0xFFFFFF, dark: 0x1E201E)
    static let background = dynamicColor(light: 0xF0F2F0, dark: 0x121412)
    static let outline = dynamicColor(light: 0x1A1C1A, dark: 0xE1E3E1, lightAlpha: 0.22, darkAlpha: 0.55)
    static let trackFill = dynamicColor(light: 0xFFFFFF, dark: 0x343834)

    static func arabicFont(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(notoNaskhArabicName(for: weight), size: size)
    }

    static func arabicFont(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .custom(notoNaskhArabicName(for: weight), size: defaultSize(for: style), relativeTo: style)
    }

    static func displayFont(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .custom(googleSansRoundedName(for: weight), size: size)
    }

    static func displayFont(_ style: Font.TextStyle, weight: Font.Weight = .semibold) -> Font {
        .custom(googleSansRoundedName(for: weight), size: defaultSize(for: style), relativeTo: style)
    }

    static func bodyFont(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .custom(googleSansRoundedName(for: weight), size: defaultSize(for: style), relativeTo: style)
    }

    static func bodyFont(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(googleSansRoundedName(for: weight), size: size)
    }

    /// Google Sans Flex, instanced at ROND=100 (rounded) per weight. Latin text.
    private static func googleSansRoundedName(for weight: Font.Weight) -> String {
        switch weight {
        case .bold, .heavy, .black:
            "GoogleSansFlexRounded-Bold"
        case .semibold:
            "GoogleSansFlexRounded-SemiBold"
        case .medium:
            "GoogleSansFlexRounded-Medium"
        default:
            "GoogleSansFlexRounded-Regular"
        }
    }

    private static func dynamicColor(light: UInt32, dark: UInt32, lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) -> Color {
        #if os(iOS)
        Color(uiColor: UIColor { traitCollection in
            let isDark = traitCollection.userInterfaceStyle == .dark
            return UIColor(hex: isDark ? dark : light).withAlphaComponent(isDark ? darkAlpha : lightAlpha)
        })
        #else
        Color(hex: light).opacity(lightAlpha)
        #endif
    }

    private static func manropeName(for weight: Font.Weight) -> String {
        switch weight {
        case .bold, .heavy, .black:
            "Manrope-Bold"
        case .semibold:
            "Manrope-SemiBold"
        case .medium:
            "Manrope-Medium"
        default:
            "Manrope-Regular"
        }
    }

    private static func plusJakartaSansName(for weight: Font.Weight) -> String {
        switch weight {
        case .bold, .heavy, .black:
            "PlusJakartaSans-Bold"
        case .semibold:
            "PlusJakartaSans-SemiBold"
        case .medium:
            "PlusJakartaSans-Medium"
        default:
            "PlusJakartaSans-Regular"
        }
    }

    private static func notoNaskhArabicName(for weight: Font.Weight) -> String {
        switch weight {
        case .bold, .heavy, .black:
            "NotoNaskhArabic-Bold"
        case .semibold:
            "NotoNaskhArabic-SemiBold"
        case .medium:
            "NotoNaskhArabic-Medium"
        default:
            "NotoNaskhArabic-Regular"
        }
    }

    private static func defaultSize(for style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle:
            34
        case .title:
            28
        case .title2:
            22
        case .title3:
            20
        case .headline:
            17
        case .subheadline:
            15
        case .callout:
            16
        case .caption:
            12
        case .caption2:
            11
        case .footnote:
            13
        case .body:
            17
        @unknown default:
            17
        }
    }
}

#if os(iOS)
private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
#else
private extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
#endif

struct AwradBundleImage: View {
    let name: String

    var body: some View {
        #if os(iOS)
        if let image = UIImage(named: name) ?? imageFromBundle(named: name) {
            Image(uiImage: image)
                .resizable()
        } else {
            placeholder
        }
        #else
        Image(name)
            .resizable()
        #endif
    }

    private var placeholder: some View {
        LinearGradient(
            colors: [AwradTheme.mint.opacity(0.45), AwradTheme.gold.opacity(0.18)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    #if os(iOS)
    private static let imageCache = NSCache<NSString, UIImage>()

    private func imageFromBundle(named name: String) -> UIImage? {
        let cacheKey = name as NSString
        if let cachedImage = Self.imageCache.object(forKey: cacheKey) {
            return cachedImage
        }

        guard let url = Bundle.main.url(forResource: name, withExtension: "png") else {
            return nil
        }
        guard let image = UIImage(contentsOfFile: url.path) else {
            return nil
        }
        Self.imageCache.setObject(image, forKey: cacheKey)
        return image
    }
    #endif
}

struct AwradCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AwradTheme.surface)
                    .shadow(color: .black.opacity(0.06), radius: 14, x: 0, y: 8)
            }
    }
}

struct AwradProgressBar: View {
    var value: Double
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AwradTheme.mint.opacity(0.32))
                Capsule()
                    .fill(AwradTheme.sage)
                    .frame(width: max(0, width * min(max(value, 0), 1)))
            }
        }
        .frame(height: height)
    }
}

struct MetricPill: View {
    var title: String
    var value: String
    var symbol: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(AwradTheme.bodyFont(15, weight: .semibold))
                .foregroundStyle(AwradTheme.gold)
                .frame(width: 28, height: 28)
                .background(AwradTheme.gold.opacity(0.15), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(AwradTheme.bodyFont(17, weight: .semibold))
                    .foregroundStyle(AwradTheme.ink)
                Text(LocalizedStringKey(title))
                    .font(AwradTheme.bodyFont(.caption))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(AwradTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct EmptyStateView: View {
    var symbol: String
    var title: String
    var message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(AwradTheme.bodyFont(28, weight: .semibold))
                .foregroundStyle(AwradTheme.sage)
                .frame(width: 56, height: 56)
                .background(AwradTheme.mint.opacity(0.24), in: Circle())
            Text(LocalizedStringKey(title))
                .font(AwradTheme.displayFont(18))
            Text(LocalizedStringKey(message))
                .font(AwradTheme.bodyFont(.subheadline))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(22)
    }
}

struct SectionHeader: View {
    var title: String
    var subtitle: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(LocalizedStringKey(title))
                    .font(AwradTheme.displayFont(20))
                    .foregroundStyle(AwradTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                if let subtitle {
                    Text(LocalizedStringKey(subtitle))
                        .font(AwradTheme.bodyFont(.subheadline))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 10)
            if let actionTitle, let action {
                Button(action: action) {
                    Text(LocalizedStringKey(actionTitle))
                }
                    .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                    .foregroundStyle(AwradTheme.sage)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
    }
}

extension View {
    func awradPrimaryButton() -> some View {
        buttonStyle(.borderedProminent)
            .tint(AwradTheme.sage)
            .controlSize(.large)
            .buttonBorderShape(.roundedRectangle(radius: 24))
    }

    func awradGlassIconButton(
        size: CGFloat = 46,
        cornerRadius: CGFloat? = nil,
        tint: Color = AwradTheme.mint.opacity(0.52)
    ) -> some View {
        modifier(AwradGlassIconButtonModifier(size: size, cornerRadius: cornerRadius ?? size / 2, tint: tint))
    }

    func awradGlassSurface(
        cornerRadius: CGFloat = 22,
        tint: Color = AwradTheme.surface.opacity(0.7),
        interactive: Bool = false
    ) -> some View {
        modifier(AwradGlassSurfaceModifier(cornerRadius: cornerRadius, tint: tint, interactive: interactive))
    }
}

private struct AwradGlassSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color
    let interactive: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(iOS 26.0, *) {
            content
                .background(tint.opacity(0.7), in: shape)
                .glassEffect(.regular.tint(tint).interactive(interactive), in: shape)
        } else {
            content
                .background(tint, in: shape)
                .overlay(shape.stroke(AwradTheme.sage.opacity(0.14), lineWidth: 1))
                .shadow(color: .black.opacity(0.05), radius: 14, x: 0, y: 8)
        }
    }
}

private struct AwradGlassIconButtonModifier: ViewModifier {
    let size: CGFloat
    let cornerRadius: CGFloat
    let tint: Color

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(iOS 26.0, *) {
            content
                .frame(width: size, height: size)
                .background(tint.opacity(0.72), in: shape)
                .glassEffect(.regular.tint(tint).interactive(true), in: shape)
        } else {
            content
                .frame(width: size, height: size)
                .background(tint, in: shape)
                .overlay(shape.stroke(AwradTheme.sage.opacity(0.18), lineWidth: 1))
        }
    }
}
