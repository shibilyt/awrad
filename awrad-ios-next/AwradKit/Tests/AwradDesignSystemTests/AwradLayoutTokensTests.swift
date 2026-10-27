import SwiftUI
import Testing

@testable import AwradDesignSystem

/// The generated shapes, strokes, spacing and type match contracts/design-tokens/v1: every scale
/// step, role, stroke, size and style, by name and value.
struct AwradLayoutTokensTests {
    @Test func theRadiusScaleAndRolesMatchShapeJSON() throws {
        let shape = try DesignTokenContract.json("shape")
        let scale = try DesignTokenContract.object(shape["scale"], "scale")
        var expectedScale: [String: CGFloat] = [:]
        for (key, value) in scale where value as? String != "full" {
            expectedScale[key] = CGFloat(try DesignTokenContract.number(value, "scale.\(key)"))
        }
        #expect(DesignTokenContract.dictionary(AwradRadius.scale) == expectedScale)

        let roles = try DesignTokenContract.object(shape["roles"], "roles")
        var expectedRoles: [String: AwradCorner] = [:]
        for (role, spec) in roles {
            let step = try DesignTokenContract.string(DesignTokenContract.object(spec, role)["radius"], role)
            if let radius = expectedScale[step] {
                expectedRoles[role] = .radius(radius)
            } else {
                #expect(scale[step] as? String == "full", "\(role) names \(step), not on the scale")
                expectedRoles[role] = .full
            }
        }
        #expect(DesignTokenContract.dictionary(AwradRadius.roles) == expectedRoles)
    }

    @Test func everyStrokeMatchesShapeJSON() throws {
        let strokes = try DesignTokenContract.object(DesignTokenContract.json("shape")["strokes"], "strokes")
        var expected: [String: CGFloat] = [:]
        for (name, spec) in strokes {
            let stroke = try DesignTokenContract.object(spec, name)
            expected["\(name).width"] = CGFloat(try DesignTokenContract.number(stroke["width"], "\(name).width"))
            if let offset = stroke["offset"] {
                expected["\(name).offset"] = CGFloat(try DesignTokenContract.number(offset, "\(name).offset"))
            }
        }
        #expect(DesignTokenContract.dictionary(AwradStroke.strokes) == expected)
    }

    @Test func theContractNamesTheRolesTheAppUses() {
        #expect(AwradRadius.card == .radius(24))
        #expect(AwradRadius.button == .radius(16))
        #expect(AwradRadius.field == .radius(16))
        #expect(AwradRadius.sheet.fixedRadius == 32)
        #expect(AwradRadius.chip == .full)
        #expect(AwradRadius.checkbox == .radius(4))
        #expect(AwradSpacing.pageMargin == 20)
        #expect(AwradSize.control == 56)
        #expect(AwradSize.logo == 148)
        #expect(AwradStroke.fieldError == 1.5)
    }

