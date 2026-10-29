import AwradDesignSystem
import SwiftUI

/// The layout every practice page shares: a title, then sections `sectionGap` apart, scrolling,
/// capped at the content width on an iPad.
struct PracticePage<Content: View>: View {
    let title: LocalizedStringResource
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AwradSpacing.sectionGap) {
                Text(title)
                    .awradTextStyle(.title)
                    .foregroundStyle(AwradColors.onSurface)
                    .accessibilityAddTraits(.isHeader)
                content
            }
            .frame(maxWidth: AwradSize.contentMaxWidth)
            .padding(.horizontal, AwradSpacing.pageMargin)
            .padding(.vertical, AwradSpacing.xl3)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AwradColors.background)
    }
}

/// A section's heading, read as a header.
struct SectionHeading: View {
    let title: LocalizedStringResource

    init(_ title: LocalizedStringResource) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .awradTextStyle(.sectionTitle)
            .foregroundStyle(AwradColors.onSurface)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Supporting text under a control.
struct Note: View {
    let text: LocalizedStringResource

    init(_ text: LocalizedStringResource) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .awradTextStyle(.bodySmall)
            .foregroundStyle(AwradColors.onSurfaceVariant)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Something the user should know about a setting (it falls back, or can't be done): the `error`
/// icon in `accent` and the text, on a `secondaryContainer` fill.
struct Hint: View {
    let text: LocalizedStringResource
    var tint = AwradColors.onSecondaryContainer

    init(_ text: LocalizedStringResource, tint: Color = AwradColors.onSecondaryContainer) {
        self.text = text
        self.tint = tint
    }

    var body: some View {
        HStack(alignment: .top, spacing: AwradSpacing.inlineGap) {
            AwradIconImage(.error, size: AwradSize.iconSmall)
            Text(text)
                .awradTextStyle(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(tint)
        .padding(AwradSpacing.cardPadding)
        .awradFill(.secondaryContainer, in: AwradRadius.tile)
        .accessibilityElement(children: .combine)
    }
}

/// A setting whose value opens its own page: the title, the value under it, and a chevron that
/// flips in right-to-left.
struct ValueRow: View {
    let title: LocalizedStringResource
    let value: Text
    let action: () -> Void

    var body: some View {
        AwradCardButton(AwradRadius.tile, action: action) {
            HStack(spacing: AwradSpacing.lg) {
                VStack(alignment: .leading, spacing: AwradSpacing.xxs) {
                    Text(title)
                        .awradTextStyle(.rowTitle)
                        .foregroundStyle(AwradColors.onSurface)
                    value
                        .awradTextStyle(.bodySmall)
                        .foregroundStyle(AwradColors.onSurfaceVariant)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                AwradIconImage(.chevron, size: AwradSize.iconSmall)
                    .foregroundStyle(AwradColors.onSurfaceVariant)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// A setting with two or three values side by side: heading, pills, and an optional note.
struct PillsSection<Value: Hashable>: View {
    let title: LocalizedStringResource
    let note: LocalizedStringResource?
    let selection: Binding<Value>
    let options: [AwradSegmentedPills<Value>.Option]

    var body: some View {
        VStack(alignment: .leading, spacing: AwradSpacing.sm) {
            SectionHeading(title)
            AwradSegmentedPills(selection: selection, options: options)
            if let note { Note(note) }
        }
    }
}

/// A city or place to pick: its name as written and where it is.
struct PlaceRow: View {
    let name: String
    let detail: Text?
    let action: () -> Void

    var body: some View {
        AwradCardButton(AwradRadius.tile, action: action) {
            VStack(alignment: .leading, spacing: AwradSpacing.xxs) {
                Text(verbatim: name)
                    .awradTextStyle(.rowTitle)
                    .foregroundStyle(AwradColors.onSurface)
                if let detail {
                    detail
                        .awradTextStyle(.bodySmall)
                        .foregroundStyle(AwradColors.onSurfaceVariant)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}
