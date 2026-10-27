import SwiftUI

// Previews of the ready-made motions, to try them before a screen uses them. Turn on Reduce Motion
// (Accessibility settings) to see each become the cross-fade.

#Preview("Count tap, ring fill, press") {
    MotionPreview()
}

#Preview("Expand, list appear, nav pill") {
    SectionPreview()
}

private struct MotionPreview: View {
    @State private var count = 0
    @Environment(\.awradMotion) private var motion

    var body: some View {
        VStack(spacing: AwradSpacing.sectionGap) {
            Text(count, format: .number)
                .awradTextStyle(.counter)
                .foregroundStyle(AwradColors.onSurface)
                .awradCountTap(value: count)
            ProgressView(value: Double(count % 34), total: 33)
                .tint(AwradColors.progress)
                .awradRingFill(value: count)
            Button {
                // Changing the count inside the animation is what makes the number roll.
                motion.animate(AwradMotion.CountTap.spring.animation) { count += 1 }
            } label: {
                Text(verbatim: "Count")
                    .awradTextStyle(.button)
                    .foregroundStyle(AwradColors.onPrimary)
                    .frame(maxWidth: .infinity, minHeight: AwradSize.control)
                    .background(AwradColors.primary, in: AwradRadius.button.shape)
            }
            .buttonStyle(.awradPress(.button))
            Button {
            } label: {
                Text(verbatim: "A pressable card")
                    .awradTextStyle(.rowTitle)
                    .foregroundStyle(AwradColors.onSurface)
                    .padding(AwradSpacing.cardPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .awradCard()
            }
            .buttonStyle(.awradPress(.card))
        }
        .padding(AwradSpacing.pageMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AwradColors.background)
        .onAppear { AwradFonts.register() }
    }
}

private struct SectionPreview: View {
    @State private var isExpanded = false
    @State private var selectedTab = 0

    var body: some View {
        VStack(alignment: .leading, spacing: AwradSpacing.sectionGap) {
            VStack(alignment: .leading, spacing: AwradSpacing.rowGap) {
                Button {
                    isExpanded.toggle()
                } label: {
                    HStack {
                        Text(verbatim: "Section").awradTextStyle(.cardTitle)
                        Spacer()
                        AwradIconImage(.expand).awradChevron(isExpanded: isExpanded)
                    }
                }
                .buttonStyle(.awradPress(.card))
                if isExpanded {
                    ForEach(0..<8, id: \.self) { index in
                        Text(verbatim: "Row \(index + 1)")
                            .awradTextStyle(.body)
                            .awradListAppear(index: index)
                    }
                    .awradExpandingContent()
                }
            }
            .padding(AwradSpacing.cardPadding)
            .awradCard()
            .awradExpand(value: isExpanded)
            HStack(spacing: AwradSpacing.sm) {
                ForEach(0..<3, id: \.self) { tab in
                    AwradIconImage([AwradIcon.home, .goals, .library][tab])
                        .awradNavIcon(isSelected: selectedTab == tab)
                        .frame(width: AwradSize.touchTarget, height: AwradSize.touchTarget)
                        .background {
                            AwradRadius.navPill.shape.fill(AwradColors.primaryContainer)
                                .awradNavPill(isSelected: selectedTab == tab)
                        }
                        .onTapGesture { selectedTab = tab }
                }
            }
            .awradHaptic(.tick, trigger: selectedTab)
        }
        .foregroundStyle(AwradColors.onSurface)
        .padding(AwradSpacing.pageMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AwradColors.background)
    }
}
