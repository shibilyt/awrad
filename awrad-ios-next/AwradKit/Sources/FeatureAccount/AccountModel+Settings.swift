import AwradDomain
import Foundation

// The signed-in flows (slice 2b): devices, change password, change email and delete account. A
// password re-entered here is checked only for being there; the server checks it.

extension AccountModel {
    /// Asking to confirm a destructive action, and closing the question, change local state only.
    func applyConfirmation(_ action: Action) -> Bool {
        switch action {
        case .revokeTapped(let session): ask(.revokeSession(session))
        case .revokeOthersTapped: ask(.revokeOtherSessions)
        case .deleteTapped:
            if state.currentPassword.isEmpty {
                fail(.currentPasswordRequired)
            } else {
                ask(.deleteAccount)
            }
        case .confirmationDismissed: state.confirmation = nil
        case .profileQuestionDismissed: dismissProfileQuestion()
        default: return false
        }
        return true
    }

    /// The work behind a signed-in button that talks to the server.
    func settingsSubmission(for action: Action) -> (() async throws(AccountError) -> Void)? {
        switch action {
        case .revokeConfirmed(let id): { () throws(AccountError) in try await self.revokeSession(id) }
        case .revokeOthersConfirmed: revokeOtherSessions
        case .savePasswordTapped: changePassword
        case .sendEmailCodeTapped: requestEmailChange
        case .confirmEmailTapped: confirmEmailChange
        case .deleteConfirmed: deleteAccount
        default: nil
        }
    }

    // MARK: - Devices

    /// Loads the devices list. While a list is showing, a failed reload keeps it.
    func loadSessions() async {
        do {
            let sessions = try await service.sessions()
            state.sessions = .loaded(sessions.filter(\.isCurrent) + sessions.filter { !$0.isCurrent })
        } catch .signedOut {
            await sessionEnded()
        } catch {
            if case .loaded = state.sessions {} else { state.sessions = .unavailable }
            state.feedback = Self.feedback(for: error)
        }
    }

    func revokeSession(_ id: AwradID) async throws(AccountError) {
        state.confirmation = nil
        do {
            try await service.revokeSession(id)
            state.feedback = .sessionSignedOut
        } catch .notFound {
            // Already signed out elsewhere: it's gone either way.
            removeSessions { $0.id == id }
            throw .notFound
        }
        removeSessions { $0.id == id }
    }

    func revokeOtherSessions() async throws(AccountError) {
        state.confirmation = nil
        try await service.revokeOtherSessions()
        removeSessions { !$0.isCurrent }
        state.feedback = .otherSessionsSignedOut
    }

    private func removeSessions(where shouldRemove: (AccountSession) -> Bool) {
        guard case .loaded(var sessions) = state.sessions else { return }
        sessions.removeAll(where: shouldRemove)
        state.sessions = .loaded(sessions)
    }

    // MARK: - Password and email

    func changePassword() async throws(AccountError) {
        guard checkCurrentPassword(), checkPassword(state.newPassword) else { return }
        try await service.changePassword(currentPassword: state.currentPassword, newPassword: state.newPassword)
        finishSettings(.passwordChanged)
    }

    func requestEmailChange() async throws(AccountError) {
        guard checkCurrentPassword(), let newEmail = checkedNewEmail() else { return }
        try await service.requestEmailChange(currentPassword: state.currentPassword, newEmail: newEmail)
        state.pendingEmail = newEmail
        state.code = ""
        state.path.append(.confirmEmailChange)
        state.resendAvailableAt = now().addingTimeInterval(Self.resendCooldown)
        state.feedback = .codeSent
    }

    func confirmEmailChange() async throws(AccountError) {
        guard let code = checkedCode() else { return }
        let account = try await service.confirmEmailChange(code: code)
        state.phase = .signedIn(email: account.email)
        finishSettings(.emailChanged)
        await profileSignedIn(account)
    }

    // MARK: - Delete

    func deleteAccount() async throws(AccountError) {
        state.confirmation = nil
        guard checkCurrentPassword() else { return }
        try await service.deleteAccount(currentPassword: state.currentPassword)
        showSignedOut(.accountDeleted, keepEmail: false)
        await profiles.handle(.signOut, choice: nil)
    }

    // MARK: - Steps

    private func ask(_ confirmation: Confirmation) {
        state.feedback = nil
        state.confirmation = confirmation
    }

    /// Back to the overview after a change, forgetting what was typed, with a notice.
    private func finishSettings(_ notice: Feedback) {
        state.path = []
        state.currentPassword = ""
        state.newPassword = ""
        state.newEmail = ""
        state.code = ""
        state.pendingEmail = nil
        state.resendAvailableAt = nil
        state.feedback = notice
    }

    private func checkCurrentPassword() -> Bool {
        guard state.currentPassword.isEmpty else { return true }
        fail(.currentPasswordRequired)
        return false
    }

    /// The normalised new email, or `nil` with feedback. It must differ from the account's
    /// (emails compare case-insensitively).
    private func checkedNewEmail() -> String? {
        guard let email = AccountInput.email(state.newEmail) else {
            fail(.emailInvalid)
            return nil
        }
        state.newEmail = email
        if let current = signedInEmail, current.lowercased() == email.lowercased() {
            fail(.emailUnchanged)
            return nil
        }
        return email
    }
}
