#if DEBUG
    import SwiftUI

    /// Cards, the content sheet, the bottom sheet, the dialog and option rows.
    struct GalleryContainers: View {
        @Binding var showsSheet: Bool
        @Binding var showsDialog: Bool
        @State private var language = 0
        @State private var reminders = true
        @State private var sounds = false

        var body: some View {
            GalleryGroup(title: "Containers") {
                GalleryItem(caption: "Card · static, card and tile shapes") {
                    AwradCard {
                        GalleryRowText(title: GalleryStrings.todaysGoals, detail: GalleryStrings.morningAdhkar)
                    }
                    AwradCard(AwradRadius.tile) {
                        GalleryRowText(title: GalleryStrings.eveningAdhkar, detail: nil)
                    }
                }
                GalleryItem(caption: "Card · tappable, tappable disabled") {
                    AwradCardButton(action: galleryNoAction) {
                        GalleryRowText(title: GalleryStrings.nextPrayer, detail: GalleryStrings.morningAdhkar)
                    }
                    AwradCardButton(AwradRadius.tile, action: galleryNoAction) {
                        GalleryRowText(title: GalleryStrings.nextPrayer, detail: nil)
                    }
                    .disabled(true)
                }
                GalleryItem(caption: "Content sheet · section title, background cards inside", isInset: false) {
                    AwradContentSheet {
                        AwradSectionTitle(GalleryStrings.myGoals)
                        AwradCard(AwradRadius.tile) {
                            GalleryRowText(title: GalleryStrings.morningAdhkar, detail: nil)
                        }
                        .padding(.horizontal, AwradSpacing.pageMargin)
                        AwradCard(AwradRadius.tile) {
                            GalleryRowText(title: GalleryStrings.eveningAdhkar, detail: nil)
                        }
                        .padding(.horizontal, AwradSpacing.pageMargin)
                    }
                    // A sample height: the sheet fills whatever is left of a real screen.
                    .frame(height: 260)
                }
                GalleryItem(caption: "Bottom sheet · native sheet, sheet corners, handle") {
                    AwradButton(GalleryStrings.openSheet, variant: .secondary) { showsSheet = true }
                }
                GalleryItem(caption: "Dialog · inline, and presented over the scrim") {
                    dialog
                    AwradButton(GalleryStrings.openDialog, variant: .secondary) { showsDialog = true }
                }
                GalleryItem(caption: "Option row · single choice, avatar, disabled") {
                    AwradOptionRow(GalleryStrings.english, avatar: "Aa", isSelected: language == 0) { language = 0 }
                    AwradOptionRow(GalleryStrings.arabic, avatar: "ع", isSelected: language == 1) { language = 1 }
                    AwradOptionRow(GalleryStrings.malayalam, avatar: "അ", isSelected: language == 2) { language = 2 }
                        .disabled(true)
                }
                GalleryItem(caption: "Option row · multiple choice") {
                    AwradOptionRow(GalleryStrings.reminders, isSelected: reminders, selection: .multiple) {
                        reminders.toggle()
                    }
                    AwradOptionRow(GalleryStrings.sounds, isSelected: sounds, selection: .multiple) { sounds.toggle() }
                }
                GalleryItem(caption: "Option row · on a surface card: background fill, onSurface label") {
                    AwradCard {
                        AwradOptionRow(GalleryStrings.english, avatar: "Aa", isSelected: language == 0) { language = 0 }
                        AwradOptionRow(GalleryStrings.arabic, avatar: "ع", isSelected: language == 1) { language = 1 }
                    }
                }
            }
            .awradBottomSheet(isPresented: $showsSheet) {
                VStack(alignment: .leading, spacing: AwradSpacing.rowGap) {
                    Text(GalleryStrings.sheetTitle)
                        .awradTextStyle(.cardTitle)
                        .foregroundStyle(AwradColors.onSurface)
                    Text(GalleryStrings.sheetBody)
                        .awradTextStyle(.body)
                        .foregroundStyle(AwradColors.onSurfaceVariant)
                    AwradOptionRow(GalleryStrings.morningAdhkar, isSelected: true) {}
                    AwradOptionRow(GalleryStrings.eveningAdhkar, isSelected: false) {}
                    AwradButton(GalleryStrings.continueAction) { showsSheet = false }
                }
                .padding(.horizontal, AwradSpacing.pageMargin)
            }
        }

        private var dialog: some View {
            AwradDialog(title: GalleryStrings.dialogTitle, message: GalleryStrings.dialogBody) {
                Self.dialogActions {}
            }
        }

        /// Cancel, and the destructive confirmation in the error variant.
        @ViewBuilder static func dialogActions(dismiss: @escaping () -> Void) -> some View {
            AwradButton(GalleryStrings.cancel, variant: .text, layout: .row, action: dismiss)
            AwradButton(GalleryStrings.delete, variant: .error, layout: .row, role: .destructive, action: dismiss)
        }
    }

    extension View {
        /// The gallery's dialog, over the whole gallery.
        func galleryDialog(isPresented: Binding<Bool>) -> some View {
            awradDialog(isPresented: isPresented, title: GalleryStrings.dialogTitle, message: GalleryStrings.dialogBody)
            {
                GalleryContainers.dialogActions { isPresented.wrappedValue = false }
            }
        }
    }

    /// A title and an optional detail line, as a card's content.
    struct GalleryRowText: View {
        let title: LocalizedStringResource
        let detail: LocalizedStringResource?

        var body: some View {
            VStack(alignment: .leading, spacing: AwradSpacing.xxs) {
                Text(title)
                    .awradTextStyle(.cardTitle)
                    .foregroundStyle(AwradColors.onSurface)
                if let detail {
                    Text(detail)
                        .awradTextStyle(.bodySmall)
                        .foregroundStyle(AwradColors.onSurfaceVariant)
                }
            }
        }
    }
#endif
