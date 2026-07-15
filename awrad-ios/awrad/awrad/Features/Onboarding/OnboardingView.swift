import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct OnboardingView: View {
    @Environment(AwradStore.self) private var store
    @Environment(AppServices.self) private var services
    @Environment(AppRouter.self) private var router
    @Environment(\.scenePhase) private var scenePhase

    @State private var step = 0
    @State private var openingPhase: OnboardingOpeningPhase = .bismillah
    @State private var name = ""
    @State private var selectedAudioIDs: Set<AwradID> = []
    @State private var downloadProgress = 0
    @State private var isDownloading = false
    @State private var downloadMessage: String?
    @State private var notificationAuthorizationState: NotificationAuthorizationState = .notDetermined
    @State private var selectedReminderPresets: Set<OnboardingReminderPreset> = []
    @State private var firstGoalCount = 70
    @State private var isCreatingGoal = false
    @State private var showsAuthSheet = false
    @State private var authMode: OnboardingAuthMode = .signIn
    @State private var authEmail = ""
    @State private var authPassword = ""
    @State private var isAuthenticating = false
    @State private var authError: String?
    @State private var reminderSchedulingError: String?
    @State private var pendingFirstGoal: Goal?

    private let totalSteps = 10

    private var audioItems: [Dhikr] {
        store.dhikrs.filter { $0.audioURL != nil }
    }
    private var language: AppLanguage { store.preferences.appLanguage }

    var body: some View {
        ZStack {
            onboardingBackground.ignoresSafeArea()

            if step == OnboardingStep.opening.rawValue {
                openingScene
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
                    if step != OnboardingStep.account.rawValue {
                        controls
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                            .padding(.bottom, 8)
                            .background(.ultraThinMaterial)
                    }
                }
            }
        }
        .animation(.snappy, value: step)
        .onAppear(perform: initializeOnboardingState)
        .task {
            await refreshNotificationAuthorization()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await refreshNotificationAuthorization() }
        }
        .onChange(of: firstGoalCount) { _, _ in
            guard step == OnboardingStep.firstGoal.rawValue else { return }
            persistOnboardingDraft()
        }
        .sheet(isPresented: $showsAuthSheet) {
            onboardingAuthSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .alert("Couldn’t schedule reminders", isPresented: Binding(
            get: { reminderSchedulingError != nil },
            set: { if !$0 { reminderSchedulingError = nil } }
        )) {
            Button("Retry", action: finishOnboarding)
            if pendingFirstGoal != nil {
                Button("Continue without reminders", action: finishWithoutReminders)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(reminderSchedulingError ?? "")
        }
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
            move(toRawStep: max(step - 1, 0))
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
            move(toRawStep: min(step + 1, totalSteps - 1))
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
        step == OnboardingStep.language.rawValue || step == OnboardingStep.name.rawValue
    }

    @ViewBuilder
    private var centeredStepBody: some View {
        switch step {
        case OnboardingStep.language.rawValue: languageStep
        case OnboardingStep.name.rawValue: nameStep
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

    // MARK: - Cinematic opening

    private var openingScene: some View {
        ZStack {
            openingGlow

            if openingPhase == .bismillah {
                bismillahBlock
                    .transition(
                        .opacity
                            .combined(with: .scale(scale: 0.94))
                            .combined(with: .offset(y: -10))
                    )
            } else {
                welcomeBlock
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }

            if openingPhase == .ready {
                VStack {
                    Spacer()
                    Button {
                        move(to: .language)
                    } label: {
                        Text(LocalizedStringKey("Begin"))
                            .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(AwradTheme.sage, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 20)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard openingPhase != .ready else { return }
            withAnimation(.easeInOut(duration: 0.6)) {
                openingPhase = .ready
            }
        }
        .task(id: openingPhase) {
            do {
                switch openingPhase {
                case .bismillah:
                    try await Task.sleep(for: .milliseconds(3_100))
                    withAnimation(.easeInOut(duration: 0.5)) {
                        openingPhase = .welcome
                    }
                case .welcome:
                    try await Task.sleep(for: .milliseconds(1_200))
                    withAnimation(.easeOut(duration: 0.6)) {
                        openingPhase = .ready
                    }
                case .ready:
                    break
                }
            } catch {
                // A phase change cancels the previous beat; the new phase owns the timeline.
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var openingGlow: some View {
        RadialGradient(
            colors: [AwradTheme.sage.opacity(0.12), .clear],
            center: .center,
            startRadius: 24,
            endRadius: 360
        )
        .ignoresSafeArea()
    }

    private var bismillahBlock: some View {
        VStack(spacing: 18) {
            Text(verbatim: "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ")
                .font(AwradTheme.arabicFont(34))
                .foregroundStyle(AwradTheme.sageDark)
                .multilineTextAlignment(.center)
                .lineSpacing(8)

            HStack(spacing: 10) {
                Rectangle().fill(AwradTheme.sage.opacity(0.45)).frame(width: 48, height: 1)
                Image(systemName: "diamond.fill")
                    .font(.system(size: 7))
                    .foregroundStyle(AwradTheme.sage)
                Rectangle().fill(AwradTheme.sage.opacity(0.45)).frame(width: 48, height: 1)
            }

            let translation = String(localized: "In the name of Allah, the Most Compassionate, the Most Merciful")
            if !translation.isEmpty {
                Text(translation)
                    .font(AwradTheme.bodyFont(.title3, weight: .regular))
                    .foregroundStyle(AwradTheme.subdued)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 32)
    }

    private var welcomeBlock: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(AwradTheme.sage.opacity(0.10))
                    .frame(width: 196, height: 196)
                    .blur(radius: 1)
                AppMark(size: 148)
            }

            Text(LocalizedStringKey("As-salamu alaykum"))
                .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                .tracking(2)
                .foregroundStyle(AwradTheme.sage)
                .multilineTextAlignment(.center)
                .padding(.top, 30)

            Text(LocalizedStringKey("Welcome to Awrad"))
                .font(AwradTheme.displayFont(38, weight: .bold))
                .foregroundStyle(AwradTheme.sageDark)
                .multilineTextAlignment(.center)
                .padding(.top, 10)

            Text(LocalizedStringKey("Your daily dhikr companion"))
                .font(AwradTheme.bodyFont(.title3, weight: .regular))
                .foregroundStyle(AwradTheme.subdued)
                .multilineTextAlignment(.center)
                .padding(.top, 10)
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Steps

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case OnboardingStep.account.rawValue:
            accountStep
        case OnboardingStep.location.rawValue:
            OnboardingLocationStep()
        case OnboardingStep.notifications.rawValue:
            OnboardingPanel(title: "Never miss a moment of dhikr", subtitle: "Gentle reminders at the times you choose help daily awrad become habit.") {
                notificationsStep
            }
        case OnboardingStep.reminderPresets.rawValue:
            OnboardingPanel(title: "When should we remind you?", subtitle: "Choose the moments for your daily dhikr — pick as many as you like.") {
                reminderPresetsStep
            }
        case OnboardingStep.audio.rawValue:
            OnboardingPanel(title: "Prepare guided audio", subtitle: "Download recitations now so audio-assisted counting works offline.") {
                audioStep
            }
        case OnboardingStep.goalIntro.rawValue:
            goalIntroStep
        default:
            firstGoalStep
        }
    }

    // MARK: - Account

    private var accountStep: some View {
        OnboardingPanel(
            title: "Keep your progress safe",
            subtitle: "Sign in to sync goals and streaks across your devices. Local reading and counting always remain available offline."
        ) {
            VStack(spacing: 14) {
                if services.auth.isLoggedIn {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(AwradTheme.bodyFont(.title2))
                            .foregroundStyle(AwradTheme.sage)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(LocalizedStringKey("You're signed in"))
                                .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                            if let email = services.auth.userEmail {
                                Text(email)
                                    .font(AwradTheme.bodyFont(.footnote))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(16)
                    .awradGlassSurface(cornerRadius: 18)

                    Button("Next") { move(to: .name) }
                        .awradPrimaryButton()
                } else {
                    Button {
                        authMode = .signIn
                        authError = nil
                        showsAuthSheet = true
                    } label: {
                        Label("Continue with email", systemImage: "envelope.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .awradPrimaryButton()

                    Button("Continue as guest") { move(to: .name) }
                        .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                        .foregroundStyle(AwradTheme.sage)
                        .frame(minHeight: 44)
                }
            }
        }
    }

    private var onboardingAuthSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(LocalizedStringKey(authMode == .signIn ? "Welcome back" : "Create your account"))
                        .font(AwradTheme.displayFont(.title, weight: .bold))
                    Text(LocalizedStringKey("Your goals and streaks will follow you to any device."))
                        .font(AwradTheme.bodyFont(.subheadline))
                        .foregroundStyle(.secondary)
                }

                TextField("Email", text: $authEmail)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(14)
                    .awradGlassSurface(cornerRadius: 14, interactive: true)

                SecureField("Password", text: $authPassword)
                    .textContentType(authMode == .signIn ? .password : .newPassword)
                    .padding(14)
                    .awradGlassSurface(cornerRadius: 14, interactive: true)

                if authMode == .createAccount {
                    Text(LocalizedStringKey(AuthPasswordPolicy.guidance))
                        .font(AwradTheme.bodyFont(.footnote))
                        .foregroundStyle(
                            AuthPasswordPolicy.isValid(authPassword) || authPassword.isEmpty
                                ? Color.secondary
                                : Color.red
                        )
                }

                if let authError {
                    Text(authError)
                        .font(AwradTheme.bodyFont(.footnote))
                        .foregroundStyle(.red)
                        .accessibilityLabel(Text("Authentication error: \(authError)"))
                }

                Button(action: submitOnboardingAuth) {
                    Group {
                        if isAuthenticating {
                            ProgressView().tint(.white)
                        } else {
                            Text(LocalizedStringKey(authMode == .signIn ? "Sign in" : "Create account"))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .awradPrimaryButton()
                .disabled(
                    isAuthenticating || authEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        authPassword.isEmpty ||
                        (authMode == .createAccount && !AuthPasswordPolicy.isValid(authPassword))
                )

                Button(authMode == .signIn ? "New to Awrad? Create an account" : "Already have an account? Sign in") {
                    authMode = authMode == .signIn ? .createAccount : .signIn
                    authError = nil
                }
                .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                .foregroundStyle(AwradTheme.sage)
                .frame(maxWidth: .infinity, minHeight: 44)

                Spacer(minLength: 0)
            }
            .padding(20)
            .background(AwradTheme.background.ignoresSafeArea())
            .navigationTitle(Text(LocalizedStringKey("Your account")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showsAuthSheet = false }
                }
            }
        }
    }

    private func submitOnboardingAuth() {
        let email = authEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty, !authPassword.isEmpty else {
            authError = String(localized: "Enter your email and password to continue.")
            return
        }
        guard authMode == .signIn || AuthPasswordPolicy.isValid(authPassword) else {
            authError = AuthPasswordPolicy.guidance
            return
        }
        guard !isAuthenticating else { return }
        isAuthenticating = true
        authError = nil
        Task {
            do {
                if authMode == .signIn {
                    try await services.auth.login(email: email, password: authPassword)
                } else {
                    try await services.auth.register(email: email, password: authPassword)
                }
                isAuthenticating = false
                showsAuthSheet = false
                move(to: .name)
            } catch {
                isAuthenticating = false
                authError = error.localizedDescription
            }
        }
    }

    // MARK: - Reminder presets

    private var reminderPresetsStep: some View {
        VStack(spacing: 10) {
            ForEach(OnboardingReminderPreset.allCases) { preset in
                let selected = selectedReminderPresets.contains(preset)
                Button {
                    if selected {
                        selectedReminderPresets.remove(preset)
                    } else {
                        selectedReminderPresets.insert(preset)
                    }
                    persistOnboardingDraft()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: preset.symbol)
                            .font(AwradTheme.bodyFont(.title3, weight: .semibold))
                            .foregroundStyle(selected ? .white : AwradTheme.sage)
                            .frame(width: 40, height: 40)
                            .background(selected ? AwradTheme.sage : AwradTheme.sage.opacity(0.12), in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(LocalizedStringKey(preset.title))
                                .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                            Text(LocalizedStringKey(preset.subtitle))
                                .font(AwradTheme.bodyFont(.footnote))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer()
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selected ? AwradTheme.sage : .secondary)
                    }
                    .padding(14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .awradGlassSurface(cornerRadius: 16, interactive: true)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }

            Text(LocalizedStringKey("These become reminders on your first goal — edit or remove them anytime."))
                .font(AwradTheme.bodyFont(.footnote))
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }

    // MARK: - Goal introduction

    private var goalIntroStep: some View {
        OnboardingPanel(
            title: "A prophetic practice",
            subtitle: "Even the most beloved of Allah ﷺ sought forgiveness every single day."
        ) {
            VStack(spacing: 18) {
                Text(LocalizedStringKey("onboarding_goalintro_hadith_arabic"))
                    .font(AwradTheme.arabicFont(25))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AwradTheme.sageDark)

                Text(LocalizedStringKey("By Allah, I seek Allah's forgiveness and turn to Him in repentance more than seventy times a day."))
                    .font(AwradTheme.bodyFont(.body))
                    .multilineTextAlignment(.center)

                Text(LocalizedStringKey("Sahih al-Bukhari · 6307"))
                    .font(AwradTheme.bodyFont(.caption, weight: .semibold))
                    .foregroundStyle(AwradTheme.gold)

                Divider()

                Text(LocalizedStringKey("Begin where he began — with istighfar."))
                    .font(AwradTheme.displayFont(.headline, weight: .semibold))
                    .multilineTextAlignment(.center)
            }
            .padding(18)
            .awradGlassSurface(cornerRadius: 22)
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
            Image(systemName: notificationAuthorizationState == .authorized
                  ? "checkmark.circle.fill"
                  : notificationAuthorizationState == .denied ? "bell.slash.fill" : "bell.badge.fill")
                .font(AwradTheme.bodyFont(44))
                .foregroundStyle(notificationAuthorizationState == .authorized ? AwradTheme.sage : AwradTheme.gold)
                .frame(maxWidth: .infinity, alignment: .center)

            FeatureLine(symbol: "alarm.fill", text: "Reminders for your daily dhikr goals")
            FeatureLine(symbol: "sun.horizon.fill", text: "Prayer-time aware nudges")

            Button {
                if notificationAuthorizationState == .denied {
                    #if canImport(UIKit)
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                    #endif
                } else {
                    Task {
                        await services.notifications.requestAuthorizationIfUseful()
                        notificationAuthorizationState = await services.notifications.authorizationState()
                    }
                }
            } label: {
                Text(LocalizedStringKey(notificationAuthorizationState == .authorized
                     ? "Notifications set"
                     : notificationAuthorizationState == .denied ? "Open notification settings" : "Enable notifications"))
                    .frame(maxWidth: .infinity)
            }
            .awradPrimaryButton()
            .disabled(notificationAuthorizationState == .authorized)

            if notificationAuthorizationState == .denied {
                Text("Notifications are required to continue. Enable them in Settings, then return to Awrad.")
                    .font(AwradTheme.bodyFont(.footnote))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            } else if notificationAuthorizationState != .authorized {
                Text("Allow notifications to continue onboarding.")
                    .font(AwradTheme.bodyFont(.footnote))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
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
        OnboardingPanel(title: "Your first dhikr goal", subtitle: "One tap, and the Prophet's ﷺ daily practice becomes yours too.") {
            VStack(spacing: 18) {
                istighfarCard
                CountStepper(count: $firstGoalCount, quickValues: [70, 100])
                Text(LocalizedStringKey("Seventy istighfar a day — the number the Prophet ﷺ himself named. Keep it, or set your own pace."))
                    .font(AwradTheme.bodyFont(.footnote))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
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
        step == OnboardingStep.firstGoal.rawValue ? "Begin Counting" : "Next"
    }

    private var canSkip: Bool {
        guard let onboardingStep = OnboardingStep(rawValue: step) else { return false }
        return OnboardingForwardGate.canSkip(onboardingStep)
    }

    private var canAdvance: Bool {
        guard let onboardingStep = OnboardingStep(rawValue: step) else { return false }
        return OnboardingForwardGate.canAdvance(
            onboardingStep,
            name: name,
            notificationAuthorizationState: notificationAuthorizationState,
            isCreatingGoal: isCreatingGoal
        )
    }

    private func advance() {
        guard canAdvance else { return }
        switch step {
        case OnboardingStep.name.rawValue:
            store.updateUserName(name)
            move(to: .location)
        case OnboardingStep.firstGoal.rawValue:
            finishOnboarding()
        default:
            move(toRawStep: min(step + 1, totalSteps - 1))
        }
    }

    private func finishOnboarding() {
        guard !isCreatingGoal else { return }

        let istighfarID = store.dhikrs.first {
            $0.id == BuiltInDhikrRegistry.isthighfar.id &&
                $0.catalogKey == BuiltInDhikrRegistry.isthighfar.catalogKey
        }?.id
        guard let istighfarID,
              let prepared = store.firstOnboardingGoal(
                dhikrID: istighfarID,
                target: max(firstGoalCount, 1),
                reminders: resolvedOnboardingReminders()
              ) else {
            isCreatingGoal = false
            return
        }
        isCreatingGoal = true
        pendingFirstGoal = prepared
        Task {
            let prayerTimes = ReminderScheduleBuilder.prayerSummaries(
                for: prepared,
                preferences: store.preferences,
                prayerTimeService: services.prayerTimes
            )
            let result = await services.notifications.scheduleGoalReminders(
                for: prepared,
                dhikrTitle: store.title(for: prepared),
                language: language,
                prayerTimes: prayerTimes
            )
            guard result.succeeded else {
                isCreatingGoal = false
                reminderSchedulingError = result.localizedFailureMessage(language: language)
                return
            }
            guard commitOnboarding(firstGoal: prepared, reminderPresetKeys: selectedReminderPresets.map(\.rawValue)) else {
                _ = await services.notifications.cancelGoalReminders(goalID: prepared.id)
                isCreatingGoal = false
                reminderSchedulingError = AwradLocalizer.localized("Couldn’t save changes. Try again.", language: language)
                return
            }
        }
    }

    private func finishWithoutReminders() {
        guard var prepared = pendingFirstGoal else { return }
        prepared.reminders = []
        reminderSchedulingError = nil
        isCreatingGoal = true
        guard commitOnboarding(firstGoal: prepared, reminderPresetKeys: []) else {
            isCreatingGoal = false
            reminderSchedulingError = AwradLocalizer.localized("Couldn’t save changes. Try again.", language: language)
            return
        }
    }

    @discardableResult
    private func commitOnboarding(firstGoal: Goal, reminderPresetKeys: [String]) -> Bool {
        guard let saved = store.completeOnboarding(
            name: name,
            reminderPresetKeys: reminderPresetKeys,
            firstGoal: firstGoal
        ) else { return false }
        pendingFirstGoal = nil
        store.selectedTab = .home
        router.homePath = [.counting(goalID: saved.id, slotID: nil)]
        return true
    }

    // MARK: - State

    private func initializeOnboardingState() {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            name = store.preferences.userName
        }
        step = min(max(store.preferences.onboardingStep, 0), totalSteps - 1)
        firstGoalCount = max(store.preferences.onboardingFirstGoalCount, 1)
        selectedReminderPresets = Set(
            store.preferences.onboardingReminderPresetKeys.compactMap(OnboardingReminderPreset.init(rawValue:))
        )
        if selectedAudioIDs.isEmpty {
            selectedAudioIDs = Set(audioItems.map(\.id))
        }
    }

    private func move(to destination: OnboardingStep) {
        move(toRawStep: destination.rawValue)
    }

    private func move(toRawStep newStep: Int) {
        let clamped = min(max(newStep, 0), totalSteps - 1)
        withAnimation(.snappy) {
            step = clamped
        }
        persistOnboardingDraft(step: clamped)
    }

    private func persistOnboardingDraft(step: Int? = nil) {
        store.updatePreferences {
            if let step { $0.onboardingStep = step }
            $0.onboardingFirstGoalCount = max(firstGoalCount, 1)
            $0.onboardingReminderPresetKeys = selectedReminderPresets.map(\.rawValue).sorted()
        }
    }

    private func refreshNotificationAuthorization() async {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--awrad-ui-force-notifications-undetermined") {
            notificationAuthorizationState = .notDetermined
            return
        }
        #endif
        notificationAuthorizationState = await services.notifications.authorizationState()
    }

    private func resolvedOnboardingReminders(now: Date = Date()) -> [GoalReminder] {
        guard !selectedReminderPresets.isEmpty else { return [] }
        let prayerTimes: PrayerTimesSummary?
        if let latitude = store.preferences.latitude, let longitude = store.preferences.longitude {
            prayerTimes = services.prayerTimes.summary(
                for: now,
                latitude: latitude,
                longitude: longitude,
                method: store.preferences.calculationMethod,
                madhab: store.preferences.madhab
            )
        } else {
            prayerTimes = nil
        }

        let calendar = Calendar.current
        return selectedReminderPresets.sorted { $0.sortOrder < $1.sortOrder }.enumerated().map { index, preset in
            let components = preset.timeComponents(prayerTimes: prayerTimes, calendar: calendar)
            return GoalReminder(
                reminderType: .fixedTime,
                hour: components.hour,
                minute: components.minute,
                enabled: true,
                sortOrder: index
            )
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

enum OnboardingStep: Int, CaseIterable {
    case opening
    case language
    case account
    case name
    case location
    case notifications
    case reminderPresets
    case audio
    case goalIntro
    case firstGoal
}

enum OnboardingOpeningPhase: Equatable {
    case bismillah
    case welcome
    case ready
}

enum OnboardingForwardGate {
    static func canSkip(_ step: OnboardingStep) -> Bool {
        step == .location || step == .audio
    }

    static func canAdvance(
        _ step: OnboardingStep,
        name: String,
        notificationAuthorizationState: NotificationAuthorizationState,
        isCreatingGoal: Bool
    ) -> Bool {
        switch step {
        case .name:
            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .notifications:
            notificationAuthorizationState == .authorized
        case .firstGoal:
            !isCreatingGoal
        default:
            true
        }
    }
}

private enum OnboardingAuthMode {
    case signIn
    case createAccount
}

private enum OnboardingReminderPreset: String, CaseIterable, Identifiable {
    case afterFajr
    case morning
    case afterAsr
    case afterMaghrib

    var id: String { rawValue }

    var sortOrder: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }

    var title: String {
        switch self {
        case .afterFajr: "After Fajr"
        case .morning: "Morning"
        case .afterAsr: "After Asr"
        case .afterMaghrib: "After Maghrib"
        }
    }

    var subtitle: String {
        switch self {
        case .afterFajr: "30 minutes after the dawn prayer"
        case .morning: "A bright start to the day"
        case .afterAsr: "30 minutes after the afternoon prayer"
        case .afterMaghrib: "As the day closes"
        }
    }

    var symbol: String {
        switch self {
        case .afterFajr: "sunrise.fill"
        case .morning: "sun.max.fill"
        case .afterAsr: "sun.haze.fill"
        case .afterMaghrib: "sunset.fill"
        }
    }

    func timeComponents(
        prayerTimes: PrayerTimesSummary?,
        calendar: Calendar
    ) -> DateComponents {
        let resolvedDate: Date?
        let fallback: (hour: Int, minute: Int)
        switch self {
        case .afterFajr:
            resolvedDate = prayerTimes.flatMap { calendar.date(byAdding: .minute, value: 30, to: $0.fajr) }
            fallback = (6, 15)
        case .morning:
            resolvedDate = nil
            fallback = (7, 0)
        case .afterAsr:
            resolvedDate = prayerTimes.flatMap { calendar.date(byAdding: .minute, value: 30, to: $0.asr) }
            fallback = (17, 0)
        case .afterMaghrib:
            resolvedDate = prayerTimes.flatMap { calendar.date(byAdding: .minute, value: 15, to: $0.maghrib) }
            fallback = (19, 15)
        }
        guard let resolvedDate else {
            return DateComponents(hour: fallback.hour, minute: fallback.minute)
        }
        return calendar.dateComponents([.hour, .minute], from: resolvedDate)
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