    @Test func shapesHaveContinuousCorners() {
        let rect = CGRect(x: 0, y: 0, width: 120, height: 48)
        #expect(
            AwradRadius.card.shape.path(in: rect)
                == RoundedRectangle(cornerRadius: 24, style: .continuous).path(in: rect))
        #expect(AwradRadius.chip.shape.path(in: rect) == Capsule(style: .continuous).path(in: rect))
        // Insetting (strokeBorder) keeps the curve concentric: the radius shrinks by the inset.
        #expect(
            AwradRadius.field.shape.inset(by: 2).path(in: rect)
                == RoundedRectangle(cornerRadius: 14, style: .continuous).path(in: rect.insetBy(dx: 2, dy: 2)))
    }

    @Test func theSpacingScaleRolesAndSizesMatchSpacingJSON() throws {
        let spacing = try DesignTokenContract.json("spacing")
        let scale = try DesignTokenContract.object(spacing["scale"], "scale")
            .mapValues { CGFloat(try DesignTokenContract.number($0, "scale")) }
        #expect(DesignTokenContract.dictionary(AwradSpacing.scale) == scale)

        let roles = try DesignTokenContract.object(spacing["roles"], "roles").mapValues { spec in
            let step = try DesignTokenContract.string(DesignTokenContract.object(spec, "role")["space"], "space")
            return try #require(scale[step], "\(step) isn't on the scale")
        }
        #expect(DesignTokenContract.dictionary(AwradSpacing.roles) == roles)

        let sizes = try DesignTokenContract.object(spacing["sizes"], "sizes").mapValues { spec in
            CGFloat(try DesignTokenContract.number(DesignTokenContract.object(spec, "size")["value"], "value"))
        }
        #expect(DesignTokenContract.dictionary(AwradSize.sizes) == sizes)
    }

    @Test func everyTextStyleMatchesTypographyJSON() throws {
        let typography = try DesignTokenContract.json("typography")
        let interfaceFamily = try DesignTokenContract.string(typography["fontFamily"], "fontFamily")
        let styles = try DesignTokenContract.object(typography["styles"], "styles")
        #expect(Set(AwradTextStyle.all.map(\.name)) == Set(styles.keys))
        for style in AwradTextStyle.all {
            let spec = try DesignTokenContract.object(styles[style.name], style.name)
            let size = try DesignTokenContract.number(spec["size"], "size")
            let lineHeight = try DesignTokenContract.number(spec["lineHeight"], "lineHeight")
            let weight = try DesignTokenContract.number(spec["weight"], "weight")
            let iosTextStyle = try DesignTokenContract.string(spec["iosTextStyle"], "iosTextStyle")
            #expect(Double(style.size) == size, "\(style.name)")
            #expect(Double(style.lineHeight) == lineHeight, "\(style.name)")
            #expect(Double(style.weight) == weight, "\(style.name)")
            #expect(Self.name(of: style.relativeTo) == iosTextStyle, "\(style.name)")
            #expect(style.tabularNumbers == (spec["tabularNumbers"] as? Bool ?? false), "\(style.name)")
            let family = spec["fontFamily"] as? String ?? interfaceFamily
            #expect(style.face == Self.face(family: family, weight: style.weight), "\(style.name) uses the wrong face")
        }
        #expect(AwradTextStyle.counter.tabularNumbers)
        #expect(AwradTextStyle.input.size == 16)
        #expect(AwradTextStyle.quran.face == .naskhRegular)
    }

    /// Lines sit `lineHeight` apart: the face's own line height plus `lineSpacing`, never less.
    @Test(arguments: AwradTextStyle.all)
    func lineSpacingMakesUpTheLineHeight(style: AwradTextStyle) {
        AwradFonts.register()
        let natural = style.face.naturalLineHeight(size: style.size)
        #expect(style.lineSpacing >= 0)
        #expect(abs(natural + style.lineSpacing - max(style.lineHeight, natural)) < 0.001, "\(style.name)")
    }

    /// The bundled face of a contract font family at a weight; `nil` for a family that isn't bundled.
    private static func face(family: String, weight: Int) -> AwradFonts.Face? {
        switch family {
        case "Google Sans Flex Rounded":
            [400: .interfaceRegular, 500: .interfaceMedium, 600: .interfaceSemiBold, 700: .interfaceBold][weight]
        case "Noto Naskh Arabic":
            [400: .naskhRegular, 500: .naskhMedium, 600: .naskhSemiBold, 700: .naskhBold][weight]
        default: nil
        }
    }

    private static func name(of style: Font.TextStyle) -> String {
        switch style {
        case .largeTitle: "largeTitle"
        case .title: "title"
        case .title2: "title2"
        case .title3: "title3"
        case .headline: "headline"
        case .subheadline: "subheadline"
        case .body: "body"
        case .callout: "callout"
        case .footnote: "footnote"
        case .caption: "caption"
        case .caption2: "caption2"
        default: "unknown"
        }
    }
}

extension AwradTextStyle: CustomTestStringConvertible {
    public var testDescription: String { name }
}
