import SwiftUI

extension View {
    /// The bottom sheet: the native sheet (it follows the finger and settles itself) with `sheet`
    /// corners, a `surfaceBar` fill and the drag handle (`outline`, `tabIndicator` shape) on top.
    public func awradBottomSheet<Content: View>(
        isPresented: Binding<Bool>, detents: Set<PresentationDetent> = [.medium, .large],
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        sheet(isPresented: isPresented) {
            AwradBottomSheetContent(detents: detents, content: content())
        }
    }

    /// The dialog over this view, with the `scrim` behind it: tapping the scrim, or the VoiceOver
    /// escape gesture, dismisses it. Pass buttons as `actions`, `layout: .row` so they sit at the end;
    /// a destructive confirmation uses the `error` variant. It appears and leaves with a fade.
    public func awradDialog<Actions: View>(
        isPresented: Binding<Bool>, title: LocalizedStringResource, message: LocalizedStringResource? = nil,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        modifier(
            DialogPresenter(
                isPresented: isPresented, dialog: AwradDialog(title: title, message: message, actions: actions)))
    }
}

/// The content of a bottom sheet, with its handle, fill and corners.
private struct AwradBottomSheetContent<Content: View>: View {
    let detents: Set<PresentationDetent>
    let content: Content

    var body: some View {
        VStack(spacing: AwradSpacing.lg) {
            // The handle shows the sheet can be dragged; the native sheet already says so to VoiceOver.
            Capsule(style: .continuous)
                .fill(AwradColors.outline)
                .frame(width: AwradSpacing.xl3, height: AwradSize.tabIndicatorHeight)
                .padding(.top, AwradSpacing.sm)
                .accessibilityHidden(true)
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // A bottom sheet counts as the page: controls in it use their page fills.
        .environment(\.awradContainer, .background)
        .presentationDetents(detents)
        .presentationDragIndicator(.hidden)
        .presentationBackground(AwradColors.surfaceBar)
        .awradSheet()
    }
}

/// A dialog's card: `surfaceBar` fill, `dialog` corners, `cardPadding` inside, at most
/// `dialogMaxWidth` wide. Title `cardTitle`, body `body`, actions at the end. Use it through
/// `awradDialog(isPresented:title:message:actions:)`; it's public for galleries and previews.
public struct AwradDialog<Actions: View>: View {
    private let title: LocalizedStringResource
    private let message: LocalizedStringResource?
    private let actions: Actions

    public init(
        title: LocalizedStringResource, message: LocalizedStringResource? = nil, @ViewBuilder actions: () -> Actions
    ) {
        self.title = title
        self.message = message
        self.actions = actions()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: AwradSpacing.rowGap) {
            Text(title)
                .awradTextStyle(.cardTitle)
                .foregroundStyle(AwradColors.onSurface)
                .accessibilityAddTraits(.isHeader)
            if let message {
                Text(message)
                    .awradTextStyle(.body)
                    .foregroundStyle(AwradColors.onSurfaceVariant)
            }
            HStack(spacing: AwradSpacing.sm) {
                Spacer(minLength: AwradSpacing.none)
                actions
            }
            .padding(.top, AwradSpacing.sm)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(AwradSpacing.cardPadding)
        .frame(maxWidth: AwradSize.dialogMaxWidth, alignment: .leading)
        .background(AwradColors.surfaceBar, in: AwradRadius.dialog.shape)
        // A dialog counts as the page: controls in it use their page fills.
        .environment(\.awradContainer, .background)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }
}

private struct DialogPresenter<Actions: View>: ViewModifier {
    @Binding var isPresented: Bool
    let dialog: AwradDialog<Actions>
    /// Whether the transparent full-screen cover holding the dialog is up. It goes up at once and
    /// comes down after the fade, so only the fade shows.
    @State private var isCovering = false

    func body(content: Content) -> some View {
        #if os(iOS)
            // A full-screen cover, so the scrim also dims bars SwiftUI draws above overlays (the
            // floating bottom bar's safe-area inset, toolbars).
            content
                .fullScreenCover(isPresented: $isCovering) {
                    DialogScene(isPresented: $isPresented, dialog: dialog) {
                        // Shown again while fading out: keep the cover.
                        if !isPresented { Self.withoutAnimation { isCovering = false } }
                    }
                    .presentationBackground(.clear)
                }
                .onChange(of: isPresented, initial: true) { _, isPresented in
                    if isPresented { Self.withoutAnimation { isCovering = true } }
                }
        #else
            content.overlay {
                if isCovering || isPresented {
                    DialogScene(isPresented: $isPresented, dialog: dialog) { isCovering = false }
                }
            }
        #endif
    }

    private static func withoutAnimation(_ change: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, change)
    }
}

/// The scrim and the dialog, fading in when they appear and out when `isPresented` turns off
/// (`contentSwap`, already a fade), then calling `onGone`.
private struct DialogScene<Actions: View>: View {
    @Binding var isPresented: Bool
    let dialog: AwradDialog<Actions>
    let onGone: () -> Void
    @State private var isShown = false

    var body: some View {
        ZStack {
            if isShown {
                ZStack {
                    AwradColors.scrim
                        .ignoresSafeArea()
                        .onTapGesture { isPresented = false }
                        .accessibilityHidden(true)
                    dialog
                        .padding(AwradSpacing.pageMargin)
                        .accessibilityAction(.escape) { isPresented = false }
                }
                .transition(AwradMotion.ContentSwap.transition)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(AwradMotion.ContentSwap.easing.animation(duration: AwradMotion.ContentSwap.fadeIn), value: isShown)
        .onAppear { isShown = isPresented }
        .onChange(of: isPresented) { _, isPresented in
            isShown = isPresented
            guard !isPresented else { return }
            Task {
                try? await Task.sleep(for: .seconds(AwradMotion.ContentSwap.fadeOut))
                onGone()
            }
        }
    }
}

#Preview("Dialog") {
    @Previewable @State var isPresented = true
    AwradButton("Show") { isPresented = true }
        .padding(AwradSpacing.pageMargin)
        .frame(maxHeight: .infinity)
        .background(AwradColors.background)
        .awradDialog(isPresented: $isPresented, title: "Delete account?", message: "This can't be undone.") {
            AwradButton("Cancel", variant: .text, layout: .row) { isPresented = false }
            AwradButton("Delete", variant: .error, layout: .row, role: .destructive) { isPresented = false }
        }
}
