#if DEBUG
    import SwiftUI

    /// Text fields, checkboxes, switches and segmented pills in each state.
    struct GalleryInputs: View {
        @State private var email = ""
        @State private var filledEmail = "amina@example.com"
        @State private var password = "short"
        @State private var remember = true
        @State private var later = false
        @State private var reminder = true
        @State private var sounds = false
        @State private var view = 0
        @State private var threeWay = 1

        var body: some View {
            GalleryGroup(title: "Inputs") {
                GalleryItem(caption: "Text field · empty with placeholder, filled with supporting text") {
                    AwradTextField(GalleryStrings.email, text: $email, prompt: GalleryStrings.emailPrompt)
                    AwradTextField(
                        GalleryStrings.email, text: $filledEmail, supportingText: GalleryStrings.emailSupport)
                }
                GalleryItem(caption: "Text field · error (secure), disabled") {
                    AwradTextField(
                        GalleryStrings.password, text: $password, isSecure: true, error: GalleryStrings.passwordError)
                    AwradTextField(GalleryStrings.email, text: $filledEmail).disabled(true)
                }
                GalleryItem(caption: "Text field · on a card, in error") {
                    AwradCard {
                        AwradTextField(GalleryStrings.email, text: $email, prompt: GalleryStrings.emailPrompt)
                        AwradTextField(
                            GalleryStrings.password, text: $password, isSecure: true,
                            error: GalleryStrings.passwordError)
                    }
                }
                GalleryItem(caption: "Checkbox · ticked, unticked, disabled") {
                    VStack(spacing: AwradSpacing.none) {
                        AwradCheckbox(GalleryStrings.rememberMe, isOn: $remember)
                        AwradCheckbox(GalleryStrings.dailyReminder, isOn: $later)
                        AwradCheckbox(GalleryStrings.rememberMe, isOn: .constant(true)).disabled(true)
                        AwradCheckbox(GalleryStrings.dailyReminder, isOn: .constant(false)).disabled(true)
                    }
                }
                GalleryItem(caption: "Switch · native Toggle tinted primary: on, off, disabled") {
                    VStack(spacing: AwradSpacing.none) {
                        AwradSwitch(GalleryStrings.dailyReminder, isOn: $reminder)
                        AwradSwitch(GalleryStrings.sounds, isOn: $sounds)
                        AwradSwitch(GalleryStrings.reminders, isOn: .constant(true)).disabled(true)
                    }
                }
                GalleryItem(caption: "Segmented pills · two, three, disabled") {
                    AwradSegmentedPills(selection: $view, options: Self.twoViews)
                    AwradSegmentedPills(selection: $threeWay, options: Self.threeViews)
                    AwradSegmentedPills(selection: .constant(0), options: Self.twoViews).disabled(true)
                }
                GalleryItem(caption: "Segmented pills · on a surface card") {
                    AwradCard { AwradSegmentedPills(selection: $view, options: Self.twoViews) }
                }
            }
        }

        static let twoViews: [AwradSegmentedPills<Int>.Option] = [
            .init(0, title: GalleryStrings.active), .init(1, title: GalleryStrings.history),
        ]

        static let threeViews: [AwradSegmentedPills<Int>.Option] = [
            .init(0, title: GalleryStrings.active), .init(1, title: GalleryStrings.upcoming),
            .init(2, title: GalleryStrings.history),
        ]
    }

    /// The top bar, step indicator, large-title header and bottom bar.
    struct GalleryNavigation: View {
        let tab: GalleryTab

        var body: some View {
            GalleryGroup(title: "Navigation") {
                GalleryItem(caption: "Top bar · back, title, more; back, steps, text button", isInset: false) {
                    AwradTopBar(GalleryStrings.settings, onBack: galleryNoAction) { AwradIconButton.more {} }
                    AwradTopBar(onBack: galleryNoAction) {
                        AwradStepIndicator(current: 2, total: 7)
                    } trailing: {
                        AwradButton(GalleryStrings.skip, variant: .text, layout: .row) {}
                    }
                }
                GalleryItem(caption: "Step indicator · 1, 4 and 7 of 7") {
                    AwradStepIndicator(current: 1, total: 7)
                    AwradStepIndicator(current: 4, total: 7)
                    AwradStepIndicator(current: 7, total: 7)
                }
                GalleryItem(caption: "Large-title header · with the + action, title only", isInset: false) {
                    AwradLargeTitleHeader(GalleryStrings.myGoals) {
                        AwradRoundButton(systemImage: "plus", label: GalleryStrings.addGoal) {}
                    }
                    AwradLargeTitleHeader(GalleryStrings.library)
                }
                GalleryItem(caption: "Bottom bar · Home selected, Library selected (the real one floats below)") {
                    AwradBottomBar(selection: .constant(GalleryTab.home), items: GalleryTab.items)
                    AwradBottomBar(selection: .constant(GalleryTab.library), items: GalleryTab.items)
                }
                GalleryItem(caption: "Tab switch · follows the floating bar") {
                    AwradCard {
                        Text(tab.title)
                            .awradTextStyle(.cardTitle)
                            .foregroundStyle(AwradColors.onSurface)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .awradTabSwitch(value: tab)
                    }
                }
            }
        }
    }
#endif
