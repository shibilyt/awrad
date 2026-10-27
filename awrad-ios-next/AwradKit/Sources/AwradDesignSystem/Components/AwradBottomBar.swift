import SwiftUI

/// One tab of the bottom bar: its icon (`home`, `goals`, `library`, `community`) over its label.
public struct AwradBottomBarItem<Tab: Hashable> {
    public let tab: Tab
    public let title: LocalizedStringResource
    public let icon: AwradIcon

    public init(_ tab: Tab, title: LocalizedStringResource, icon: AwradIcon) {
        self.tab = tab
        self.title = title
        self.icon = icon
    }
}

/// The floating main navigation (Home, Goals, Library, Community): `navBar` (72) tall, `surfaceBar`
/// in the `navBar` shape with the `floating` shadow (none in dark). Items have equal widths; the
/// selected one has the `primaryContainer` pill behind its icon, which grows in (`navPill`) while the
/// icon pops, with a `tick`. The icon is the same outline icon selected or not: the pill shows the
/// selection. VoiceOver reads a tab bar with each tab's selected state. It mirrors in right-to-left.
/// Place it with `awradBottomBar(selection:items:)`.
public struct AwradBottomBar<Tab: Hashable>: View {
    @Binding private var selection: Tab
    private let items: [AwradBottomBarItem<Tab>]

    public init(selection: Binding<Tab>, items: [AwradBottomBarItem<Tab>]) {
        _selection = selection
        self.items = items
    }

    public var body: some View {
        HStack(spacing: AwradSpacing.none) {
            ForEach(items, id: \.tab) { item in
                BottomBarItemView(item: item, isSelected: item.tab == selection) {
                    selection = item.tab
                }
            }
        }
        .padding(.horizontal, AwradSpacing.sm)
        .frame(maxWidth: .infinity, minHeight: AwradSize.navBar)
        .background(AwradColors.surfaceBar, in: AwradRadius.navBar.shape)
        .awradElevation(AwradElevation.floating)
        .awradHaptic(AwradHaptic.tick, trigger: selection)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isTabBar)
    }
}

private struct BottomBarItemView<Tab: Hashable>: View {
    let item: AwradBottomBarItem<Tab>
    let isSelected: Bool
    let action: () -> Void

    private var colorChange: Animation {
        AwradMotion.Easing.linear.animation(duration: AwradMotion.NavPill.colorDuration)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: AwradSpacing.xs) {
                ZStack {
                    AwradRadius.navPill.shape
                        .fill(AwradColors.primaryContainer)
                        .frame(width: AwradSize.navPillWidth, height: AwradSize.navPillHeight)
                        .awradNavPill(isSelected: isSelected)
                    AwradIconImage(item.icon)
                        .foregroundStyle(isSelected ? AwradColors.onPrimaryContainer : AwradColors.onSurfaceVariant)
                        .animation(colorChange, value: isSelected)
                        .awradNavIcon(isSelected: isSelected)
                }
                Text(item.title)
                    .awradTextStyle(.navLabel)
                    .foregroundStyle(isSelected ? AwradColors.accent : AwradColors.onSurfaceVariant)
                    .animation(colorChange, value: isSelected)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: AwradSize.touchTarget)
            .contentShape(Rectangle())
            .awradDisabledAppearance()
        }
        .buttonStyle(.awradPress(.button))
        // The bar keeps its height at large text sizes; a long press shows the large label.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityShowsLargeContentViewer {
            item.icon.image
            Text(item.title)
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

extension View {
    /// Floats the bottom bar over this view: `pageMargin` from the sides and `lg` above the bottom
    /// safe area. Scrolling content goes under it and is inset so its last item clears it. It shows
    /// only on the top-level tabs: pass `isPresented: false` while a page is pushed, and the bar and
    /// its inset go away.
    public func awradBottomBar<Tab: Hashable>(
        selection: Binding<Tab>, items: [AwradBottomBarItem<Tab>], isPresented: Bool = true
    ) -> some View {
        safeAreaInset(edge: .bottom, spacing: AwradSpacing.none) {
            if isPresented {
                AwradBottomBar(selection: selection, items: items)
                    .padding(.horizontal, AwradSpacing.pageMargin)
                    .padding(.bottom, AwradSpacing.lg)
            }
        }
    }

    /// `tabSwitch`, on a tab's content keyed by the selected tab: the new tab scales up from
    /// `enterScaleFrom` and fades in from `enterFadeFrom`, the old one scales to `exitScaleTo` and fades
    /// out, over `medium` on `emphasized`. A cross-fade with reduced motion.
    public func awradTabSwitch<Value: Hashable>(value: Value) -> some View {
        modifier(TabSwitchModifier(value: value))
    }
}

private struct TabSwitchModifier<Value: Hashable>: ViewModifier {
    let value: Value
    @Environment(\.awradMotion) private var motion

    func body(content: Content) -> some View {
        let enter = TabSwitchEffect(
            scale: AwradMotion.TabSwitch.enterScaleFrom, opacity: AwradMotion.TabSwitch.enterFadeFrom)
        let exit = TabSwitchEffect(scale: AwradMotion.TabSwitch.exitScaleTo, opacity: 0)
        let identity = TabSwitchEffect(scale: 1, opacity: 1)
        ZStack {
            content
                .id(value)
                .transition(
                    motion.transition(
                        .asymmetric(
                            insertion: .modifier(active: enter, identity: identity),
                            removal: .modifier(active: exit, identity: identity))))
        }
        .animation(
            motion.animation(AwradMotion.TabSwitch.easing.animation(duration: AwradMotion.TabSwitch.duration)),
            value: value)
    }
}

private struct TabSwitchEffect: ViewModifier {
    let scale: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content.scaleEffect(scale).opacity(opacity)
    }
}
