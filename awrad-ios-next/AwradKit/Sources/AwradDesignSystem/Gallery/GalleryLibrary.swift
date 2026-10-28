#if DEBUG
    import SwiftUI

    /// The slice 3b components (components.md "Custom dhikrs and sync components"): filter chips, the
    /// conflict banner, the "Change refused" notice, the multi-line text field and the "Your dhikrs"
    /// tile.
    struct GalleryLibrary: View {
        @State private var chosen: Set<Int> = [0]
        @State private var empty = ""
        @State private var translation = String(localized: GalleryStrings.translationSample)
        @State private var showsNotice = false

        var body: some View {
            GalleryGroup(title: "Library") {
                GalleryItem(caption: "Filter chip · selected, unselected (tap to toggle), disabled") {
                    HStack(spacing: AwradSpacing.sm) {
                        chip(0, GalleryStrings.tagMorning)
                        chip(1, GalleryStrings.tagEvening)
                        AwradFilterChip(GalleryStrings.tagTravel, isSelected: false) {}.disabled(true)
                    }
                }
                GalleryItem(caption: "Filter chip · on a surface card") {
                    AwradCard {
                        HStack(spacing: AwradSpacing.sm) {
                            chip(0, GalleryStrings.tagMorning)
                            chip(1, GalleryStrings.tagEvening)
                        }
                    }
                }
                GalleryItem(caption: "Conflict banner · message, with a tag's name") {
                    AwradConflictBanner(
                        GalleryStrings.conflict, keepMine: GalleryStrings.keepMine, useTheirs: GalleryStrings.useTheirs,
                        onKeepMine: galleryNoAction, onUseTheirs: galleryNoAction)
                    AwradConflictBanner(
                        GalleryStrings.conflict, detail: String(localized: GalleryStrings.tagMorning),
                        keepMine: GalleryStrings.keepMine, useTheirs: GalleryStrings.useTheirs,
                        onKeepMine: galleryNoAction, onUseTheirs: galleryNoAction)
                }
                GalleryItem(caption: "\"Change refused\" notice · inline, and presented over the scrim") {
                    AwradDialog(title: GalleryStrings.changeRefused, message: GalleryStrings.changeRefusedReason) {
                        AwradButton(GalleryStrings.ok, variant: .text, layout: .row, action: galleryNoAction)
                    }
                    AwradButton(GalleryStrings.changeRefused, variant: .secondary) { showsNotice = true }
                }
                GalleryItem(caption: "Multi-line text field · one line when empty, grows to 6 lines, error") {
                    AwradTextField(GalleryStrings.translation, text: $empty, axis: .vertical)
                    AwradTextField(GalleryStrings.translation, text: $translation, axis: .vertical)
                    AwradTextField(
                        GalleryStrings.translation, text: $empty, error: GalleryStrings.required, axis: .vertical)
                }
                GalleryItem(caption: "\"Your dhikrs\" tile · first in the row", isInset: false) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: AwradSpacing.md) {
                            AwradCollectionTile(GalleryStrings.yourDhikrs, detail: GalleryStrings.dhikrCount(3)) {}
                            AwradCollectionTile(GalleryStrings.morningAdhkar, detail: GalleryStrings.dhikrCount(4)) {}
                        }
                        .padding(.horizontal, AwradSpacing.pageMargin)
                    }
                }
            }
            .awradDialog(
                isPresented: $showsNotice, title: GalleryStrings.changeRefused,
                message: GalleryStrings.changeRefusedReason
            ) {
                AwradButton(GalleryStrings.ok, variant: .text, layout: .row) { showsNotice = false }
            }
        }

        private func chip(_ index: Int, _ title: LocalizedStringResource) -> some View {
            AwradFilterChip(title, isSelected: chosen.contains(index)) {
                if chosen.remove(index) == nil { chosen.insert(index) }
            }
        }
    }
#endif
