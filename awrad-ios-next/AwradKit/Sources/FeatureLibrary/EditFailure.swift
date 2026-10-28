import AwradDomain

/// Why an edit didn't happen, as the screens say it. Nothing changed.
enum EditFailure: Equatable, Sendable {
    case tagNameEmpty
    case tagNameTooLong
    case tagNameTooManyBytes
    case tagNameTaken
    case tagLimitReached
    case tooManyTagsOnDhikr
    case customDhikrLimitReached
    case notFound
    case audioTooLarge
    case audioUnsupported
    /// The picker couldn't hand over the file.
    case audioUnreadable
    case invalidDhikr
    case storage

    init(_ error: PersonalLibraryError) {
        switch error {
        case .invalidDhikr: self = .invalidDhikr
        case .invalidTagName(.empty): self = .tagNameEmpty
        case .invalidTagName(.tooManyGraphemes): self = .tagNameTooLong
        case .invalidTagName(.tooManyBytes): self = .tagNameTooManyBytes
        case .tagNameTaken: self = .tagNameTaken
        case .tagLimitReached: self = .tagLimitReached
        case .tooManyTagsOnDhikr: self = .tooManyTagsOnDhikr
        case .customDhikrLimitReached: self = .customDhikrLimitReached
        case .notFound: self = .notFound
        case .audioTooLarge: self = .audioTooLarge
        case .audioUnsupported: self = .audioUnsupported
        case .storage: self = .storage
        }
    }
}
