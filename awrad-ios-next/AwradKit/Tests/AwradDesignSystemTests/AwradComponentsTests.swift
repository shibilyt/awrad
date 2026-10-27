import Foundation
import SwiftUI
import Testing

@testable import AwradDesignSystem

/// State and accessibility logic of the components (contracts/design-system/v1/components.md).
struct AwradComponentsTests {
    // MARK: Step indicator

    @Test func theStepIndicatorReadsAsOneStep() {
        var label = AwradStepIndicator(current: 2, total: 7).accessibilityLabel
        label.locale = Locale(identifier: "en")
        #expect(String(localized: label) == "Step 2 of 7")
    }

    @Test func stepsUpToTheCurrentOneAreFilled() {
        let indicator = AwradStepIndicator(current: 2, total: 7)
        #expect((1...7).filter(indicator.isReached) == [1, 2])
    }

    @Test func theCurrentStepStaysInTheFlow() {
        #expect(AwradStepIndicator(current: 0, total: 7).current == 1)
        #expect(AwradStepIndicator(current: 9, total: 7).current == 7)
        #expect(AwradStepIndicator(current: 1, total: 0).total == 1)
    }

    // MARK: Segmented pills

    @Test func tappingAPillSelectsIt() {
        let box = Box(0)
        let pills = AwradSegmentedPills(selection: box.binding, options: Self.options)
        pills.select(1)
        #expect(box.value == 1)
        #expect(box.writes == 1)
    }

    @Test func tappingTheSelectedPillChangesNothing() {
        let box = Box(1)
        AwradSegmentedPills(selection: box.binding, options: Self.options).select(1)
        #expect(box.writes == 0)
    }

    @Test func onlyTheSelectedPillReadsAsSelected() {
        #expect(AwradSegmentedPills<Int>.traits(isSelected: true) == .isSelected)
        #expect(AwradSegmentedPills<Int>.traits(isSelected: false) == [])
    }

    // MARK: Option row

    @Test func aSingleChoiceRowReadsItsSelection() {
        #expect(AwradOptionRow.Selection.single.traits(isSelected: true) == .isSelected)
        #expect(AwradOptionRow.Selection.single.traits(isSelected: false) == [])
    }

    @Test func aMultipleChoiceRowReadsAsAToggle() {
        #expect(AwradOptionRow.Selection.multiple.traits(isSelected: true) == [.isToggle, .isSelected])
        #expect(AwradOptionRow.Selection.multiple.traits(isSelected: false) == .isToggle)
    }

    // MARK: Buttons

    @Test(arguments: [AwradButton.Variant.main, .secondary, .error])
    func filledButtonsAreControlTall(variant: AwradButton.Variant) {
        #expect(AwradButtonAppearance(variant: variant, layout: .fill).height == AwradSize.control)
        #expect(AwradButtonAppearance(variant: variant, layout: .fill).fillsWidth)
    }

    @Test func rowAndTextButtonsAreTouchTargetTall() {
        let row = AwradButtonAppearance(variant: .secondary, layout: .row)
        #expect(row.height == AwradSize.touchTarget)
        #expect(!row.fillsWidth)
        #expect(AwradButtonAppearance(variant: .text, layout: .fill).height == AwradSize.touchTarget)
        #expect(AwradButtonAppearance(variant: .text, layout: .fill).textStyle == .label)
        #expect(AwradButtonAppearance(variant: .main, layout: .fill).textStyle == .button)
    }

    @Test(arguments: [ColorScheme.light, .dark])
    func eachVariantUsesItsRoles(scheme: ColorScheme) {
        // Each variant's fill and content roles.
        let roles: [AwradButton.Variant: [Color]] = [
            .main: [AwradColors.primary, AwradColors.onPrimary],
            .secondary: [AwradColors.secondaryContainer, AwradColors.onSecondaryContainer],
            .error: [AwradColors.error, AwradColors.onError],
            .text: [.clear, AwradColors.accent],
        ]
        for (variant, colors) in roles {
            let appearance = AwradButtonAppearance(variant: variant, layout: .fill)
            #expect(
                [appearance.fill, appearance.content].map { Self.resolved($0, scheme) }
                    == colors.map { Self.resolved($0, scheme) })
        }
        let destructive = AwradButtonAppearance(variant: .text, layout: .row, isDestructive: true)
        #expect(Self.resolved(destructive.content, scheme) == Self.resolved(AwradColors.error, scheme))
    }

    // MARK: Containers

    @Test func aCardIsTheOtherContainer() {
        #expect(AwradContainer.background.inverted == .surface)
        #expect(AwradContainer.surface.inverted == .background)
    }

    /// `secondaryContainer` is `surface` in light, so on a surface secondary fills are `background`.
    @Test(arguments: [ColorScheme.light, .dark])
    func secondaryFillsStandOutOnASurface(scheme: ColorScheme) {
        let onPage = AwradButtonAppearance(variant: .secondary, layout: .fill)
        #expect(Self.resolved(onPage.fill, scheme) == Self.resolved(AwradColors.secondaryContainer, scheme))
        #expect(Self.resolved(onPage.content, scheme) == Self.resolved(AwradColors.onSecondaryContainer, scheme))
        let onCard = AwradButtonAppearance(variant: .secondary, layout: .fill, container: .surface)
        #expect(Self.resolved(onCard.fill, scheme) == Self.resolved(AwradColors.background, scheme))
        #expect(Self.resolved(onCard.content, scheme) == Self.resolved(AwradColors.onSurface, scheme))
        #expect(
            Self.resolved(AwradContainer.surface.secondaryFill, scheme) != Self.resolved(AwradColors.surface, scheme))
    }

    // MARK: Strings

    @Test func everyComponentStringIsInTheCatalogWithItsEnglishDefault() throws {
        let url = URL(filePath: #filePath).deletingLastPathComponent().appending(
            path: "../../Sources/AwradDesignSystem/Resources/Localizable.xcstrings")
        let catalog = try #require(
            try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let strings = try #require(catalog["strings"] as? [String: Any])
        let expected = [
            "ds.back": "Back", "ds.more": "More options", "ds.loading": "Loading",
            "ds.step_indicator": "Step %1$lld of %2$lld",
        ]
        for (key, english) in expected {
            let entry = try #require(strings[key] as? [String: Any], "\(key) isn't in the catalog")
            let value =
                (entry["localizations"] as? [String: Any]).flatMap { $0["en"] as? [String: Any] }
                .flatMap { $0["stringUnit"] as? [String: Any] }?["value"] as? String
            #expect(value == english, "\(key)")
        }
        for resource in [AwradStrings.back, AwradStrings.more, AwradStrings.loading] {
            #expect(expected[resource.key] != nil)
        }
    }

    private static let options: [AwradSegmentedPills<Int>.Option] = [
        .init(0, title: "Active"), .init(1, title: "History"),
    ]

    private static func resolved(_ color: Color, _ scheme: ColorScheme) -> Color.Resolved {
        var environment = EnvironmentValues()
        environment.colorScheme = scheme
        return color.resolve(in: environment)
    }
}

/// A selection the test can read back, counting writes.
@MainActor private final class Box {
    var value: Int
    var writes = 0

    init(_ value: Int) {
        self.value = value
    }

    var binding: Binding<Int> {
        Binding(
            get: { self.value },
            set: {
                self.value = $0
                self.writes += 1
            })
    }
}
