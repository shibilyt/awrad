import SwiftUI

struct CommunityView: View {
    @Environment(AppServices.self) private var services
    @Environment(AppRouter.self) private var router

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Keep your practice connected and steady.")
                    .font(AwradTheme.bodyFont(.body))
                    .foregroundStyle(.secondary)

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
    @Environment(AppServices.self) private var services
    @Environment(AppRouter.self) private var router
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: AuthInputField?

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
                router.popToRoot(in: .community)
            } catch {
                errorMessage = error.localizedDescription
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
    @State private var token: String
    @State private var isVerifying = false
    @State private var isResending = false
    @State private var cooldownSeconds = 0
    @State private var message: String?
    @State private var messageIsSuccess = false

    init(token: String?) {
        _token = State(initialValue: token ?? "")
    }

    var body: some View {
        AuthFormShell(title: "Verify your email", subtitle: "Paste the token from your verification link.") {
            TextField("Verification token", text: $token)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .awradAuthField()

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

            Button(action: verify) {
                AuthButtonLabel(title: "Verify and Sign In", isLoading: isVerifying)
            }
            .awradPrimaryButton()
            .disabled(token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isVerifying)

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
        }
        .navigationTitle("Verify Email")
        .task {
            while !Task.isCancelled {
                refreshCooldown()
                try? await Task<Never, Never>.sleep(for: .seconds(1))
            }
        }
    }

    private func verify() {
        guard !isVerifying else { return }
        isVerifying = true
        message = nil
        messageIsSuccess = false
        Task {
            do {
                try await services.auth.verifyEmail(token: token.trimmingCharacters(in: .whitespacesAndNewlines))
                router.popToRoot(in: .community)
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
