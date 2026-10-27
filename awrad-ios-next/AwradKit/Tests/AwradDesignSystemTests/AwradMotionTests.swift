import Foundation
import SwiftUI
import Testing

@testable import AwradDesignSystem

/// The generated motion matches contracts/design-tokens/v1/motion.json, springs converted with
/// response = 2π / √stiffness and dampingFraction = dampingRatio; and reduced motion turns every
/// movement into the cross-fade.
struct AwradMotionTests {
    private static let tolerance = 1e-6

    private static func motion() throws -> [String: Any] {
        try DesignTokenContract.json("motion")
    }

    /// (response, dampingFraction) for a contract spring, by the README's conversion.
    fileprivate static func converted(_ spring: [String: Any]) throws -> (Double, Double) {
        let stiffness = try DesignTokenContract.number(spring["stiffness"], "stiffness")
        let dampingRatio = try DesignTokenContract.number(spring["dampingRatio"], "dampingRatio")
        return (2 * Double.pi / stiffness.squareRoot(), dampingRatio)
    }

    @Test func durationsAreTheContractsInSeconds() throws {
        let durations = try DesignTokenContract.object(Self.motion()["duration"], "duration")
            .mapValues { try DesignTokenContract.number($0, "duration") / 1000 }
        #expect(DesignTokenContract.dictionary(AwradMotion.durations) == durations)
    }

    @Test func easingsAreTheContractsControlPoints() throws {
        let easings = try DesignTokenContract.object(Self.motion()["easing"], "easing")
        let generated = DesignTokenContract.dictionary(AwradMotion.easings)
        #expect(Set(generated.keys) == Set(easings.keys))
        for (name, points) in easings {
            let expected = try #require(points as? [Double], "easing \(name)")
            let curve = try #require(generated[name])
            #expect([curve.x1, curve.y1, curve.x2, curve.y2] == expected, "\(name)")
        }
    }

    @Test func springsAreConvertedForSwiftUI() throws {
        let springs = try DesignTokenContract.object(Self.motion()["spring"], "spring")
        let generated = DesignTokenContract.dictionary(AwradMotion.springs)
        #expect(Set(generated.keys) == Set(springs.keys))
        for (name, value) in springs {
            let (response, dampingFraction) = try Self.converted(DesignTokenContract.object(value, name))
            let spring = try #require(generated[name])
            #expect(abs(spring.response - response) < Self.tolerance, "\(name) response")
            #expect(spring.dampingFraction == dampingFraction, "\(name) dampingFraction")
        }
        // A worked example: spatial (0.8, 380) is response 2π/√380 ≈ 0.3223 s.
        #expect(abs(AwradMotion.Spring.spatial.response - 0.322_321) < Self.tolerance)
    }

    @Test func hapticsFollowTheContractsIOSMapping() throws {
        let haptics = try DesignTokenContract.object(Self.motion()["haptic"], "haptic")
        #expect(Set(AwradHaptic.allCases.map(\.rawValue)) == Set(haptics.keys))
        #expect(AwradHaptic.tick.feedback == .selection)
        #expect(AwradHaptic.threshold.feedback == .impact(weight: .medium))
        #expect(AwradHaptic.success.feedback == .success)
    }

    @Test func everyIOSMotionIsGeneratedWithItsValues() throws {
        let tokens = try Self.motion()
        let motions = try DesignTokenContract.object(tokens["motions"], "motions").filter { _, spec in
            ((spec as? [String: Any])?["platforms"] as? [String])?.contains("ios") == true
        }
        #expect(Set(AwradMotion.motions) == Set(motions.keys))

        var expected = ExpectedMotions(tokens: tokens)
        for (name, spec) in motions {
            for (key, value) in try DesignTokenContract.object(spec, name) where key != "platforms" && key != "use" {
                if let nested = value as? [String: Any] {
                    for (innerKey, innerValue) in nested {
                        try expected.add("\(name).\(key).\(innerKey)", key: innerKey, value: innerValue)
                    }
                } else {
                    try expected.add("\(name).\(key)", key: key, value: value)
                }
            }
        }
        let generated = DesignTokenContract.dictionary(AwradMotion.motionNumbers)
        #expect(Set(generated.keys) == Set(expected.numbers.keys))
        for (path, number) in expected.numbers {
            let actual = try #require(generated[path], "\(path) isn't generated")
            #expect(abs(actual - number) < Self.tolerance, "\(path): \(actual) isn't \(number)")
        }
        #expect(DesignTokenContract.dictionary(AwradMotion.motionNames) == expected.names)
    }

