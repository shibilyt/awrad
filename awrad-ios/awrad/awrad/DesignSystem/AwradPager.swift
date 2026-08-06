import SwiftUI

struct AwradPagerTabs<Selection: Hashable>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding private var selection: Selection
    private let options: [Selection]
    private let position: CGFloat
    private let title: (Selection) -> String
    private let coordinateSpaceName = "AwradPagerTabs"
    @State private var tabCenters: [AnyHashable: CGFloat] = [:]

    init(
        selection: Binding<Selection>,
        options: [Selection],
        position: CGFloat,
        title: @escaping (Selection) -> String
    ) {
        _selection = selection
        self.options = options
        self.position = position
        self.title = title
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                ForEach(Array(options.enumerated()), id: \.element) { index, option in
                    tab(option, index: index)
                }
            }
            .coordinateSpace(name: coordinateSpaceName)

            Color.clear
                .frame(height: 12)
                .accessibilityHidden(true)
        }
        .overlay(alignment: .bottomLeading) {
            if let center = indicatorCenter {
                Capsule()
                    .fill(AwradTheme.sage)
                    .frame(width: 24, height: 4)
                    .offset(x: center - 12, y: -1)
                    .accessibilityHidden(true)
            }
        }
        .onPreferenceChange(AwradPagerCenterPreferenceKey.self) { centers in
            tabCenters = centers
        }
        .accessibilityElement(children: .contain)
    }

    private func tab(_ option: Selection, index: Int) -> some View {
        let selectedness = AwradPagerMotion.selectedness(index: index, position: position)
        let localizedTitle = LocalizedStringKey(title(option))

        return Button {
            guard selection != option else { return }
            if reduceMotion {
                selection = option
            } else {
                withAnimation(.snappy(duration: 0.32)) {
                    selection = option
                }
            }
        } label: {
            ZStack {
                Text(localizedTitle)
                    .foregroundStyle(AwradTheme.subdued)
                    .opacity(1 - selectedness)
                Text(localizedTitle)
                    .foregroundStyle(.white)
                    .opacity(selectedness)
            }
            .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
            .lineLimit(1)
            .padding(.horizontal, 22)
            .frame(minHeight: 44)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .background {
            ZStack {
                Capsule()
                    .fill(AwradTheme.background)
                Capsule()
                    .fill(AwradTheme.sage)
                    .opacity(selectedness)
            }
        }
        .scaleEffect(0.97 + (0.03 * selectedness))
        .background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: AwradPagerCenterPreferenceKey.self,
                    value: [
                        AnyHashable(option): proxy.frame(in: .named(coordinateSpaceName)).midX
                    ]
                )
            }
        }
        .accessibilityLabel(Text(localizedTitle))
        .accessibilityAddTraits(selection == option ? .isSelected : [])
    }

    private var indicatorCenter: CGFloat? {
        AwradPagerMotion.interpolatedCenter(
            position: position,
            centers: options.compactMap { tabCenters[AnyHashable($0)] }
        )
    }
}

struct AwradPager<Selection: Hashable, Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding private var selection: Selection
    @Binding private var position: CGFloat
    private let options: [Selection]
    private let accessibilityIdentifier: String
    private let content: (Selection) -> Content
    private let coordinateSpaceName: String
    @State private var scrollPosition: Selection?

    init(
        selection: Binding<Selection>,
        options: [Selection],
        position: Binding<CGFloat>,
        accessibilityIdentifier: String,
        @ViewBuilder content: @escaping (Selection) -> Content
    ) {
        _selection = selection
        _position = position
        self.options = options
        self.accessibilityIdentifier = accessibilityIdentifier
        self.content = content
        coordinateSpaceName = "\(accessibilityIdentifier).coordinateSpace"
        _scrollPosition = State(initialValue: selection.wrappedValue)
    }

    var body: some View {
        GeometryReader { container in
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(options, id: \.self) { option in
                        content(option)
                            .frame(width: container.size.width, height: container.size.height)
                            .background {
                                GeometryReader { proxy in
                                    Color.clear.preference(
                                        key: AwradPagerCenterPreferenceKey.self,
                                        value: [
                                            AnyHashable(option): proxy.frame(
                                                in: .named(coordinateSpaceName)
                                            ).midX
                                        ]
                                    )
                                }
                            }
                            .id(option)
                    }
                }
                .scrollTargetLayout()
            }
            .coordinateSpace(name: coordinateSpaceName)
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $scrollPosition)
            .scrollDisabled(options.count < 2)
            .onPreferenceChange(AwradPagerCenterPreferenceKey.self) { centers in
                updatePosition(from: centers, pageWidth: container.size.width)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(accessibilityIdentifier)
        .onAppear {
            scrollPosition = selection
            position = selectedIndex
        }
        .onChange(of: selection) { _, newSelection in
            guard scrollPosition != newSelection else { return }
            if reduceMotion {
                scrollPosition = newSelection
                position = selectedIndex
            } else {
                withAnimation(.snappy(duration: 0.32)) {
                    scrollPosition = newSelection
                    position = selectedIndex
                }
            }
        }
        .onChange(of: scrollPosition) { _, newSelection in
            guard let newSelection, selection != newSelection else { return }
            selection = newSelection
        }
    }

    private var selectedIndex: CGFloat {
        CGFloat(options.firstIndex(of: selection) ?? 0)
    }

    private func updatePosition(from centers: [AnyHashable: CGFloat], pageWidth: CGFloat) {
        guard pageWidth > 0 else { return }
        let viewportCenter = pageWidth / 2
        var weightedPosition: CGFloat = 0
        var totalWeight: CGFloat = 0

        for (index, option) in options.enumerated() {
            guard let center = centers[AnyHashable(option)] else { continue }
            let weight = max(0, 1 - abs(center - viewportCenter) / pageWidth)
            weightedPosition += CGFloat(index) * weight
            totalWeight += weight
        }

        guard totalWeight > 0 else { return }
        position = AwradPagerMotion.clampedPosition(
            weightedPosition / totalWeight,
            pageCount: options.count
        )
    }
}

enum AwradPagerMotion {
    static func clampedPosition(_ position: CGFloat, pageCount: Int) -> CGFloat {
        min(max(position, 0), CGFloat(max(pageCount - 1, 0)))
    }

    static func selectedness(index: Int, position: CGFloat) -> CGFloat {
        min(max(1 - abs(position - CGFloat(index)), 0), 1)
    }

    static func interpolatedCenter(position: CGFloat, centers: [CGFloat]) -> CGFloat? {
        guard !centers.isEmpty else { return nil }
        let clamped = clampedPosition(position, pageCount: centers.count)
        let lowerIndex = Int(floor(clamped))
        let upperIndex = Int(ceil(clamped))
        guard lowerIndex != upperIndex else { return centers[lowerIndex] }
        let fraction = clamped - CGFloat(lowerIndex)
        return centers[lowerIndex] + ((centers[upperIndex] - centers[lowerIndex]) * fraction)
    }
}

private struct AwradPagerCenterPreferenceKey: PreferenceKey {
    static let defaultValue: [AnyHashable: CGFloat] = [:]

    static func reduce(
        value: inout [AnyHashable: CGFloat],
        nextValue: () -> [AnyHashable: CGFloat]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
