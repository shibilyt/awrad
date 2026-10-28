import SwiftUI

/// components.md "Conflict banner": at the top of a page while what it shows has an open conflict.
/// A `card`-shaped card with `cardPadding`, filled `secondaryContainer` (never the `error` roles):
/// the `error` icon (`icon` size) at the start, then the message in `body`, both
/// `onSecondaryContainer`; under them, the two text buttons aligned to the end, their labels also
/// `onSecondaryContainer` (`awradFill`). `detail` (a tag's
/// name, say) is a second line under the message.
public struct AwradConflictBanner: View {
    private let message: LocalizedStringResource
    private let detail: String?
    private let keepMine: LocalizedStringResource
    private let useTheirs: LocalizedStringResource
    private let onKeepMine: () -> Void
    private let onUseTheirs: () -> Void

    public init(
        _ message: LocalizedStringResource, detail: String? = nil, keepMine: LocalizedStringResource,
        useTheirs: LocalizedStringResource, onKeepMine: @escaping () -> Void, onUseTheirs: @escaping () -> Void
    ) {
        self.message = message
        self.detail = detail
        self.keepMine = keepMine
        self.useTheirs = useTheirs
        self.onKeepMine = onKeepMine
        self.onUseTheirs = onUseTheirs
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: AwradSpacing.sm) {
            HStack(alignment: .top, spacing: AwradSpacing.md) {
                AwradIconImage(.error)
                VStack(alignment: .leading, spacing: AwradSpacing.xxs) {
                    Text(message)
                        .awradTextStyle(.body)
                    if let detail {
                        Text(verbatim: detail)
                            .awradTextStyle(.body)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .foregroundStyle(AwradColors.onSecondaryContainer)
            .accessibilityElement(children: .combine)
            HStack(spacing: AwradSpacing.sm) {
                AwradButton(keepMine, variant: .text, layout: .row, action: onKeepMine)
                AwradButton(useTheirs, variant: .text, layout: .row, action: onUseTheirs)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(AwradSpacing.cardPadding)
        // Keep mine and Use theirs in `onSecondaryContainer`: `accent` would vanish on it in dark mode.
        .awradFill(.secondaryContainer, in: AwradRadius.card)
        .awradDisabledAppearance()
    }
}

#Preview("Conflict banner") {
    VStack(spacing: AwradSpacing.lg) {
        AwradConflictBanner(
            "Changed on another device", keepMine: "Keep mine", useTheirs: "Use theirs", onKeepMine: {},
            onUseTheirs: {})
        AwradConflictBanner(
            "Changed on another device", detail: "Morning", keepMine: "Keep mine", useTheirs: "Use theirs",
            onKeepMine: {}, onUseTheirs: {})
    }
    .padding(AwradSpacing.pageMargin)
    .background(AwradColors.background)
}