    /// What the named motions' contract values should become, references resolved.
    private struct ExpectedMotions {
        let tokens: [String: Any]
        var numbers: [String: Double] = [:]
        var names: [String: String] = [:]

        mutating func add(_ path: String, key: String, value: Any) throws {
            if value is NSNumber {
                let number = try DesignTokenContract.number(value, path)
                numbers[path] = key == "stagger" ? number / 1000 : number  // stagger is in ms
                return
            }
            let name = try DesignTokenContract.string(value, path)
            if key == "spring" || key.hasSuffix("Spring") {
                let spring = try DesignTokenContract.object(
                    DesignTokenContract.object(tokens["spring"], "spring")[name], name)
                let (response, dampingFraction) = try AwradMotionTests.converted(spring)
                numbers["\(path).response"] = response
                numbers["\(path).dampingFraction"] = dampingFraction
            } else if key == "easing" {
                let points = try #require(DesignTokenContract.object(tokens["easing"], "easing")[name] as? [Double])
                for (index, point) in points.enumerated() { numbers["\(path).\(index)"] = point }
            } else if key == "radius" {
                let shape = try DesignTokenContract.json("shape")
                let roles = try DesignTokenContract.object(shape["roles"], "roles")
                let step = try DesignTokenContract.string(DesignTokenContract.object(roles[name], name)["radius"], name)
                numbers[path] = try DesignTokenContract.number(
                    DesignTokenContract.object(shape["scale"], "scale")[step], step)
            } else if key == "haptic" || key == "numberTransition" {
                names[path] = name
            } else {
                let durations = try DesignTokenContract.object(tokens["duration"], "duration")
                numbers[path] = try DesignTokenContract.number(durations[name], "\(path) names \(name)") / 1000
            }
        }
    }

    // MARK: - Reduced motion

    @Test func reducedMotionIsTheContractsCrossFade() throws {
        let reduced = try DesignTokenContract.object(Self.motion()["reducedMotion"], "reducedMotion")
        let durations = try DesignTokenContract.object(Self.motion()["duration"], "duration")
        let duration = try DesignTokenContract.number(
            durations[DesignTokenContract.string(reduced["duration"], "duration")], "duration")
        #expect(try DesignTokenContract.string(reduced["replaceWith"], "replaceWith") == "crossfade")
        #expect(AwradMotion.ReducedMotion.duration == duration / 1000)
        #expect(AwradMotionPolicy.crossFade == .easeInOut(duration: duration / 1000))
    }

    @Test func withReducedMotionEveryMovementBecomesTheCrossFade() {
        let reduced = AwradMotionPolicy(reduceMotion: true)
        let spring = AwradMotion.Press.releaseSpring
        #expect(reduced.animation(spring) == AwradMotionPolicy.crossFade)
        #expect(reduced.animation(AwradMotion.Easing.emphasized.animation(duration: 1)) == AwradMotionPolicy.crossFade)
        #expect(reduced.scale(AwradMotion.Press.buttonScale) == 1)
        #expect(reduced.scale(AwradMotion.CountTap.popScale) == 1)
        #expect(reduced.offset(AwradMotion.ListAppear.offset) == 0)
    }

    @Test func withoutReducedMotionMotionPlaysAsDesigned() {
        let full = AwradMotionPolicy(reduceMotion: false)
        let spring = AwradMotion.Press.releaseSpring
        #expect(full.animation(spring) == spring.animation)
        #expect(full.scale(AwradMotion.Press.cardScale) == AwradMotion.Press.cardScale)
        #expect(full.offset(AwradMotion.ListAppear.offset) == AwradMotion.ListAppear.offset)
    }

    @Test func screensReadThePolicyFromTheSystemSetting() {
        #expect(EnvironmentValues().awradMotion == AwradMotionPolicy(reduceMotion: false))
    }

    @Test func animateRunsTheBodyAndReturnsItsResult() {
        var count = 0
        let result = AwradMotionPolicy(reduceMotion: true).animate(AwradMotion.CountTap.spring.animation) {
            count += 1
            return count
        }
        #expect(result == 1)
    }
}
