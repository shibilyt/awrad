import Foundation

/// Why an upload is refused (`$defs/upload_error`), in the order the checks run.
public enum AudioUploadError: String, Error, CaseIterable, Sendable, Hashable {
    case unsupportedAudioType = "unsupported_audio_type"
    case invalidSize = "invalid_size"
    case fileTooLarge = "file_too_large"
    case storageFull = "storage_full"
}

/// Storage an account's recordings use (`get_audio_usage`): ready assets and pending uploads, by
/// their declared size, and the account's limit.
public struct AudioUsage: Hashable, Sendable {
    public let usedBytes: Int
    public let limitBytes: Int

    public init(usedBytes: Int, limitBytes: Int) {
        self.usedBytes = usedBytes
        self.limitBytes = limitBytes
    }

    /// An amount in whole decimal megabytes, as the limits are written ("120 MB" for 120,482,733
    /// bytes), rounded down so a nearly full account never reads as full, in the locale's digits.
    public static func megabytes(_ bytes: Int, locale: Locale) -> String {
        let value = (Double(bytes) / 1_000_000).rounded(.down)
        let style = Measurement<UnitInformationStorage>.FormatStyle(
            width: .abbreviated, locale: locale, usage: .asProvided,
            numberFormatStyle: .number.precision(.fractionLength(0)).locale(locale))
        return Measurement(value: value, unit: UnitInformationStorage.megabytes).formatted(style)
    }
}

/// Whether an account may upload a recording (contracts/audio/v1/fixtures/audio_upload_validity.json).
/// Clients check before reserving an upload; `create_audio_upload` enforces the same rules.
public enum AudioUploadRules {
    /// 10 MB per file, decimal (10 MiB is too large).
    public static let maxFileBytes = 10_000_000
    /// 500 MB per account, ready and pending uploads together.
    public static let accountLimitBytes = 500_000_000

    /// The first rule the upload breaks, or `nil` when it's allowed: the type (exactly
    /// `audio/mpeg` or `audio/mp4`), then the size (1 to 10,000,000 bytes), then the quota
    /// (`usedBytes + byteSize` at most `limitBytes`; exactly full is allowed).
    public static func check(
        byteSize: Int, contentType: String, usedBytes: Int, limitBytes: Int = accountLimitBytes
    ) -> AudioUploadError? {
        guard AudioContentType(rawValue: contentType) != nil else { return .unsupportedAudioType }
        if byteSize < 1 { return .invalidSize }
        if byteSize > maxFileBytes { return .fileTooLarge }
        // Subtraction keeps a huge `usedBytes` from overflowing.
        if byteSize > limitBytes - usedBytes { return .storageFull }
        return nil
    }
}
