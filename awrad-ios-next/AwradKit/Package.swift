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
    ],
    targets: [
        .target(name: "AwradDomain", swiftSettings: strict),
        .target(name: "AwradData", dependencies: ["AwradDomain"], swiftSettings: strict),
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
    ]
)
