#if DEBUG
    import Foundation

    /// Sample text for the component gallery, from the design system's catalog (en, ar, ml), so the
    /// right-to-left view shows Arabic. Captions naming components and states stay in English: the
    /// gallery is a debug review surface.
    enum GalleryStrings {
        private static func text(_ key: StaticString, _ english: String.LocalizationValue) -> LocalizedStringResource {
            LocalizedStringResource(key, defaultValue: english, bundle: AwradStrings.bundle)
        }

        static let title = text("gallery.title", "Components")
        static let dark = text("gallery.dark", "Dark")
        static let rightToLeft = text("gallery.rtl", "Arabic, right to left")

        static let todaysGoals = text("gallery.todays_goals", "Today's goals")
        static let morningAdhkar = text("gallery.morning_adhkar", "Morning adhkar")
        static let eveningAdhkar = text("gallery.evening_adhkar", "Evening adhkar")
        static let nextPrayer = text("gallery.next_prayer", "Next prayer")
        static let myGoals = text("gallery.my_goals", "My Goals")
        static let openSheet = text("gallery.open_sheet", "Open bottom sheet")
        static let sheetTitle = text("gallery.sheet_title", "Choose a time")
        static let sheetBody = text("gallery.sheet_body", "Drag down to close.")
        static let openDialog = text("gallery.open_dialog", "Open dialog")
        static let dialogTitle = text("gallery.dialog_title", "Delete this goal?")
        static let dialogBody = text("gallery.dialog_body", "Its history goes too. This can't be undone.")
        static let cancel = text("gallery.cancel", "Cancel")
        static let delete = text("gallery.delete", "Delete")
        static let english = text("gallery.english", "English")
        static let arabic = text("gallery.arabic", "العربية")
        static let malayalam = text("gallery.malayalam", "മലയാളം")
        static let reminders = text("gallery.reminders", "Reminders")
        static let sounds = text("gallery.sounds", "Sounds")

        static let continueAction = text("gallery.continue", "Continue")
        static let notifications = text("gallery.notifications", "Notifications")
        static let deleteAccount = text("gallery.delete_account", "Delete account")
        static let viewAll = text("gallery.view_all", "View all")
        static let signOut = text("gallery.sign_out", "Sign out")
        static let addGoal = text("gallery.add_goal", "Add goal")
        static let openCollection = text("gallery.open_collection", "Open collection")

        /// A collection tile's count (plural variants in the catalog).
        static func dhikrCount(_ count: Int) -> LocalizedStringResource {
            LocalizedStringResource("gallery.dhikr_count", defaultValue: "\(count) dhikrs", bundle: AwradStrings.bundle)
        }

        static let email = text("gallery.email", "Email")
        static let emailPrompt = text("gallery.email_prompt", "Your email address")
        static let emailSupport = text("gallery.email_support", "We'll send a code to this address.")
        static let password = text("gallery.password", "Password")
        static let passwordError = text("gallery.password_error", "This password is too short.")
        static let rememberMe = text("gallery.remember_me", "Remember me")
        static let dailyReminder = text("gallery.daily_reminder", "Daily reminder")
        static let active = text("gallery.active", "Active")
        static let history = text("gallery.history", "History")
        static let upcoming = text("gallery.upcoming", "Upcoming")

        static let settings = text("gallery.settings", "Settings")
        static let skip = text("gallery.skip", "Skip")
        static let home = text("gallery.home", "Home")
        static let goals = text("gallery.goals", "Goals")
        static let library = text("gallery.library", "Library")
        static let community = text("gallery.community", "Community")

        static let tagMorning = text("gallery.tag_morning", "Morning")
        static let tagEvening = text("gallery.tag_evening", "Evening")
        static let tagTravel = text("gallery.tag_travel", "Travel")
        static let conflict = text("gallery.conflict", "Changed on another device")
        static let keepMine = text("gallery.keep_mine", "Keep mine")
        static let useTheirs = text("gallery.use_theirs", "Use theirs")
        static let changeRefused = text("gallery.change_refused", "Change refused")
        static let changeRefusedReason = text("gallery.change_refused_reason", "Another tag already has that name.")
        static let ok = text("gallery.ok", "OK")
        static let translation = text("gallery.translation", "Translation")
        static let translationSample = text(
            "gallery.translation_sample",
            "Glory be to Allah and praise be to Him, glory be to Allah the Magnificent. Whoever says it a hundred times a day has their sins wiped away."
        )
        static let required = text("gallery.required", "Enter the Arabic text.")
        static let yourDhikrs = text("gallery.your_dhikrs", "Your dhikrs")
    }
#endif
