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

                if services.auth.isLoggedIn {
                    loggedInCard
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
                    Button("Log Out") {
                        Task {
                            await services.auth.logout()
                        }
                    }
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

    private var communityMark: some View {
        Image(systemName: "person.2.fill")
            .font(AwradTheme.bodyFont(34, weight: .semibold))
            .foregroundStyle(AwradTheme.sage)
            .frame(width: 76, height: 76)
            .background(AwradTheme.mint.opacity(0.24), in: Circle())
    }
}

struct LoginView: View {
    @Environment(AppServices.self) private var services
    @Environment(AppRouter.self) private var router
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

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
                router.navigate(.forgotPassword, in: .community)
            }
            .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))

            Button("No account? Sign Up") {
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

        if includePassword {
            SecureField("Password", text: $password)
                .textContentType(.password)
                .awradAuthField()
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

    var body: some View {
        AuthFormShell(title: "Create your account", subtitle: "Start sharing progress with the community") {
            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .awradAuthField()

            SecureField("Password", text: $password)
                .textContentType(.newPassword)
                .awradAuthField()

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
            .disabled(email.isEmpty || password.isEmpty || isLoading)

            Button("Already have an account? Log In") {
                router.replaceLast(with: .login, in: .community)
            }
            .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
        }
        .navigationTitle("Sign Up")
    }

    private func submit() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await services.auth.register(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
                router.popToRoot(in: .community)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

struct ForgotPasswordView: View {
    @Environment(AppServices.self) private var services
    @State private var email = ""
    @State private var isLoading = false
    @State private var message: String?

    var body: some View {
        AuthFormShell(title: "Reset Password", subtitle: "Send a reset link to your email") {
            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .awradAuthField()

            if let message {
                Text(message)
                    .font(AwradTheme.bodyFont(.footnote))
                    .foregroundStyle(.secondary)
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
        .navigationTitle("Forgot Password")
    }

    private func submit() {
        isLoading = true
        message = nil
        Task {
            do {
                try await services.auth.forgotPassword(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
                message = "Reset link sent."
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
            .background(AwradTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AwradTheme.sage.opacity(0.16), lineWidth: 1)
            }
    }
}
