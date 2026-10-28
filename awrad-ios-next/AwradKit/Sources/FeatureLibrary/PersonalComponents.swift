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

/// "Changed on another device" (components.md "Conflict banner"): the dhikr or tag was changed here
/// and elsewhere. Keep mine or Use theirs. `name` is the tag's name when it's about a tag.
struct ConflictBanner: View {
    let name: String?
    let onKeepMine: () -> Void
    let onUseTheirs: () -> Void

    var body: some View {
        AwradConflictBanner(
            Strings.conflictTitle, detail: name, keepMine: Strings.keepMine, useTheirs: Strings.useTheirs,
            onKeepMine: onKeepMine, onUseTheirs: onUseTheirs)
    }
}

extension View {
    /// components.md "Change refused" notice: while the server has refused changes (each already
    /// undone), a dialog with the first one's reason and a single OK that dismisses it.
    func changeRefusedNotice(_ notices: [SyncNotice], dismiss: @escaping (SyncNotice) -> Void) -> some View {
        let notice = notices.first
        return awradDialog(
            isPresented: Binding(get: { notice != nil }, set: { if !$0, let notice { dismiss(notice) } }),
            title: Strings.changeRefused, message: notice.map { Strings.noticeReason($0.code) }
        ) {
            AwradButton(Strings.ok, variant: .text, layout: .row) {
                if let notice { dismiss(notice) }
            }
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

/// A labelled `AwradTextField`: one line, a number, or the multi-line field that grows with its text
/// (components.md "Multi-line text field"). Arabic fields type right to left. An error shows under the
/// field, and is read with it.
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
        let field = AwradTextField(
            label, text: Binding(get: { text }, set: { onChange($0) }), error: error,
            axis: kind == .multiline ? .vertical : .horizontal, isRightToLeft: isArabic)
        #if os(iOS)
            if kind == .number {
                field.keyboardType(.numberPad)
            } else {
                field
            }
        #else
            field
        #endif
    }
}
