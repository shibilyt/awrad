import Foundation

#if canImport(UIKit)
    import UIKit
#endif

/// The device name a session shows in the account's device list: the marketing name of the
/// model ("iPhone 16 Pro"), or the device family and its model identifier ("iPhone (iPhone19,1)")
/// for a model this table doesn't know yet. Never a constant like "Apple device" (slice 2
/// inventory row 8), and never the user-chosen device name, which is personal data.
public enum DeviceName {
    /// The name for this device. On the simulator, the simulated model.
    @MainActor public static func current() -> String {
        #if canImport(UIKit)
            readable(modelIdentifier: modelIdentifier(), family: UIDevice.current.model)
        #else
            readable(modelIdentifier: modelIdentifier(), family: "Mac")
        #endif
    }

    /// `modelIdentifier` mapped to its marketing name, else `family (modelIdentifier)`.
    public static func readable(modelIdentifier: String, family: String) -> String {
        if let name = marketingNames[modelIdentifier] { return name }
        let identifier = modelIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = family.isEmpty ? "Apple" : family
        return String((identifier.isEmpty ? fallback : "\(fallback) (\(identifier))").prefix(maximumLength))
    }

    /// The API's limit for `DeviceInfo.name`.
    public static let maximumLength = 120

    /// The hardware model identifier, such as `iPhone17,1`.
    static func modelIdentifier() -> String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulated
        }
        var system = utsname()
        uname(&system)
        return withUnsafeBytes(of: &system.machine) { bytes in
            String(bytes: bytes.prefix { $0 != 0 }, encoding: .utf8) ?? ""
        }
    }

    // The models iOS 18 runs on, and the iPads since 2022. Add new models as they ship; until
    // then they fall back to `family (identifier)`.
    static let marketingNames: [String: String] = [
        "iPhone11,2": "iPhone XS", "iPhone11,4": "iPhone XS Max", "iPhone11,6": "iPhone XS Max",
        "iPhone11,8": "iPhone XR",
        "iPhone12,1": "iPhone 11", "iPhone12,3": "iPhone 11 Pro", "iPhone12,5": "iPhone 11 Pro Max",
        "iPhone12,8": "iPhone SE (2nd generation)",
        "iPhone13,1": "iPhone 12 mini", "iPhone13,2": "iPhone 12", "iPhone13,3": "iPhone 12 Pro",
        "iPhone13,4": "iPhone 12 Pro Max",
        "iPhone14,4": "iPhone 13 mini", "iPhone14,5": "iPhone 13", "iPhone14,2": "iPhone 13 Pro",
        "iPhone14,3": "iPhone 13 Pro Max", "iPhone14,6": "iPhone SE (3rd generation)",
        "iPhone14,7": "iPhone 14", "iPhone14,8": "iPhone 14 Plus",
        "iPhone15,2": "iPhone 14 Pro", "iPhone15,3": "iPhone 14 Pro Max",
        "iPhone15,4": "iPhone 15", "iPhone15,5": "iPhone 15 Plus",
        "iPhone16,1": "iPhone 15 Pro", "iPhone16,2": "iPhone 15 Pro Max",
        "iPhone17,1": "iPhone 16 Pro", "iPhone17,2": "iPhone 16 Pro Max", "iPhone17,3": "iPhone 16",
        "iPhone17,4": "iPhone 16 Plus", "iPhone17,5": "iPhone 16e",
        "iPhone18,1": "iPhone 17 Pro", "iPhone18,2": "iPhone 17 Pro Max", "iPhone18,3": "iPhone 17",
        "iPhone18,4": "iPhone Air",
        "iPad13,18": "iPad (10th generation)", "iPad13,19": "iPad (10th generation)",
        "iPad14,3": "iPad Pro 11-inch (4th generation)", "iPad14,4": "iPad Pro 11-inch (4th generation)",
        "iPad14,5": "iPad Pro 12.9-inch (6th generation)", "iPad14,6": "iPad Pro 12.9-inch (6th generation)",
        "iPad14,8": "iPad Air 11-inch (M2)", "iPad14,9": "iPad Air 11-inch (M2)",
        "iPad14,10": "iPad Air 13-inch (M2)", "iPad14,11": "iPad Air 13-inch (M2)",
        "iPad15,3": "iPad Air 11-inch (M3)", "iPad15,4": "iPad Air 11-inch (M3)",
        "iPad15,5": "iPad Air 13-inch (M3)", "iPad15,6": "iPad Air 13-inch (M3)",
        "iPad15,7": "iPad (A16)", "iPad15,8": "iPad (A16)",
        "iPad16,1": "iPad mini (A17 Pro)", "iPad16,2": "iPad mini (A17 Pro)",
        "iPad16,3": "iPad Pro 11-inch (M4)", "iPad16,4": "iPad Pro 11-inch (M4)",
        "iPad16,5": "iPad Pro 13-inch (M4)", "iPad16,6": "iPad Pro 13-inch (M4)",
    ]
}
