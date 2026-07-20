import SwiftUI

struct AccountRecoveryView: View {
    @Environment(AwradStore.self) private var store
    @Environment(AppServices.self) private var services
    @State private var showsLogin = false
    @State private var showsVerification = false
    @State private var showsLocalResetConfirmation = false
    @State private var isResettingLocalState = false
    @State private var localResetError: String?
    let verificationToken: String?
    let onVerificationHandled: () -> Void

    init(
        verificationToken: String? = nil,
        onVerificationHandled: @escaping () -> Void = {}
    ) {
        self.verificationToken = verificationToken
        self.onVerificationHandled = onVerificationHandled
    }

    var body: some View {
        ZStack {
            AwradTheme.background.ignoresSafeArea()

            ScrollView {
                AwradCard(padding: 24) {
                    VStack(spacing: 20) {
                        Image(systemName: "icloud.and.arrow.down.fill")
                            .font(AwradTheme.bodyFont(36, weight: .semibold))
                            .foregroundStyle(AwradTheme.sage)
                            .frame(width: 78, height: 78)
                            .background(AwradTheme.mint.opacity(0.28), in: Circle())

                        VStack(spacing: 10) {
                            Text("Previous progress found")
                                .font(AwradTheme.displayFont(28))
                                .foregroundStyle(AwradTheme.ink)
                                .multilineTextAlignment(.center)

                            Text(recoveryMessage)
                                .font(AwradTheme.bodyFont(.body))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        Button {
                            showsLogin = true
                        } label: {
                            Text("Sign in to restore").frame(maxWidth: .infinity)
                        }
                        .awradPrimaryButton()
                        .disabled(isResettingLocalState)

                        Button(role: .destructive) {
                            showsLocalResetConfirmation = true
                        } label: {
                            Label("Start fresh on this device", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(isResettingLocalState)

                        Text("Prefer not to restore? You can erase this device and continue with a clean, signed-out app.")
                            .font(AwradTheme.bodyFont(.footnote))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        Text("Awrad signed out the previous session because this is a new app installation. Your cloud progress has not been deleted.")
                            .font(AwradTheme.bodyFont(.footnote))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(24)
                .frame(maxWidth: 560)
            }
        }
        .sheet(isPresented: $showsLogin) {
            NavigationStack {
                if showsVerification {
                    VerifyEmailView(
                        token: verificationToken,
                        onVerified: {
                            onVerificationHandled()
                            showsLogin = false
                        },
                        onSignIn: { _ in
                            onVerificationHandled()
                            showsVerification = false
                        }
                    )
                } else {
                    LoginView(
                        prefilledEmail: services.auth.pendingVerificationEmail
                            ?? services.auth.recoveryUserEmail,
                        onSuccess: { showsLogin = false },
                        onVerificationRequired: { showsVerification = true }
                    )
                }
            }
        }
        .onChange(of: verificationToken, initial: true) { _, token in
            guard token != nil else { return }
            showsVerification = true
            showsLogin = true
        }
        .confirmationDialog(
            "Start fresh on this device?",
            isPresented: $showsLocalResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Erase local data", role: .destructive, action: resetLocalState)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently erases goals, counts, custom dhikrs, wird progress, preferences, and sync history on this device. Data already backed up to your account stays in the cloud.")
        }
        .alert("Couldn’t reset local data", isPresented: Binding(
            get: { localResetError != nil },
            set: { if !$0 { localResetError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(localResetError ?? "")
        }
    }

    private var recoveryMessage: String {
        guard let email = services.auth.recoveryUserEmail, !email.isEmpty else {
            return AwradLocalizer.localized(
                "Sign in again to safely restore the goals and counts previously backed up from this device.",
                language: store.preferences.appLanguage
            )
        }
        return AwradLocalizer.format(
            "We found progress previously backed up with %@. Sign in again to safely restore your goals and counts.",
            language: store.preferences.appLanguage,
            masked(email)
        )
    }

    private func masked(_ email: String) -> String {
        let parts = email.split(separator: "@", maxSplits: 1).map(String.init)
        guard parts.count == 2, let first = parts[0].first else { return email }
        return "\(first)••••@\(parts[1])"
    }

    private func resetLocalState() {
        guard !isResettingLocalState else { return }
        isResettingLocalState = true
        localResetError = nil
        Task {
            do {
                try store.resetLocalState()
                services.auth.resetLocalAuthentication()
                _ = await services.clearScheduledRemindersForLocalReset()
            } catch {
                localResetError = error.localizedDescription
            }
            isResettingLocalState = false
        }
    }
}

struct CommunityView: View {
    @Environment(AwradStore.self) private var store
    @Environment(AppServices.self) private var services
    @Environment(AppRouter.self) private var router
    @State private var stats: CommunityStatsResponse?
    @State private var isLoadingStats = false
    @State private var statsLoadFailed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Keep your practice connected and steady.")
                    .font(AwradTheme.bodyFont(.body))
                    .foregroundStyle(.secondary)

                communityStatsSection

                if services.auth.isLoggedIn, services.auth.userEmailVerified {
                    loggedInCard
                } else if services.auth.pendingVerificationEmail != nil ||
                            (services.auth.isLoggedIn && !services.auth.userEmailVerified) {
                    verificationRequiredCard
                } else {
                    guestCard
                }
            }
            .padding(20)
            .padding(.bottom, 96)
        }
        .background(AwradTheme.background)
        .navigationTitle("Community")
        .task { await loadStats() }
        .refreshable { await loadStats(forceRefresh: true) }
        .toolbar {
            if services.auth.isLoggedIn {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Active Sessions") {
                            router.navigate(.sessions, in: .community)
                        }
                        Button("Log Out", role: .destructive) {
                            Task {
                                await services.auth.logout()
                            }
                        }
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }
                    .accessibilityLabel("Account menu")
                }
            }
        }
    }

    @ViewBuilder
    private var communityStatsSection: some View {
        if let stats {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(localized("Community at a glance"))
                        .font(AwradTheme.displayFont(.headline))
                        .foregroundStyle(AwradTheme.ink)
                    Spacer()
                    Button {
                        Task { await loadStats(forceRefresh: true) }
                    } label: {
                        if isLoadingStats {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(isLoadingStats)
                    .accessibilityLabel(localized("Refresh community stats"))
                }

                statsHero(stats)

                HStack(alignment: .top, spacing: 12) {
                    metricCard(
                        value: stats.totalTrackedGoals.formatted(.number.locale(locale)),
                        label: localized("Tracked goals"),
                        icon: "target"
                    )
                    metricCard(
                        value: stats.approximateDhikrHours.formatted(
                            .number.precision(.fractionLength(0...1)).locale(locale)
                        ),
                        label: localized("Approx. hours"),
                        icon: "clock.fill"
                    )
                }

                dailyChart(stats.dailyCounts)

                VStack(alignment: .leading, spacing: 5) {
                    Label(
                        AwradLocalizer.format(
                            "Synced %@",
                            language: language,
                            stats.asOf.formatted(
                                .dateTime
                                    .year().month(.abbreviated).day()
                                    .hour().minute()
                                    .locale(locale)
                            )
                        ),
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                    Text(AwradLocalizer.format(
                        "Estimates assume %d second per count.",
                        language: language,
                        stats.secondsPerCount
                    ))
                    Text(localized("Community totals are approximate and may change as progress syncs."))
                }
                .font(AwradTheme.bodyFont(.footnote))
                .foregroundStyle(AwradTheme.subdued)
            }
        } else if isLoadingStats {
            AwradCard(padding: 24) {
                HStack(spacing: 14) {
                    ProgressView().tint(AwradTheme.sage)
                    Text(localized("Loading community totals…"))
                        .font(AwradTheme.bodyFont(.body, weight: .medium))
                        .foregroundStyle(AwradTheme.ink)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }
        } else if statsLoadFailed {
            AwradCard(padding: 22) {
                VStack(alignment: .leading, spacing: 14) {
                    Label(localized("Community totals are unavailable"), systemImage: "wifi.exclamationmark")
                        .font(AwradTheme.displayFont(.headline))
                        .foregroundStyle(AwradTheme.ink)
                    Text(localized("Check your connection and try again."))
                        .font(AwradTheme.bodyFont(.subheadline))
                        .foregroundStyle(.secondary)
                    Button(localized("Retry")) { Task { await loadStats() } }
                        .buttonStyle(.bordered)
                        .tint(AwradTheme.sage)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func statsHero(_ stats: CommunityStatsResponse) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(localized("Community dhikr"), systemImage: "person.3.fill")
                .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                .foregroundStyle(AwradTheme.sageDark)
            Text(compactCount(stats.approximateTotalCounts))
                .font(AwradTheme.displayFont(.largeTitle, weight: .bold))
                .minimumScaleFactor(0.65)
                .lineLimit(1)
                .foregroundStyle(AwradTheme.ink)
            Text(localized("Approximate counts together"))
                .font(AwradTheme.bodyFont(.body, weight: .medium))
                .foregroundStyle(AwradTheme.subdued)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(
            LinearGradient(
                colors: [AwradTheme.mint.opacity(0.72), AwradTheme.gold.opacity(0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(AwradLocalizer.format(
            "Approximately %@ community counts",
            language: language,
            fullCount(stats.approximateTotalCounts)
        ))
    }

    private func metricCard(value: String, label: String, icon: String) -> some View {
        AwradCard(padding: 16) {
            VStack(alignment: .leading, spacing: 9) {
                Image(systemName: icon).foregroundStyle(AwradTheme.sage)
                Text(value)
                    .font(AwradTheme.displayFont(.title2, weight: .bold))
                    .foregroundStyle(AwradTheme.ink)
                Text(label)
                    .font(AwradTheme.bodyFont(.caption, weight: .medium))
                    .foregroundStyle(AwradTheme.subdued)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(label), \(value)")
        }
    }

    private func dailyChart(_ counts: [CommunityStatsResponse.DailyCount]) -> some View {
        let days = Array(counts.suffix(7))
        let maximum = max(days.map(\.approximateCount.magnitudeForChart).max() ?? 0, 1)
        return AwradCard(padding: 18) {
            VStack(alignment: .leading, spacing: 16) {
                Text(localized("Last seven days"))
                    .font(AwradTheme.displayFont(.headline))
                    .foregroundStyle(AwradTheme.ink)
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(days) { day in
                        VStack(spacing: 7) {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(AwradTheme.sage.gradient)
                                .frame(height: max(5, 76 * day.approximateCount.magnitudeForChart / maximum))
                            Text(weekday(for: day.date))
                                .font(AwradTheme.bodyFont(.caption2, weight: .medium))
                                .foregroundStyle(AwradTheme.subdued)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(AwradLocalizer.format(
                            "%@, approximately %@ counts",
                            language: language,
                            weekday(for: day.date),
                            fullCount(day.approximateCount)
                        ))
                    }
                }
                .frame(height: 102, alignment: .bottom)
            }
        }
    }

    private var language: AppLanguage { store.preferences.appLanguage }
    private var locale: Locale { Locale(identifier: language.localeIdentifier) }

    private func localized(_ key: String) -> String {
        AwradLocalizer.localized(key, language: language)
    }

    private func compactCount(_ count: DecimalIntegerString) -> String {
        guard let value = Int64(count.rawValue) else { return fullCount(count) }
        return value.formatted(.number.notation(.compactName).locale(locale))
    }

    private func fullCount(_ count: DecimalIntegerString) -> String {
        let separator = locale.groupingSeparator ?? ","
        let groups = stride(from: count.rawValue.count, to: 0, by: -3).map { end -> String in
            let start = max(0, end - 3)
            let lower = count.rawValue.index(count.rawValue.startIndex, offsetBy: start)
            let upper = count.rawValue.index(count.rawValue.startIndex, offsetBy: end)
            return String(count.rawValue[lower..<upper])
        }.reversed()
        let asciiGrouped = groups.joined(separator: separator)
        return asciiGrouped.reduce(into: "") { result, character in
            if let digit = character.wholeNumberValue {
                result += digit.formatted(.number.locale(locale))
            } else {
                result.append(character)
            }
        }
    }

    private func weekday(for date: String) -> String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.calendar = Calendar(identifier: .gregorian)
        parser.dateFormat = "yyyy-MM-dd"
        guard let value = parser.date(from: date) else { return date }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("EEEEE")
        return formatter.string(from: value)
    }

    @MainActor
    private func loadStats(forceRefresh: Bool = false) async {
        guard !isLoadingStats else { return }
        isLoadingStats = true
        statsLoadFailed = false
        do {
            stats = try await services.auth.publicRequest(
                "api/community/stats",
                forceRefresh: forceRefresh
            )
        } catch {
            statsLoadFailed = true
        }
        isLoadingStats = false
    }

    private var guestCard: some View {
        AwradCard(padding: 22) {
            VStack(spacing: 20) {
                communityMark

                VStack(spacing: 10) {
                    Text("Join the Community")
                        .font(AwradTheme.displayFont(25))
                        .foregroundStyle(AwradTheme.ink)
                        .multilineTextAlignment(.center)
                    Text("Connect with fellow practitioners, share your progress, and stay inspired together.")
                        .font(AwradTheme.bodyFont(.body))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
                    Button {
                        router.navigate(.signup, in: .community)
                    } label: {
                        Text("Sign Up").frame(maxWidth: .infinity)
                    }
                    .awradPrimaryButton()

                    Button {
                        router.navigate(.login, in: .community)
                    } label: {
                        Text("Log In").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(AwradTheme.sage)
                    .buttonBorderShape(.roundedRectangle(radius: 24))
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var loggedInCard: some View {
        AwradCard(padding: 22) {
            VStack(spacing: 18) {
                communityMark
                Text("Community features coming soon!")
                    .font(AwradTheme.displayFont(24))
                    .foregroundStyle(AwradTheme.ink)
                    .multilineTextAlignment(.center)
                if let email = services.auth.userEmail {
                    Text("Logged in as \(email)")
                        .font(AwradTheme.bodyFont(.subheadline))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var verificationRequiredCard: some View {
        AwradCard(padding: 22) {
            VStack(spacing: 16) {
                Image(systemName: "envelope.badge.shield.half.filled")
                    .font(AwradTheme.bodyFont(34, weight: .semibold))
                    .foregroundStyle(AwradTheme.gold)
                    .frame(width: 76, height: 76)
                    .background(AwradTheme.gold.opacity(0.12), in: Circle())

                Text("Verify your email")
                    .font(AwradTheme.displayFont(24))
                    .foregroundStyle(AwradTheme.ink)

                Text("Open the verification link we sent, or enter its token to finish securing your account.")
                    .font(AwradTheme.bodyFont(.body))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if let email = services.auth.pendingVerificationEmail ?? services.auth.userEmail {
                    Text(email)
                        .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                        .foregroundStyle(AwradTheme.sage)
                }

                Button {
                    router.navigate(.verifyEmail(token: nil), in: .community)
                } label: {
                    Text("Enter verification token").frame(maxWidth: .infinity)
                }
                .awradPrimaryButton()
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var communityMark: some View {
        Image(systemName: "person.2.fill")
            .font(AwradTheme.bodyFont(34, weight: .semibold))
            .foregroundStyle(AwradTheme.sage)
            .frame(width: 76, height: 76)
            .background(AwradTheme.mint.opacity(0.24), in: Circle())
    }
}

private enum AuthInputField: Hashable {
    case email
    case password
}

struct LoginView: View {
    @Environment(AwradStore.self) private var store
    @Environment(AppServices.self) private var services
    @Environment(AppRouter.self) private var router
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: AuthInputField?
    private let onSuccess: (() -> Void)?
    private let onVerificationRequired: (() -> Void)?

    init(
        prefilledEmail: String? = nil,
        onSuccess: (() -> Void)? = nil,
        onVerificationRequired: (() -> Void)? = nil
    ) {
        _email = State(initialValue: prefilledEmail ?? "")
        self.onSuccess = onSuccess
        self.onVerificationRequired = onVerificationRequired
    }

    var body: some View {
        AuthFormShell(title: "Welcome Back", subtitle: "Log in to your account") {
            authFields(includePassword: true)

            Button {
                submit()
            } label: {
                AuthButtonLabel(title: "Log In", isLoading: isLoading)
            }
            .awradPrimaryButton()
            .disabled(email.isEmpty || password.isEmpty || isLoading)

            Button("Forgot Password") {
                focusedField = nil
                router.navigate(.forgotPassword, in: .community)
            }
            .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))

            Button("No account? Sign Up") {
                focusedField = nil
                router.replaceLast(with: .signup, in: .community)
            }
            .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
        }
        .navigationTitle("Log In")
    }

    @ViewBuilder
    private func authFields(includePassword: Bool) -> some View {
        TextField("Email", text: $email)
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .awradAuthField()
            .focused($focusedField, equals: .email)

        if includePassword {
            SecureField("Password", text: $password)
                .textContentType(.password)
                .awradAuthField()
                .focused($focusedField, equals: .password)
        }

        if let errorMessage {
            Text(errorMessage)
                .font(AwradTheme.bodyFont(.footnote))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func submit() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await services.auth.login(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
                if let onSuccess {
                    onSuccess()
                } else {
                    router.popToRoot(in: .community)
                }
            } catch AuthServiceError.recoveryAccountMismatch {
                errorMessage = AwradLocalizer.localized(
                    "Sign in with the account that owns the previous progress on this device.",
                    language: store.preferences.appLanguage
                )
            } catch {
                if services.auth.pendingVerificationContext != nil {
                    if let onVerificationRequired {
                        onVerificationRequired()
                    } else {
                        router.replaceLast(with: .verifyEmail(token: nil), in: .community)
                    }
                } else {
                    errorMessage = error.localizedDescription
                }
            }
            isLoading = false
        }
    }
}

struct SignupView: View {
    @Environment(AppServices.self) private var services
    @Environment(AppRouter.self) private var router
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: AuthInputField?

    var body: some View {
        AuthFormShell(title: "Create your account", subtitle: "Start sharing progress with the community") {
            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .awradAuthField()
                .focused($focusedField, equals: .email)

            SecureField("Password", text: $password)
                .textContentType(usesPasswordAutoFill ? .newPassword : nil)
                .awradAuthField()
                .focused($focusedField, equals: .password)

            Text(LocalizedStringKey(AuthPasswordPolicy.guidance))
                .font(AwradTheme.bodyFont(.footnote))
                .foregroundStyle(AuthPasswordPolicy.isValid(password) || password.isEmpty ? Color.secondary : Color.red)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let errorMessage {
                Text(errorMessage)
                    .font(AwradTheme.bodyFont(.footnote))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                submit()
            } label: {
                AuthButtonLabel(title: "Sign Up", isLoading: isLoading)
            }
            .awradPrimaryButton()
            .disabled(email.isEmpty || !AuthPasswordPolicy.isValid(password) || isLoading)

            Button("Already have an account? Log In") {
                focusedField = nil
                router.replaceLast(with: .login, in: .community)
            }
            .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
        }
        .navigationTitle("Sign Up")
    }

    private var usesPasswordAutoFill: Bool {
#if DEBUG
        !ProcessInfo.processInfo.arguments.contains("--awrad-ui-testing")
#else
        true
#endif
    }

    private func submit() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await services.auth.register(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
                router.replaceLast(with: .verifyEmail(token: nil), in: .community)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

struct VerifyEmailView: View {
    @Environment(AppServices.self) private var services
    @Environment(AppRouter.self) private var router
    let token: String?
    private let onVerified: (() -> Void)?
    private let onSignIn: ((String?) -> Void)?
    @State private var isVerifying = false
    @State private var isResending = false
    @State private var cooldownSeconds = 0
    @State private var message: String?
    @State private var messageIsSuccess = false

    @State private var attemptedToken = false

    init(
        token: String?,
        onVerified: (() -> Void)? = nil,
        onSignIn: ((String?) -> Void)? = nil
    ) {
        self.token = token
        self.onVerified = onVerified
        self.onSignIn = onSignIn
    }

    var body: some View {
        AuthFormShell(
            title: "Check your email",
            subtitle: "Open the verification link on this device to finish signing in."
        ) {

            if let email = services.auth.pendingVerificationEmail ?? services.auth.userEmail {
                Text(email)
                    .font(AwradTheme.bodyFont(.footnote, weight: .semibold))
                    .foregroundStyle(AwradTheme.sage)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let message {
                Text(message)
                    .font(AwradTheme.bodyFont(.footnote))
                    .foregroundStyle(messageIsSuccess ? AwradTheme.sage : Color.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if isVerifying {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Verifying and signing you in…")
                }
                .frame(maxWidth: .infinity, minHeight: 44)
            }

            Button(action: resend) {
                if isResending {
                    ProgressView()
                } else if cooldownSeconds > 0 {
                    Text("Resend in \(cooldownSeconds)s")
                } else {
                    Text("Resend verification email")
                }
            }
            .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 44)
            .disabled(isResending || cooldownSeconds > 0)

            Button("Sign in instead") {
                let email = services.auth.pendingVerificationEmail
                if let onSignIn {
                    onSignIn(email)
                } else {
                    router.replaceLast(with: .login, in: .community)
                }
            }
            .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
        }
        .navigationTitle("Verify Email")
        .task(id: token) {
            if let token, !attemptedToken {
                attemptedToken = true
                verify(token: token)
            }
            while !Task.isCancelled {
                refreshCooldown()
                try? await Task<Never, Never>.sleep(for: .seconds(1))
            }
        }
    }

    private func verify(token: String) {
        guard !isVerifying else { return }
        isVerifying = true
        message = nil
        messageIsSuccess = false
        Task {
            do {
                try await services.auth.verifyEmail(token: token.trimmingCharacters(in: .whitespacesAndNewlines))
                if let onVerified {
                    onVerified()
                } else {
                    router.popToRoot(in: .community)
                }
            } catch {
                message = error.localizedDescription
            }
            isVerifying = false
        }
    }

    private func resend() {
        guard !isResending, cooldownSeconds == 0 else { return }
        isResending = true
        message = nil
        messageIsSuccess = false
        Task {
            do {
                try await services.auth.resendVerification()
                message = "Verification email sent."
                messageIsSuccess = true
                refreshCooldown()
            } catch {
                message = error.localizedDescription
            }
            isResending = false
        }
    }

    private func refreshCooldown(now: Date = Date()) {
        guard let availableAt = services.auth.verificationResendAvailableAt else {
            cooldownSeconds = 0
            return
        }
        cooldownSeconds = max(Int(ceil(availableAt.timeIntervalSince(now))), 0)
    }
}

struct ResetPasswordView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    let token: String
    @State private var password = ""
    @State private var confirmation = ""
    @State private var isLoading = false
    @State private var message: String?

    var body: some View {
        AuthFormShell(title: "Choose a new password", subtitle: "Use a strong password you do not use elsewhere.") {
            SecureField("New password", text: $password)
                .textContentType(.newPassword)
                .awradAuthField()
            SecureField("Confirm new password", text: $confirmation)
                .textContentType(.newPassword)
                .awradAuthField()

            Text(LocalizedStringKey(AuthPasswordPolicy.guidance))
                .font(AwradTheme.bodyFont(.footnote))
                .foregroundStyle(AuthPasswordPolicy.isValid(password) || password.isEmpty ? Color.secondary : Color.red)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let message {
                Text(message)
                    .font(AwradTheme.bodyFont(.footnote))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(action: submit) {
                AuthButtonLabel(title: "Reset Password", isLoading: isLoading)
            }
            .awradPrimaryButton()
            .disabled(!AuthPasswordPolicy.isValid(password) || password != confirmation || isLoading)
        }
        .navigationTitle("Reset Password")
    }

    private func submit() {
        guard password == confirmation, AuthPasswordPolicy.isValid(password) else { return }
        isLoading = true
        message = nil
        Task {
            do {
                try await services.auth.resetPassword(token: token, password: password)
                dismiss()
            } catch {
                message = error.localizedDescription
            }
            isLoading = false
        }
    }
}

struct SessionManagementView: View {
    @Environment(AppServices.self) private var services
    @Environment(AppRouter.self) private var router
    @State private var sessions: [AuthSessionInfo] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var revokingID: String?

    var body: some View {
        List {
            if isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
            } else if sessions.isEmpty {
                ContentUnavailableView(
                    "No active sessions",
                    systemImage: "iphone.slash",
                    description: Text("Sign in again to create a new device session.")
                )
            } else {
                Section("Devices") {
                    ForEach(sessions) { session in
                        HStack(spacing: 12) {
                            Image(systemName: session.platform.lowercased() == "ios" ? "iphone" : "apps.iphone")
                                .foregroundStyle(AwradTheme.sage)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(session.device_name)
                                    .font(AwradTheme.bodyFont(.body, weight: .semibold))
                                Text(session.id == services.auth.sessionID ? "This device" : session.platform.uppercased())
                                    .font(AwradTheme.bodyFont(.caption))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if revokingID == session.id {
                                ProgressView()
                            } else {
                                Button("Revoke", role: .destructive) { revoke(session) }
                                    .buttonStyle(.borderless)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    Button("Revoke All Sessions", role: .destructive, action: revokeAll)
                        .disabled(revokingID != nil)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(.red)
                    Button("Retry") { load() }
                }
            }
        }
        .navigationTitle("Active Sessions")
        .task { await loadSessions() }
    }

    private func load() {
        Task { await loadSessions() }
    }

    private func loadSessions() async {
        isLoading = true
        errorMessage = nil
        do {
            sessions = try await services.auth.sessions()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func revoke(_ session: AuthSessionInfo) {
        guard revokingID == nil else { return }
        revokingID = session.id
        Task {
            do {
                try await services.auth.revokeSession(id: session.id)
                sessions.removeAll { $0.id == session.id }
                if !services.auth.isLoggedIn { router.popToRoot(in: .community) }
            } catch {
                errorMessage = error.localizedDescription
            }
            revokingID = nil
        }
    }

    private func revokeAll() {
        guard revokingID == nil else { return }
        revokingID = "all"
        Task {
            do {
                try await services.auth.revokeAllSessions()
                sessions = []
                router.popToRoot(in: .community)
            } catch {
                errorMessage = error.localizedDescription
            }
            revokingID = nil
        }
    }
}

struct ForgotPasswordView: View {
    @Environment(AppServices.self) private var services
    @Environment(AppRouter.self) private var router
    @State private var email = ""
    @State private var isLoading = false
    @State private var message: String?
    @State private var sent = false

    var body: some View {
        AuthFormShell(
            title: sent ? "Check your email" : "Reset Password",
            subtitle: sent ? "We sent a password reset link to your email." : "Send a reset link to your email"
        ) {
            if sent {
                Image(systemName: "envelope.badge.fill")
                    .font(AwradTheme.bodyFont(42, weight: .semibold))
                    .foregroundStyle(AwradTheme.sage)
                    .frame(maxWidth: .infinity)
                Button("Back to Log In") {
                    router.replaceLast(with: .login, in: .community)
                }
                .awradPrimaryButton()
            } else {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .awradAuthField()

                if let message {
                    Text(message)
                        .font(AwradTheme.bodyFont(.footnote))
                        .foregroundStyle(Color.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    submit()
                } label: {
                    AuthButtonLabel(title: "Send Reset Link", isLoading: isLoading)
                }
                .awradPrimaryButton()
                .disabled(email.isEmpty || isLoading)
            }
        }
        .navigationTitle("Forgot Password")
    }

    private func submit() {
        isLoading = true
        message = nil
        Task {
            do {
                try await services.auth.forgotPassword(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
                sent = true
            } catch {
                message = error.localizedDescription
            }
            isLoading = false
        }
    }
}

private struct AuthFormShell<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(LocalizedStringKey(title))
                        .font(AwradTheme.displayFont(28))
                        .foregroundStyle(AwradTheme.ink)
                    Text(LocalizedStringKey(subtitle))
                        .font(AwradTheme.bodyFont(.body))
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 14) {
                    content
                }
            }
            .padding(20)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AwradTheme.background)
    }
}

private struct AuthButtonLabel: View {
    let title: String
    let isLoading: Bool

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else {
                Text(LocalizedStringKey(title))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private extension View {
    func awradAuthField() -> some View {
        textFieldStyle(.plain)
            .padding(.horizontal, 14)
            .frame(height: 52)
            .awradGlassSurface(cornerRadius: 14, interactive: true)
    }
}
