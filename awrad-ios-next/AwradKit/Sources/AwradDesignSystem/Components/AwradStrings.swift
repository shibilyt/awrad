import Foundation

/// The design system's own strings (accessibility labels and values), from
/// `Resources/Localizable.xcstrings` in en, ar and ml. The default value is the English text.
enum AwradStrings {
    static let bundle = LocalizedStringResource.BundleDescription.atURL(Bundle.module.bundleURL)

    /// The back icon button.
    static let back = LocalizedStringResource("ds.back", defaultValue: "Back", bundle: bundle)
    /// The three-dot menu icon button.
    static let more = LocalizedStringResource("ds.more", defaultValue: "More options", bundle: bundle)
    /// The close icon button of a sheet or dialog.
    static let close = LocalizedStringResource("ds.close", defaultValue: "Close", bundle: bundle)
    /// The text field button that shows a hidden password.
    static let showPassword = LocalizedStringResource("ds.show_password", defaultValue: "Show password", bundle: bundle)
    /// The text field button that hides a shown password.
    static let hidePassword = LocalizedStringResource("ds.hide_password", defaultValue: "Hide password", bundle: bundle)
    /// A button whose action is running: read as its value.
    static let loading = LocalizedStringResource("ds.loading", defaultValue: "Loading", bundle: bundle)

    /// The step indicator, read as one element: "Step 2 of 7".
    static func step(_ current: Int, of total: Int) -> LocalizedStringResource {
        LocalizedStringResource("ds.step_indicator", defaultValue: "Step \(current) of \(total)", bundle: bundle)
    }
}
