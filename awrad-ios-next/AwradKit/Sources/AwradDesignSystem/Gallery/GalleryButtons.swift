#if DEBUG
    import SwiftUI

    /// Every button variant, with an icon, loading and disabled; row, round and icon buttons; the icons.
    struct GalleryButtons: View {
        var body: some View {
            GalleryGroup(title: "Buttons") {
                GalleryItem(caption: "Main · default, leading icon, loading, disabled") {
                    AwradButton(GalleryStrings.continueAction) {}
                    AwradButton(GalleryStrings.continueAction, icon: .forward) {}
                    AwradButton(GalleryStrings.continueAction, isLoading: true) {}
                    AwradButton(GalleryStrings.continueAction) {}.disabled(true)
                }
                GalleryItem(caption: "Secondary · default, leading icon, loading, disabled") {
                    AwradButton(GalleryStrings.notifications, variant: .secondary) {}
                    AwradButton(GalleryStrings.notifications, variant: .secondary, icon: .notifications) {}
                    AwradButton(GalleryStrings.notifications, variant: .secondary, isLoading: true) {}
                    AwradButton(GalleryStrings.notifications, variant: .secondary) {}.disabled(true)
                }
                GalleryItem(caption: "Secondary · on a surface card: background fill, onSurface label") {
                    AwradCard {
                        AwradButton(GalleryStrings.notifications, variant: .secondary, icon: .notifications) {}
                        AwradButton(GalleryStrings.viewAll, variant: .secondary, layout: .row) {}
                    }
                }
                GalleryItem(caption: "Error · default, loading, disabled") {
                    AwradButton(GalleryStrings.deleteAccount, variant: .error, role: .destructive) {}
                    AwradButton(GalleryStrings.deleteAccount, variant: .error, isLoading: true, role: .destructive) {}
                    AwradButton(GalleryStrings.deleteAccount, variant: .error, role: .destructive) {}.disabled(true)
                }
                GalleryItem(caption: "Text · default, destructive, disabled") {
                    AwradButton(GalleryStrings.viewAll, variant: .text) {}
                    AwradButton(GalleryStrings.signOut, variant: .text, role: .destructive) {}
                    AwradButton(GalleryStrings.viewAll, variant: .text) {}.disabled(true)
                }
                GalleryItem(caption: "Row buttons · in a card row, as wide as the label") {
                    AwradCard(AwradRadius.tile) {
                        HStack(spacing: AwradSpacing.md) {
                            GalleryRowText(title: GalleryStrings.morningAdhkar, detail: nil)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            AwradButton(GalleryStrings.signOut, variant: .text, layout: .row, role: .destructive) {}
                        }
                        HStack(spacing: AwradSpacing.md) {
                            GalleryRowText(title: GalleryStrings.eveningAdhkar, detail: nil)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            AwradButton(GalleryStrings.viewAll, variant: .main, layout: .row) {}
                        }
                    }
                }
                GalleryItem(caption: "Round · 48 and 32 (48 touch target), disabled") {
                    HStack(spacing: AwradSpacing.lg) {
                        AwradRoundButton(icon: .add, label: GalleryStrings.addGoal) {}
                        AwradRoundButton(
                            icon: .forward, label: GalleryStrings.openCollection, size: .small
                        ) {}
                        AwradRoundButton(icon: .add, label: GalleryStrings.addGoal) {}.disabled(true)
                    }
                }
                GalleryItem(caption: "Icon · back (flips in RTL), more, close, disabled") {
                    HStack(spacing: AwradSpacing.lg) {
                        AwradIconButton.back {}
                        AwradIconButton.more {}
                        AwradIconButton.close {}
                        AwradIconButton.more {}.disabled(true)
                    }
                }
                GalleryItem(caption: "Icons · the shared set in order; back, forward and chevron flip in RTL") {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: AwradSize.touchTarget), spacing: AwradSpacing.sm)],
                        alignment: .leading, spacing: AwradSpacing.sm
                    ) {
                        ForEach(AwradIcon.allCases, id: \.self) { icon in
                            AwradIconImage(icon)
                                .foregroundStyle(AwradColors.onSurface)
                                .frame(width: AwradSize.touchTarget, height: AwradSize.touchTarget)
                                .background(AwradColors.surface, in: AwradRadius.tile.shape)
                        }
                    }
                }
            }
        }
    }
#endif
