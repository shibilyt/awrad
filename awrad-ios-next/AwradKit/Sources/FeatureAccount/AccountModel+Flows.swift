import AwradDomain
import Foundation

// The account flows. Input is checked with the shared account-model rules before anything is
// sent; the server stays the authority and its codes come back as `AccountError`s.

extension AccountModel {
    func load() async {
        if let account = await service.signedInAccount() {
            state.phase = .signedIn(email: account.email)
            await confirmSession()
        } else {
            state.phase = .signedOut
        }
    }

    /// Checks the stored session with the server. Offline, the stored account keeps showing.
    private func confirmSession() async {
        do {
            let account = try await service.currentAccount()
            state.phase = .signedIn(email: account.email)
        } catch .signedOut {
            showSignedOut(.signedOut)
        } catch {
            // Offline or a server fault: still signed in on this device.
        }
    }

    func signIn() async throws(AccountError) {
        guard let email = checkedEmail() else { return }
        guard !state.password.isEmpty else { return fail(.passwordRequired) }
        do {
            try await signIn(email: email, password: state.password)
        } catch .emailVerificationRequired {
            // The server emailed a fresh code; verify, then sign in with this password.
            startCodeStep(.verifyEmail, email: email, notice: .verificationNeeded)
        }
    }

    func register() async throws(AccountError) {
        guard let email = checkedEmail(), checkPassword(state.password) else { return }
        try await service.register(email: email, password: state.password)
        startCodeStep(.verifyEmail, email: email, notice: .codeSent)
    }

    func verify() async throws(AccountError) {
        guard let code = checkedCode() else { return }
        try await service.verifyEmail(email: state.email, code: code)
        await signInAfterCode(password: state.password)
    }

    func resend() async throws(AccountError) {
        if let available = state.resendAvailableAt, available > now() { return }
        do {
            if state.path.last == .resetPassword {
                try await service.requestPasswordReset(email: state.email)
            } else {
                try await service.resendVerificationCode(email: state.email)
            }
            state.resendAvailableAt = now().addingTimeInterval(Self.resendCooldown)
            state.feedback = .codeSent
        } catch .rateLimited(let seconds) {
            state.resendAvailableAt = now().addingTimeInterval(TimeInterval(seconds ?? Int(Self.resendCooldown)))
            throw .rateLimited(retryAfterSeconds: seconds)
        }
    }

    func sendResetCode() async throws(AccountError) {
        guard let email = checkedEmail() else { return }
        try await service.requestPasswordReset(email: email)
        startCodeStep(.resetPassword, email: email, notice: .codeSent)
    }

    func reset() async throws(AccountError) {
        guard let code = checkedCode(), checkPassword(state.newPassword) else { return }
        try await service.resetPassword(email: state.email, code: code, newPassword: state.newPassword)
        await signInAfterCode(password: state.newPassword)
    }

    func signOut() async {
        await service.signOut()
        showSignedOut(nil)
    }

    // MARK: - Steps

    private func signIn(email: String, password: String) async throws(AccountError) {
        let account = try await service.signIn(email: email, password: password)
        state = State()
        state.phase = .signedIn(email: account.email)
    }

    /// After a verified email or a new password: signs in with the password the person typed. If
    /// that fails, they're back at sign in with the email and password filled in.
    private func signInAfterCode(password: String) async {
        do {
            try await signIn(email: state.email, password: password)
        } catch {
            state.path = []
            state.password = password
            state.code = ""
            state.newPassword = ""
            state.feedback = Self.feedback(for: error)
        }
    }

    private func startCodeStep(_ step: Step, email: String, notice: Feedback) {
        state.email = email
        state.code = ""
        state.path.append(step)
        state.resendAvailableAt = now().addingTimeInterval(Self.resendCooldown)
        state.feedback = notice
    }

    private func showSignedOut(_ feedback: Feedback?) {
        let email = state.email
        state = State()
        state.phase = .signedOut
        state.email = email
        state.feedback = feedback
    }

    // MARK: - Input

    /// The normalised email, or `nil` with feedback. Also writes the normalised form back.
    private func checkedEmail() -> String? {
        guard let email = AccountInput.email(state.email) else {
            fail(.emailInvalid)
            return nil
        }
        state.email = email
        return email
    }

    private func checkedCode() -> String? {
        guard let code = AccountInput.emailCode(state.code) else {
            fail(.codeIncomplete)
            return nil
        }
        return code
    }

    private func checkPassword(_ password: String) -> Bool {
        switch PasswordPolicy.problem(with: password) {
        case nil: return true
        case .tooShort: fail(.passwordTooShort)
        case .tooLong: fail(.passwordTooLong)
        }
        return false
    }

    private func fail(_ feedback: Feedback) {
        state.feedback = feedback
    }
}
