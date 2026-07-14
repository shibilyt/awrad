import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct OnboardingView: View {
    @Environment(AwradStore.self) private var store
    @Environment(AppServices.self) private var services
    @Environment(AppRouter.self) private var router

    @State private var step = 0
    @State private var name = ""
    @State private var selectedAudioIDs: Set<AwradID> = []
    @State private var downloadProgress = 0
    @State private var isDownloading = false
    @State private var downloadMessage: String?
    @State private var notificationsResolved = false
    @State private var firstGoalCount = 70
    @State private var isCreatingGoal = false

    private let totalSteps = 8

    private var audioItems: [Dhikr] {
        store.dhikrs.filter { $0.audioURL != nil }
    }
    private var language: AppLanguage { store.preferences.appLanguage }

    var body: some View {
        ZStack {
            onboardingBackground.ignoresSafeArea()

            if step == 0 {
                welcomeScreen
            } else {
                VStack(spacing: 0) {
                    stepHeader

                    if isCenteredStep {
                        centeredStepBody
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 22) {
                                stepContent
                            }
                            .padding(20)
                            .padding(.top, 4)
                            .padding(.bottom, 40)
                        }
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    controls
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                        .background(AwradTheme.background.opacity(0.96))
                }
            }
        }
        .animation(.snappy, value: step)
        .onAppear(perform: initializeOnboardingState)
    }

    // MARK: - Background & progress

    private var onboardingBackground: some View {
        ZStack {
            AwradTheme.background
            RadialGradient(
                colors: [AwradTheme.gold.opacity(0.10), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 440
            )
        }
    }

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index == step ? AwradTheme.sage : AwradTheme.ink.opacity(0.12))
                    .frame(width: index == step ? 18 : 6, height: 4)
                    .animation(.snappy, value: step)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityLabel("Onboarding step \(step + 1) of \(totalSteps)")
    }

    // MARK: - Shared step header (logo on top)

    private var stepHeader: some View {
        VStack(spacing: 18) {
            ZStack {
                progressDots
                HStack {
                    backButton
                    Spacer()
                    if canSkip { skipButton }
                }
            }
            AppMark(size: 56)
        }
        .padding(.top, 12)
        .padding(.horizontal, 20)
    }

    private var backButton: some View {
        Button {
            withAnimation(.snappy) { step -= 1 }
        } label: {
            Image(systemName: "chevron.left")
                .font(AwradTheme.displayFont(.subheadline, weight: .semibold))
                .foregroundStyle(AwradTheme.ink)
                .frame(width: 38, height: 38)
                .background(AwradTheme.ink.opacity(0.06), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Back"))
    }

    private var skipButton: some View {
        Button {
            withAnimation(.snappy) { step += 1 }
        } label: {
            Text(LocalizedStringKey("Skip"))
                .font(AwradTheme.displayFont(.subheadline, weight: .semibold))
                .foregroundStyle(AwradTheme.subdued)
                .padding(.horizontal, 8)
                .frame(height: 38)
        }
        .buttonStyle(.plain)
    }

    /// Steps whose content is short enough to vertically center (no scroll).
    private var isCenteredStep: Bool {
        step == 1 || step == 2
    }

    @ViewBuilder
    private var centeredStepBody: some View {
        switch step {
        case 1: nameStep
        case 2: languageStep
        default: EmptyView()
        }
    }

    // MARK: - Name (centered)

    private var nameStep: some View {
        VStack(spacing: 16) {
            Spacer()

            VStack(spacing: 8) {
                Text(LocalizedStringKey("What should we call you?"))
                    .font(AwradTheme.displayFont(28, weight: .bold))
                    .foregroundStyle(AwradTheme.ink)
                    .multilineTextAlignment(.center)
                Text(LocalizedStringKey("We'll use your name to personalize your experience."))
                    .font(AwradTheme.bodyFont(.subheadline))
                    .foregroundStyle(AwradTheme.subdued)
                    .multilineTextAlignment(.center)
            }

            TextField("", text: $name, prompt: Text(LocalizedStringKey("Your name")).foregroundColor(AwradTheme.subdued.opacity(0.6)))
                .textContentType(.name)
                .submitLabel(.next)
                .multilineTextAlignment(.center)
                .font(AwradTheme.displayFont(24, weight: .medium))
                .foregroundStyle(AwradTheme.ink)
                .padding(.vertical, 12)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(AwradTheme.sage.opacity(name.isEmpty ? 0.18 : 0.6))
                        .frame(height: 1.5)
                        .animation(.snappy, value: name.isEmpty)
                }
                .padding(.horizontal, 40)
                .padding(.top, 16)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Welcome (editorial, no imagery)

    private var welcomeScreen: some View {
        VStack(spacing: 0) {
            progressDots
                .padding(.top, 12)

            Spacer(minLength: 24)

            VStack(spacing: 20) {
                // ﷽ — fitted so it never clips on narrow screens.
                Text(verbatim: "\u{FDFD}")
                    .font(AwradTheme.arabicFont(34))
                    .foregroundStyle(AwradTheme.gold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)

                AppMark(size: 88)

                VStack(spacing: 8) {
                    Text("Awrad")
                        .font(AwradTheme.displayFont(42, weight: .bold))
                        .foregroundStyle(AwradTheme.ink)
                    Text(LocalizedStringKey("Your daily dhikr companion"))
                        .font(AwradTheme.bodyFont(.headline, weight: .regular))
                        .foregroundStyle(AwradTheme.subdued)
                }
            }

            Spacer(minLength: 28)

            VStack(spacing: 0) {
                WelcomeRow(symbol: "circle.grid.cross.fill", title: "Dhikr goals", subtitle: "Daily, cumulative, and prayer-based.")
                welcomeDivider
                WelcomeRow(symbol: "waveform", title: "Audio counting", subtitle: "Let recitations count for you, hands-free.")
                welcomeDivider
                WelcomeRow(symbol: "book.pages.fill", title: "Wirds & community", subtitle: "Read collections, grow with others.")
            }

            Spacer(minLength: 28)

            Button {
                withAnimation(.snappy) { step = 1 }
            } label: {
                Text(LocalizedStringKey("Begin"))
                    .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(AwradTheme.sage, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 20)
    }

    private var welcomeDivider: some View {
        Rectangle()
            .fill(AwradTheme.ink.opacity(0.08))
            .frame(height: 1)
    }

    // MARK: - Steps

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 3:
            OnboardingLocationStep()
        case 4:
            OnboardingPanel(title: "How should Awrad feel?", subtitle: "Choose a theme. You can change this anytime in Settings.") {
                themePicker
            }
        case 5:
            OnboardingPanel(title: "Stay on track", subtitle: "Allow notifications so Awrad can remind you of your daily dhikr and prayers.") {
                notificationsStep
            }
        case 6:
            OnboardingPanel(title: "Prepare guided audio", subtitle: "Download recitations now so audio-assisted counting works offline.") {
                audioStep
            }
        default:
            firstGoalStep
        }
    }

    // MARK: - Language (centered)

    private var languageStep: some View {
        VStack(spacing: 16) {
            Spacer()

            VStack(spacing: 8) {
                Text(LocalizedStringKey("Choose your language"))
                    .font(AwradTheme.displayFont(28, weight: .bold))
                    .foregroundStyle(AwradTheme.ink)
                    .multilineTextAlignment(.center)
                Text(LocalizedStringKey("You can change this anytime in Settings."))
                    .font(AwradTheme.bodyFont(.subheadline))
                    .foregroundStyle(AwradTheme.subdued)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 8)

            VStack(spacing: 0) {
                ForEach(Array(AppLanguage.allCases.enumerated()), id: \.element) { index, lang in
                    if index > 0 { hairline }
                    LanguageRow(
                        language: lang,
                        selected: store.preferences.appLanguage == lang
                    ) {
                        store.updatePreferences { $0.appLanguage = lang }
                    }
                }
            }
            .padding(.horizontal, 8)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var hairline: some View {
        Rectangle().fill(AwradTheme.ink.opacity(0.08)).frame(height: 1)
    }

    private var themePicker: some View {
        VStack(spacing: 10) {
            ForEach(ColorSchemeMode.allCases) { mode in
                let selected = store.preferences.colorSchemeMode == mode
                Button {
                    store.updatePreferences { $0.colorSchemeMode = mode }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: themeSymbol(mode))
                            .font(AwradTheme.bodyFont(.title3, weight: .semibold))
                            .foregroundStyle(selected ? .white : AwradTheme.sage)
                            .frame(width: 36, height: 36)
                            .background(selected ? AwradTheme.sage : AwradTheme.sage.opacity(0.12), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(LocalizedStringKey(themeTitle(mode)))
                                .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                            Text(LocalizedStringKey(themeSubtitle(mode)))
                                .font(AwradTheme.bodyFont(.footnote))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selected ? AwradTheme.sage : .secondary.opacity(0.5))
                    }
                    .padding(14)
                    .background(selected ? AwradTheme.sage.opacity(0.14) : AwradTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(selected ? AwradTheme.sage : .clear, lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var notificationsStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: notificationsResolved ? "checkmark.circle.fill" : "bell.badge.fill")
                .font(AwradTheme.bodyFont(44))
                .foregroundStyle(notificationsResolved ? AwradTheme.sage : AwradTheme.gold)
                .frame(maxWidth: .infinity, alignment: .center)

            FeatureLine(symbol: "alarm.fill", text: "Reminders for your daily dhikr goals")
            FeatureLine(symbol: "sun.horizon.fill", text: "Prayer-time aware nudges")

            Button {
                Task {
                    await services.notifications.requestAuthorizationIfUseful()
                    notificationsResolved = true
                }
            } label: {
                Text(LocalizedStringKey(notificationsResolved ? "Notifications set" : "Enable notifications"))
                    .frame(maxWidth: .infinity)
            }
            .awradPrimaryButton()
            .disabled(notificationsResolved)
        }
    }

    private var audioStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(AwradLocalizer.format("%d recitations available", language: language, audioItems.count))
                    .font(AwradTheme.bodyFont(.footnote, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            VStack(spacing: 8) {
                ForEach(audioItems) { dhikr in
                    HStack(spacing: 12) {
                        Image(systemName: dhikr.isDownloaded ? "checkmark.circle.fill" : "arrow.down.circle")
                            .foregroundStyle(dhikr.isDownloaded ? AwradTheme.sage : .secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(dhikr.displayTitle(language: language))
                                .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                            Text(dhikr.arabic)
                                .font(AwradTheme.arabicFont(18))
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(AwradTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }

            if isDownloading {
                ProgressView(value: Double(downloadProgress), total: Double(max(audioItems.count, 1))) {
                    Text(AwradLocalizer.format("Downloading %d/%d", language: language, downloadProgress, audioItems.count))
                }
            }

            if let downloadMessage {
                Text(downloadMessage)
                    .font(AwradTheme.bodyFont(.footnote))
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Download all", action: downloadAllAudio)
                    .buttonStyle(.borderedProminent)
                    .tint(AwradTheme.sage)
                    .disabled(isDownloading || audioItems.isEmpty)
                Spacer()
            }
        }
    }

    private var firstGoalStep: some View {
        OnboardingPanel(title: "Your first dhikr goal", subtitle: "We begin with Istighfar — seeking Allah's forgiveness — starting small so it lasts.") {
            VStack(spacing: 18) {
                istighfarCard
                CountStepper(count: $firstGoalCount, quickValues: [70, 100])
            }
        }
    }

    private var istighfarCard: some View {
        VStack(spacing: 8) {
            Text("أَسْتَغْفِرُ ٱللَّٰهَ ٱلْعَظِيمَ")
                .font(AwradTheme.arabicFont(30))
                .foregroundStyle(AwradTheme.sageDark)
            Text(LocalizedStringKey("Istighfar"))
                .font(AwradTheme.bodyFont(.headline, weight: .semibold))
            Text(LocalizedStringKey("Seeking Allah's forgiveness"))
                .font(AwradTheme.bodyFont(.footnote))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(AwradTheme.sage.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AwradTheme.gold.opacity(0.5), lineWidth: 1)
        }
    }

    // MARK: - Controls

    private var controls: some View {
        Button(action: advance) {
            Text(primaryTitle)
                .font(AwradTheme.displayFont(.headline, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(
                    AwradTheme.sage.opacity(canAdvance ? 1 : 0.4),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .disabled(!canAdvance)
    }

    private var primaryTitle: LocalizedStringKey {
        step == totalSteps - 1 ? "Begin Counting" : "Next"
    }

    private var canSkip: Bool {
        // Location (3) and notifications (5) are optional.
        step == 3 || step == 5
    }

    private var canAdvance: Bool {
        switch step {
        case 1: return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case totalSteps - 1: return !isCreatingGoal
        default: return true
        }
    }

    private func advance() {
        guard canAdvance else { return }
        switch step {
        case 1:
            store.updateUserName(name)
            step += 1
        case totalSteps - 1:
            finishOnboarding()
        default:
            step += 1
        }
    }

    private func finishOnboarding() {
        guard !isCreatingGoal else { return }
        isCreatingGoal = true

        let istighfarID = store.dhikrs.first {
            $0.id == BuiltInDhikrRegistry.isthighfar.id &&
                $0.catalogKey == BuiltInDhikrRegistry.isthighfar.catalogKey
        }?.id

        store.updateUserName(name)
        var goalID: AwradID?
        if let istighfarID {
            let goal = store.createGoal(dhikrID: istighfarID, target: max(firstGoalCount, 1))
            goalID = goal.id
        }
        store.completeOnboarding(name: name)

        if let goalID {
            store.selectedTab = .home
            router.homePath = [.counting(goalID: goalID)]
        }
    }

    // MARK: - State

    private func initializeOnboardingState() {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            name = store.preferences.userName
        }
        if selectedAudioIDs.isEmpty {
            selectedAudioIDs = Set(audioItems.map(\.id))
        }
    }

    private func downloadAllAudio() {
        let items = audioItems.filter { !$0.isDownloaded }
        guard !items.isEmpty else {
            downloadMessage = String(localized: "Audio library is ready.")
            return
        }
        isDownloading = true
        downloadProgress = 0
        downloadMessage = nil
        Task {
            var failures = 0
            for item in items {
                guard let url = item.audioURL else { continue }
                do {
                    let fileName = try await services.audio.downloadAudio(from: url, suggestedFileName: item.audioFileName)
                    await MainActor.run {
                        store.markDhikrAudioDownloaded(dhikrID: item.id, fileName: fileName)
                        downloadProgress += 1
                    }
                } catch {
                    await MainActor.run {
                        failures += 1
                        downloadProgress += 1
                    }
                }
            }
            await MainActor.run {
                isDownloading = false
                downloadMessage = failures == 0
                    ? String(localized: "Audio library is ready.")
                    : AwradLocalizer.format(
                        failures == 1 ? "Finished with %d failed download." : "Finished with %d failed downloads.",
                        language: language,
                        failures
                    )
            }
        }
    }

    // MARK: - Theme copy

    private func themeSymbol(_ mode: ColorSchemeMode) -> String {
        switch mode {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.stars.fill"
        }
    }
    private func themeTitle(_ mode: ColorSchemeMode) -> String {
        switch mode {
        case .system: "Automatic"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
    private func themeSubtitle(_ mode: ColorSchemeMode) -> String {
        switch mode {
        case .system: "Follows your device setting"
        case .light: "Always light"
        case .dark: "Always dark"
        }
    }
}

private struct CountStepper: View {
    @Binding var count: Int
    var quickValues: [Int] = [33, 70, 100, 313]

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 28) {
                stepButton(symbol: "minus") { count = max(count - 1, 1) }
                Text("\(count)")
                    .font(AwradTheme.bodyFont(48, weight: .bold))
                    .foregroundStyle(AwradTheme.ink)
                    .contentTransition(.numericText())
                    .frame(minWidth: 90)
                stepButton(symbol: "plus") { count = min(count + 1, 100_000) }
            }
            HStack(spacing: 8) {
                ForEach(quickValues, id: \.self) { value in
                    Button {
                        count = value
                    } label: {
                        Text("\(value)")
                            .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(count == value ? AwradTheme.sage : AwradTheme.sage.opacity(0.12), in: Capsule())
                            .foregroundStyle(count == value ? .white : AwradTheme.sage)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func stepButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(AwradTheme.bodyFont(.title2, weight: .bold))
                .foregroundStyle(AwradTheme.sage)
                .frame(width: 52, height: 52)
                .background(AwradTheme.sage.opacity(0.12), in: Circle())
        }
        .buttonStyle(.plain)
    }
}

/// The app's brand mark. Renders the real app icon if one is assigned in the asset
/// catalog; otherwise falls back to a tasteful sage/gold monogram tile.
private struct AppMark: View {
    var size: CGFloat = 88

    var body: some View {
        if Self.hasLogo {
            // SwiftUI Image auto-resolves the light/dark appearance variant and
            // updates reactively when the theme changes.
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.18), radius: 14, y: 8)
        } else {
            fallback
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.225, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
                        .stroke(AwradTheme.gold.opacity(0.30), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.18), radius: 14, y: 8)
        }
    }

    private var fallback: some View {
        ZStack {
            LinearGradient(
                colors: [AwradTheme.sage, AwradTheme.sageDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Text(verbatim: "\u{0623}") // أ
                .font(AwradTheme.arabicFont(size * 0.5, weight: .bold))
                .foregroundStyle(AwradTheme.gold)
        }
    }

    #if canImport(UIKit)
    private static let hasLogo = UIImage(named: "AppLogo") != nil
    #else
    private static let hasLogo = false
    #endif
}

private struct LanguageRow: View {
    let language: AppLanguage
    let selected: Bool
    let action: () -> Void

    private var nativeName: String {
        switch language {
        case .english: "English"
        case .arabic: "العربية"
        case .malayalam: "മലയാളം"
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(nativeName)
                    .font(language == .arabic ? AwradTheme.arabicFont(24) : AwradTheme.displayFont(20, weight: .medium))
                    .foregroundStyle(selected ? AwradTheme.sage : AwradTheme.ink)
                Spacer()
                Text(language.title)
                    .font(AwradTheme.bodyFont(.footnote))
                    .foregroundStyle(AwradTheme.subdued)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(AwradTheme.bodyFont(.title3))
                    .foregroundStyle(selected ? AwradTheme.sage : AwradTheme.subdued.opacity(0.4))
            }
            .padding(.vertical, 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Elite, editorial location step — clean search, current-location, hairline results.
private struct OnboardingLocationStep: View {
    @Environment(AwradStore.self) private var store
    @Environment(AppServices.self) private var services

    @State private var query = ""
    @State private var results: [CitySearchResult] = []
    @State private var isSearching = false
    @State private var isLocating = false
    @State private var message: String?

    private var language: AppLanguage { store.preferences.appLanguage }
    private var hasLocation: Bool {
        store.preferences.latitude != nil && store.preferences.longitude != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(LocalizedStringKey("Prayer Times"))
                    .font(AwradTheme.displayFont(28, weight: .bold))
                    .foregroundStyle(AwradTheme.ink)
                Text(LocalizedStringKey("Set your location for accurate prayer times."))
                    .font(AwradTheme.bodyFont(.subheadline))
                    .foregroundStyle(AwradTheme.subdued)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if hasLocation {
                selectedCard
            }

            searchField

            currentLocationButton

            if isSearching {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(LocalizedStringKey("Searching…"))
                        .font(AwradTheme.bodyFont(.footnote))
                        .foregroundStyle(AwradTheme.subdued)
                }
            }

            if !results.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(results.enumerated()), id: \.element) { index, result in
                        if index > 0 {
                            Rectangle().fill(AwradTheme.ink.opacity(0.07)).frame(height: 1)
                        }
                        resultRow(result)
                    }
                }
                .background(AwradTheme.surface.opacity(0.5), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            if let message, results.isEmpty {
                Text(message)
                    .font(AwradTheme.bodyFont(.footnote))
                    .foregroundStyle(AwradTheme.subdued)
            }

            // Prayer times preview, below the location inputs.
            if hasLocation, results.isEmpty, let summary = prayerSummary {
                prayerTimesPreview(summary)
            }
        }
        .padding(.horizontal, 8)
    }

    private var prayerSummary: PrayerTimesSummary? {
        services.prayerTimes.summary(
            for: Date(),
            latitude: store.preferences.latitude,
            longitude: store.preferences.longitude,
            method: store.preferences.calculationMethod,
            madhab: store.preferences.madhab
        )
    }

    private func prayerTimesPreview(_ summary: PrayerTimesSummary) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(summary.rows.filter(\.isPrayer).enumerated()), id: \.element) { index, row in
                if index > 0 {
                    Rectangle().fill(AwradTheme.ink.opacity(0.07)).frame(height: 1)
                }
                HStack {
                    Text(LocalizedStringKey(row.name))
                        .font(AwradTheme.bodyFont(.subheadline, weight: .medium))
                        .foregroundStyle(AwradTheme.ink)
                    Spacer()
                    Text(AwradLocalizer.formattedTime(row.date, language: language))
                        .font(AwradTheme.displayFont(.subheadline, weight: .semibold))
                        .foregroundStyle(AwradTheme.sage)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
            }
        }
        .background(AwradTheme.surface.opacity(0.5), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var selectedCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.circle.fill")
                .font(AwradTheme.bodyFont(.title2))
                .foregroundStyle(AwradTheme.sage)
            VStack(alignment: .leading, spacing: 2) {
                Text(store.preferences.cityName.isEmpty ? String(localized: "Prayer location") : store.preferences.cityName)
                    .font(AwradTheme.displayFont(.body, weight: .semibold))
                    .foregroundStyle(AwradTheme.ink)
                if let lat = store.preferences.latitude, let lon = store.preferences.longitude {
                    Text("\(lat.formatted(.number.precision(.fractionLength(3)))), \(lon.formatted(.number.precision(.fractionLength(3))))")
                        .font(AwradTheme.bodyFont(.caption))
                        .foregroundStyle(AwradTheme.subdued)
                }
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AwradTheme.sage)
        }
        .padding(14)
        .background(AwradTheme.sage.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AwradTheme.subdued)
            TextField("", text: $query, prompt: Text(LocalizedStringKey("Search for a city")).foregroundColor(AwradTheme.subdued.opacity(0.6)))
                .textInputAutocapitalization(.words)
                .submitLabel(.search)
                .foregroundStyle(AwradTheme.ink)
                .onSubmit(search)
            if !query.isEmpty {
                Button {
                    query = ""; results = []; message = nil
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(AwradTheme.subdued.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .font(AwradTheme.bodyFont(.body))
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(AwradTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AwradTheme.ink.opacity(0.08), lineWidth: 1))
        .onChange(of: query) { _, newValue in
            if newValue.trimmingCharacters(in: .whitespaces).count >= 2 { debounceSearch() }
            else if newValue.isEmpty { results = [] }
        }
    }

    private var currentLocationButton: some View {
        Button(action: useCurrentLocation) {
            HStack(spacing: 8) {
                if isLocating {
                    ProgressView().tint(AwradTheme.sage)
                } else {
                    Image(systemName: "location.fill")
                }
                Text(LocalizedStringKey(isLocating ? "Locating…" : "Use my location"))
            }
            .font(AwradTheme.displayFont(.subheadline, weight: .semibold))
            .foregroundStyle(AwradTheme.sage)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AwradTheme.sage.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isLocating)
    }

    private func resultRow(_ result: CitySearchResult) -> some View {
        Button {
            apply(result)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(AwradTheme.subdued)
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.name)
                        .font(AwradTheme.displayFont(.subheadline, weight: .semibold))
                        .foregroundStyle(AwradTheme.ink)
                    Text(result.displayName)
                        .font(AwradTheme.bodyFont(.caption))
                        .foregroundStyle(AwradTheme.subdued)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(AwradTheme.bodyFont(.caption))
                    .foregroundStyle(AwradTheme.subdued.opacity(0.5))
            }
            .padding(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @State private var searchTask: Task<Void, Never>?
    private func debounceSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 450_000_000)
            if Task.isCancelled { return }
            await runSearch()
        }
    }

    private func search() { Task { await runSearch() } }

    @MainActor
    private func runSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSearching = true
        message = nil
        let found = await services.locations.searchCity(trimmed)
        results = found
        isSearching = false
        if found.isEmpty {
            message = AwradLocalizer.localized("No matching cities found.", language: language)
        }
    }

    private func useCurrentLocation() {
        isLocating = true
        message = nil
        Task {
            do {
                let result = try await services.locations.requestCurrentLocation()
                await MainActor.run { apply(result); isLocating = false }
            } catch {
                await MainActor.run { message = error.localizedDescription; isLocating = false }
            }
        }
    }

    private func apply(_ result: CitySearchResult) {
        store.setPrayerLocation(result)
        results = []
        query = ""
        message = nil
    }
}

private struct WelcomeRow: View {
    let symbol: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: symbol)
                .font(AwradTheme.bodyFont(17, weight: .semibold))
                .foregroundStyle(AwradTheme.gold)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(title))
                    .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                    .foregroundStyle(AwradTheme.ink)
                Text(LocalizedStringKey(subtitle))
                    .font(AwradTheme.bodyFont(.footnote))
                    .foregroundStyle(AwradTheme.subdued)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 16)
    }
}

private struct OnboardingPanel<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        AwradCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(LocalizedStringKey(title))
                        .font(AwradTheme.displayFont(24))
                    Text(LocalizedStringKey(subtitle))
                        .font(AwradTheme.bodyFont(.subheadline))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                content
            }
        }
    }
}

private struct FeatureLine: View {
    let symbol: String
    let text: String

    var body: some View {
        Label {
            Text(LocalizedStringKey(text))
        } icon: {
            Image(systemName: symbol)
        }
        .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
        .foregroundStyle(AwradTheme.ink)
    }
}
