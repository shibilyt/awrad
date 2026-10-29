import Foundation
import Testing

@testable import AwradDesignSystem

/// `AwradIcon` and `Icons.xcassets` match contracts/design-tokens/v1/icons.json: every icon, in
/// order, with its file, its mirroring, and an imageset that's a template vector image.
struct AwradIconTests {
    private struct Contract {
        let keys: [String]
        let files: [String: String]
        let mirrored: Set<String>
    }

    private static func contract() throws -> Contract {
        let url = try DesignTokenContract.url("icons.json")
        let data = try Data(contentsOf: url)
        let object = try JSONSerialization.jsonObject(with: data)
        let icons = try DesignTokenContract.object(
            DesignTokenContract.object(object, "icons.json")["icons"], "icons")
        // JSONSerialization loses key order, so read the order from the file's text.
        let text = try #require(String(data: data, encoding: .utf8))
        let keys = icons.keys.sorted {
            text.range(of: "\"\($0)\": {")?.lowerBound ?? text.endIndex
                < text.range(of: "\"\($1)\": {")?.lowerBound ?? text.endIndex
        }
        var files: [String: String] = [:]
        var mirrored: Set<String> = []
        for (key, spec) in icons {
            let icon = try DesignTokenContract.object(spec, key)
            files[key] = try DesignTokenContract.string(icon["file"], "\(key).file")
            if try #require(icon["mirrorInRtl"] as? Bool, "\(key).mirrorInRtl isn't a Bool") {
                mirrored.insert(key)
            }
        }
        return Contract(keys: keys, files: files, mirrored: mirrored)
    }

    /// The generated asset catalog in the package sources (command-line builds copy it uncompiled).
    private static let catalog = URL(filePath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appending(path: "Sources/AwradDesignSystem/Resources/Icons.xcassets")

    @Test func theEnumHasEveryIconOfIconsJSONInOrder() throws {
        let contract = try Self.contract()
        #expect(AwradIcon.allCases.map(\.rawValue) == contract.keys)
        #expect(DesignTokenContract.dictionary(AwradIcon.files) == contract.files)
    }

    @Test func mirroredIconsAreTheContractsMirrorInRtlOnes() throws {
        let contract = try Self.contract()
        let mirrored = Set(AwradIcon.allCases.filter(\.mirrorsInRightToLeft).map(\.rawValue))
        #expect(mirrored == contract.mirrored)
        #expect(mirrored == ["back", "forward", "chevron"])
    }

    @Test(arguments: AwradIcon.allCases)
    func eachImagesetIsATemplateVectorThatMirrorsAsTheContractSays(icon: AwradIcon) throws {
        let imageset = Self.catalog.appending(path: "\(icon.rawValue).imageset")
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: imageset.appending(path: "Contents.json")))
        let contents = try DesignTokenContract.object(json, "\(icon.rawValue) Contents.json")
        let properties = try DesignTokenContract.object(contents["properties"], "properties")
        #expect(properties["template-rendering-intent"] as? String == "template")
        #expect(properties["preserves-vector-representation"] as? Bool == true)

        let images = try #require(contents["images"] as? [[String: Any]])
        #expect(images.count == 1)
        let file = try #require(DesignTokenContract.dictionary(AwradIcon.files)[icon.rawValue])
        #expect(images.first?["filename"] as? String == file)
        let direction = images.first?["language-direction"] as? String
        #expect(direction == (icon.mirrorsInRightToLeft ? "left-to-right" : nil))

        // The negative viewBox origin of the contract's SVGs is normalised away.
        let svg = try String(contentsOf: imageset.appending(path: file), encoding: .utf8)
        #expect(svg.contains("viewBox=\"0 0 960 960\""))
        #expect(!svg.contains("viewBox=\"0 -"))
    }

    @Test func theCatalogHoldsOnlyTheContractsIcons() throws {
        let names = try FileManager.default.contentsOfDirectory(atPath: Self.catalog.path(percentEncoded: false))
            .filter { $0.hasSuffix(".imageset") }
        #expect(Set(names) == Set(AwradIcon.allCases.map { "\($0.rawValue).imageset" }))
    }
}
