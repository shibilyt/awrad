// swift-tools-version: 6.2
// AwradKit: every line of iOS code except the thin app target (ADR 0001).
//
// Module rules are compiler-enforced: a target can only import what it lists in
// `dependencies`. scripts/check-module-rules.py additionally checks that each
// target's list follows the allowed graph in ARCHITECTURE.md.
import PackageDescription

/// Every target uses Swift 6 language mode (tools 6.2) with complete concurrency checking.
///
/// Warnings as errors are enforced by `scripts/validate` (`swift build`/`swift test`
/// with `-warnings-as-errors`), not here: Xcode compiles this package as a dependency
/// of the app with `-suppress-warnings`, which conflicts with `.treatAllWarnings`.
let strict: [SwiftSetting] = []

/// UI targets are main-actor by default; the domain and data targets are not.
let ui: [SwiftSetting] = strict + [.defaultIsolation(MainActor.self)]

let package = Package(
    name: "AwradKit",
    defaultLocalization: "en",
    // macOS lets `swift test` run domain, data and model tests without a simulator.
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "AwradDomain", targets: ["AwradDomain"]),
        .library(name: "AwradData", targets: ["AwradData"]),
        .library(name: "AwradDesignSystem", targets: ["AwradDesignSystem"]),
        .library(name: "FeatureOnboarding", targets: ["FeatureOnboarding"]),
        .library(name: "FeatureAccount", targets: ["FeatureAccount"]),
        .library(name: "FeatureLibrary", targets: ["FeatureLibrary"]),
        .library(name: "FeaturePracticeSettings", targets: ["FeaturePracticeSettings"]),
    ],
    // adhan-swift computes Maghrib for the day reset (slice 3d, ADR 0006); only AwradData uses it.
    dependencies: [.package(url: "https://github.com/batoulapps/adhan-swift", exact: "1.5.0")],
    targets: [
        .target(
            name: "AwradDomain",
            // Identical copies of contracts/dhikr-catalog/v1/catalog.json (scripts/check-dhikr-catalog.py)
            // and contracts/places/v1/cities.json (scripts/check-city-list.py).
            resources: [.copy("Resources/dhikr-catalog.json"), .copy("Resources/cities.json")],
            swiftSettings: strict
        ),
        .target(
            name: "AwradData",
            dependencies: ["AwradDomain", .product(name: "Adhan", package: "adhan-swift")],
            swiftSettings: strict
        ),
        .target(
            name: "AwradDesignSystem",
            resources: [
                .copy("Resources/Fonts"), .copy("Resources/Images"), .process("Resources/Icons.xcassets"),
                .process("Resources/Localizable.xcstrings"),
            ],
            swiftSettings: ui
        ),
        .target(
            name: "FeatureOnboarding",
            dependencies: ["AwradDomain", "AwradDesignSystem"],
            resources: [.process("Resources")],
            swiftSettings: ui
        ),
        .target(
            name: "FeatureAccount",
            dependencies: ["AwradDomain", "AwradDesignSystem"],
            resources: [.process("Resources")],
            swiftSettings: ui
        ),
        .target(
            name: "FeatureLibrary",
            dependencies: ["AwradDomain", "AwradDesignSystem"],
            resources: [.process("Resources")],
            swiftSettings: ui
        ),
        .target(
            name: "FeaturePracticeSettings",
            dependencies: ["AwradDomain", "AwradDesignSystem"],
            resources: [.process("Resources")],
            swiftSettings: ui
        ),
        .target(name: "AwradTesting", dependencies: ["AwradDomain"], swiftSettings: strict),

        .testTarget(name: "AwradDomainTests", dependencies: ["AwradDomain", "AwradTesting"], swiftSettings: strict),
        .testTarget(
            name: "AwradDataTests",
            dependencies: ["AwradData", "AwradDomain", "AwradTesting"],
            swiftSettings: strict
        ),
        .testTarget(
            name: "AwradDesignSystemTests",
            dependencies: ["AwradDesignSystem", "AwradTesting"],
            swiftSettings: ui
        ),
        .testTarget(
            name: "FeatureOnboardingTests",
            dependencies: ["FeatureOnboarding", "AwradDomain", "AwradTesting"],
            swiftSettings: ui
        ),
        .testTarget(
            name: "FeatureAccountTests",
            dependencies: ["FeatureAccount", "AwradDomain", "AwradTesting"],
            swiftSettings: ui
        ),
        .testTarget(
            name: "FeatureLibraryTests",
            dependencies: ["FeatureLibrary", "AwradDomain", "AwradTesting"],
            swiftSettings: ui
        ),
        .testTarget(
            name: "FeaturePracticeSettingsTests",
            dependencies: ["FeaturePracticeSettings", "AwradDomain", "AwradTesting"],
            swiftSettings: ui
        ),
    ]
)
