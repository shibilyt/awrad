import AwradDomain
import Foundation

// contracts/account-model/v1: the account input rules iOS implements, and each rule's `given` and
// `expect` shapes. Both stay in the wire shape; the tests build `expect` from the domain result.

/// Every account-model rule iOS implements. The runner fails if any has no fixture file or no cases.
public enum AccountModelRule: String, CaseIterable, Sendable {
    case emailInput = "email_input"
    case passwordPolicy = "password_policy"
    case emailCodeInput = "email_code_input"

    /// `contracts/account-model/v1/fixtures/<rule>.json` in this repository.
    public func fixtureFile(from filePath: String = #filePath) throws -> URL {
        try FixtureLoader.fixturesDirectory(model: "account-model", from: filePath)
            .appending(path: "\(rawValue).json")
    }

    public func cases<Given: Decodable & Sendable, Expect: Decodable & Sendable>(
        _ shape: (Given.Type, Expect.Type)
    ) throws -> [FixtureCase<Given, Expect>] {
        try FixtureLoader.load(fixtureFile(), rule: rawValue, as: shape)
    }
}

/// Typed case lists, one per rule, for `@Test(arguments:)`.
public enum AccountModelFixtures {
    public static func emailInput() throws -> [FixtureCase<TypedInput, EmailInputExpect>] {
        try AccountModelRule.emailInput.cases((TypedInput.self, EmailInputExpect.self))
    }

    public static func passwordPolicy() throws -> [FixtureCase<PasswordGiven, PasswordPolicyExpect>] {
        try AccountModelRule.passwordPolicy.cases((PasswordGiven.self, PasswordPolicyExpect.self))
    }

    public static func emailCodeInput() throws -> [FixtureCase<TypedInput, EmailCodeExpect>] {
        try AccountModelRule.emailCodeInput.cases((TypedInput.self, EmailCodeExpect.self))
    }
}

// MARK: - Given

/// What the user typed.
public struct TypedInput: Decodable, Sendable {
    public let input: String
}

public struct PasswordGiven: Decodable, Sendable {
    public let password: String
}

// MARK: - Expect

public struct EmailInputExpect: Decodable, Equatable, Sendable {
    public let valid: Bool
    public let email: String?

    public init(_ email: String?) {
        valid = email != nil
        self.email = email
    }
}

public struct PasswordPolicyExpect: Decodable, Equatable, Sendable {
    public let valid: Bool
    public let errors: [String]

    public init(_ problem: PasswordPolicy.Problem?) {
        valid = problem == nil
        errors = problem.map { [$0.rawValue] } ?? []
    }
}

public struct EmailCodeExpect: Decodable, Equatable, Sendable {
    public let code: String?

    public init(_ code: String?) {
        self.code = code
    }
}
