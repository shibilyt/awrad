import SwiftUI

// The styles themselves are generated into AwradTextStyle.swift by scripts/generate-design-tokens.py.

/// A named text style from typography.json: size and line height in points, the weight's bundled
/// face, and the Dynamic Type style it scales with.
nonisolated public struct AwradTextStyle: Sendable, Hashable {
    /// The contract name, such as `cardTitle`.
    public let name: String
    public let size: CGFloat
    public let lineHeight: CGFloat
    /// The CSS weight, 400 to 700; `face` is the bundled file for it.
    public let weight: Int
    let face: AwradFonts.Face
    /// The Dynamic Type style the size scales with (`iosTextStyle`).
    public let relativeTo: Font.TextStyle
    /// Digits all the same width, so a changing number doesn't shift (the counter).
    public let tabularNumbers: Bool

    /// The `lineSpacing` that sets lines `lineHeight` apart: the gap above the face's own line
    /// height. Never negative: a line height tighter than the face's (the single-line `counter`)
    /// keeps the face's own.
    public var lineSpacing: CGFloat {
        max(0, lineHeight - face.naturalLineHeight(size: size))
    }
}

extension View {
    /// Sets a named text style: its font (`AwradFonts.font(_:)`) and its line height through
    /// `lineSpacing`, both scaled with Dynamic Type.
    public func awradTextStyle(_ style: AwradTextStyle) -> some View {
        modifier(AwradTextStyleModifier(style: style))
    }
}

private struct AwradTextStyleModifier: ViewModifier {
    let style: AwradTextStyle
    @ScaledMetric private var lineSpacing: CGFloat

    init(style: AwradTextStyle) {
        self.style = style
        _lineSpacing = ScaledMetric(wrappedValue: style.lineSpacing, relativeTo: style.relativeTo)
    }

    func body(content: Content) -> some View {
        content
            .font(AwradFonts.font(style))
            .lineSpacing(lineSpacing)
    }
}

#Preview("Text styles") {
    ScrollView {
        VStack(alignment: .leading, spacing: AwradSpacing.rowGap) {
            ForEach(AwradTextStyle.all, id: \.name) { style in
                Text(verbatim: "\(style.name) 1234567890")
                    .awradTextStyle(style)
                    .foregroundStyle(AwradColors.onSurface)
            }
        }
        .padding(AwradSpacing.pageMargin)
    }
    .background(AwradColors.background)
    .onAppear { AwradFonts.register() }
}
