#if DEBUG
    import SwiftUI

    /// Every button variant, with an icon, loading and disabled; row, round and icon buttons.
    struct GalleryButtons: View {
        var body: some View {
            GalleryGroup(title: "Buttons") {
                GalleryItem(caption: "Main · default, leading icon, loading, disabled") {
                    AwradButton(GalleryStrings.continueAction) {}
                    AwradButton(GalleryStrings.continueAction, systemImage: "arrow.forward") {}
                    AwradButton(GalleryStrings.continueAction, isLoading: true) {}
                    AwradButton(GalleryStrings.continueAction) {}.disabled(true)
                }
                GalleryItem(caption: "Secondary · default, leading icon, loading, disabled") {
                    AwradButton(GalleryStrings.notifications, variant: .secondary) {}
                    AwradButton(GalleryStrings.notifications, variant: .secondary, systemImage: "bell") {}
                    AwradButton(GalleryStrings.notifications, variant: .secondary, isLoading: true) {}
                    AwradButton(GalleryStrings.notifications, variant: .secondary) {}.disabled(true)
                }
                GalleryItem(caption: "Secondary · on a surface card: background fill, onSurface label") {
                    AwradCard {
                        AwradButton(GalleryStrings.notifications, variant: .secondary, systemImage: "bell") {}
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
                        AwradRoundButton(systemImage: "plus", label: GalleryStrings.addGoal) {}
                        AwradRoundButton(
                            systemImage: "arrow.forward", label: GalleryStrings.openCollection, size: .small
                        ) {}
                        AwradRoundButton(systemImage: "plus", label: GalleryStrings.addGoal) {}.disabled(true)
                    }
                }
                GalleryItem(caption: "Icon · back (flips in RTL), more, disabled") {
                    HStack(spacing: AwradSpacing.lg) {
                        AwradIconButton.back {}
                        AwradIconButton.more {}
                        AwradIconButton.more {}.disabled(true)
                    }
                }
            }
        }
    }
#endif
