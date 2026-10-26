import AwradDomain
import AwradTesting
import Testing

// Every case of contracts/account-model/v1/fixtures/, run through the real input rules. The
// fixtures are the spec: never edit them to match this code.

@Suite("account-model v1 fixtures")
struct AccountModelFixtureTests {
    @Test(arguments: try AccountModelFixtures.emailInput())
    func emailInput(_ fixture: FixtureCase<TypedInput, EmailInputExpect>) {
        let email = AccountInput.email(fixture.given.input)
        #expect(EmailInputExpect(email) == fixture.expect, "\(fixture.id): \(fixture.summary)")
    }

    @Test(arguments: try AccountModelFixtures.passwordPolicy())
    func passwordPolicy(_ fixture: FixtureCase<PasswordGiven, PasswordPolicyExpect>) {
        let problem = PasswordPolicy.problem(with: fixture.given.password)
        #expect(PasswordPolicyExpect(problem) == fixture.expect, "\(fixture.id): \(fixture.summary)")
    }

    @Test(arguments: try AccountModelFixtures.emailCodeInput())
    func emailCodeInput(_ fixture: FixtureCase<TypedInput, EmailCodeExpect>) {
        let code = AccountInput.emailCode(fixture.given.input)
        #expect(EmailCodeExpect(code) == fixture.expect, "\(fixture.id): \(fixture.summary)")
    }
}

/// Cases the fixtures don't spell out, pinned so a refactor can't drift from the README's rules.
struct AccountInputTests {
    @Test func passwordLengthIsCodePointsNotGraphemes() {
        // 12 flags are 12 grapheme clusters but 24 code points.
        let flags = String(repeating: "🇸🇦", count: 12)
        #expect(flags.count == 12)
        #expect(PasswordPolicy.problem(with: flags) == nil)
        #expect(PasswordPolicy.problem(with: String(repeating: "🇸🇦", count: 65)) == .tooLong)
    }

    @Test func emailCodeKeepsOnlySixDigits() {
        #expect(AccountInput.emailCode("\u{200B}482913\u{FEFF}") == "482913")
        #expect(AccountInput.emailCode("482–913") == nil)  // an en dash isn't a hyphen
    }
}
