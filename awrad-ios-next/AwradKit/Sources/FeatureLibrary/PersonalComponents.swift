import AwradDesignSystem
import AwradDomain
import SwiftUI

/// What the Library's routes need from the app beyond the model: the user's library and a player
/// for each dhikr screen.
struct LibraryServices {
    let library: any PersonalLibrary
    let makePlayer: @MainActor () -> any DhikrAudioPlayer
}

/// A user's tag, or a catalog tag, to show as a chip.
struct TagChipItem: Identifiable, Equatable {
    let id: String
    let title: String
}

/// Tag chips, `sm` apart, wrapping onto more lines when they don't fit.
struct TagChips: View {
    let items: [TagChipItem]

    var body: some View {
        FlowLayout(spacing: AwradSpacing.sm) {
            ForEach(items) { TagChip(title: $0.title) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A tag (components.md, "Tag chip"): `label` text in a `chip`, filled like a secondary control.
struct TagChip: View {
    let title: String
    @Environment(\.awradContainer) private var container

    var body: some View {
        Text(verbatim: title)
            .awradTextStyle(.label)
            .foregroundStyle(container.onSecondaryFill)
            .padding(.horizontal, AwradSpacing.md)
            .padding(.vertical, AwradSpacing.xs)
            .background(container.secondaryFill, in: AwradRadius.chip.shape)
    }
}

/// Lays its children out in lines, starting a new line when one doesn't fit; follows the layout
/// direction.
struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let lines = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let width = lines.map(\.width).max() ?? 0
        let height = lines.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(lines.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let isRightToLeft = subviews.layoutDirection == .rightToLeft
        var y = bounds.minY
        for line in arrange(width: bounds.width, subviews: subviews) {
            var x = isRightToLeft ? bounds.maxX : bounds.minX
            for item in line.items {
                let origin = CGPoint(x: isRightToLeft ? x - item.size.width : x, y: y)
                subviews[item.index].place(at: origin, proposal: ProposedViewSize(item.size))
                x += (isRightToLeft ? -1 : 1) * (item.size.width + spacing)
            }
            y += line.height + spacing
        }
    }

    private struct Item {
        let index: Int
        let size: CGSize
    }

    private struct Line {
        var items: [Item] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Line] {
        var lines: [Line] = []
        var line = Line()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(ProposedViewSize(width: width, height: nil))
            let needed = line.items.isEmpty ? size.width : line.width + spacing + size.width
            if needed > width, !line.items.isEmpty {
                lines.append(line)
                line = Line()
            }
            line.width = line.items.isEmpty ? size.width : line.width + spacing + size.width
            line.height = max(line.height, size.height)
            line.items.append(Item(index: index, size: size))
        }
        if !line.items.isEmpty { lines.append(line) }
        return lines
    }
}

/// "Changed on another device": the dhikr or tag was changed here and elsewhere. Keep mine or Use
/// theirs. `name` is the tag's name when it's about a tag.
struct ConflictCard: View {
    let name: String?
    let onKeepMine: () -> Void
    let onUseTheirs: () -> Void

    var body: some View {
        AwradCard {
            VStack(alignment: .leading, spacing: AwradSpacing.xs) {
                Text(Strings.conflictTitle)
                    .awradTextStyle(.cardTitle)
                    .foregroundStyle(AwradColors.onSurface)
                    .accessibilityAddTraits(.isHeader)
                if let name {
                    Text(verbatim: name)
                        .awradTextStyle(.rowTitle)
                        .foregroundStyle(AwradColors.onSurface)
                }
                Text(Strings.conflictBody)
                    .awradTextStyle(.body)
                    .foregroundStyle(AwradColors.onSurfaceVariant)
            }
            .accessibilityElement(children: .combine)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: AwradSpacing.sm) { buttons }
                VStack(alignment: .leading, spacing: AwradSpacing.sm) { buttons }
            }
        }
    }

    @ViewBuilder private var buttons: some View {
        AwradButton(Strings.keepMine, variant: .secondary, layout: .row, action: onKeepMine)
        AwradButton(Strings.useTheirs, variant: .secondary, layout: .row, action: onUseTheirs)
    }
}

/// A rejected change that was undone, with the reason, until the user dismisses it.
struct NoticeCard: View {
    let notice: SyncNotice
    let onDismiss: () -> Void

    var body: some View {
        AwradCard {
            VStack(alignment: .leading, spacing: AwradSpacing.xs) {
                Text(Strings.noticeTitle(notice.key.type))
                    .awradTextStyle(.cardTitle)
                    .foregroundStyle(AwradColors.onSurface)
                    .accessibilityAddTraits(.isHeader)
                Text(Strings.noticeReason(notice.code))
                    .awradTextStyle(.body)
                    .foregroundStyle(AwradColors.onSurfaceVariant)
            }
            .accessibilityElement(children: .combine)
            AwradButton(Strings.dismiss, variant: .text, layout: .row, action: onDismiss)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

/// Why an edit didn't happen, in `error` text.
struct FailureText: View {
    let failure: EditFailure

    var body: some View {
        Text(Strings.message(failure))
            .awradTextStyle(.caption)
            .foregroundStyle(AwradColors.error)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A labelled text field in the `field` style: one line, or several that grow with the text.
/// Arabic fields type right to left. An error shows under the field, and is read with it.
struct LabeledField: View {
    enum Kind {
        case line
        case multiline
        case number
    }

    let label: LocalizedStringResource
    let text: String
    let onChange: (String) -> Void
    var error: LocalizedStringResource?
    var kind = Kind.line
    var isArabic = false

    var body: some View {
        VStack(alignment: .leading, spacing: AwradSpacing.xs) {
            Text(label)
                .awradTextStyle(.label)
                .foregroundStyle(AwradColors.onSurface)
                .accessibilityHidden(true)
            field
                .padding(.vertical, kind == .multiline ? AwradSpacing.md : AwradSpacing.none)
                .awradField(isInError: error != nil)
                .accessibilityHint(error.map { Text($0) } ?? Text(verbatim: ""))
            if let error {
                Text(error)
                    .awradTextStyle(.caption)
                    .foregroundStyle(AwradColors.error)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var field: some View {
        let binding = Binding(get: { text }, set: { onChange($0) })
        let field = TextField(text: binding, axis: kind == .multiline ? .vertical : .horizontal) { Text(label) }
        if isArabic {
            field
                .lineLimit(kind == .multiline ? 1...8 : 1...1)
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Locale(identifier: "ar"))
        } else if kind == .number {
            #if os(iOS)
                field.keyboardType(.numberPad)
            #else
                field
            #endif
        } else {
            field.lineLimit(kind == .multiline ? 1...8 : 1...1)
        }
    }
}
