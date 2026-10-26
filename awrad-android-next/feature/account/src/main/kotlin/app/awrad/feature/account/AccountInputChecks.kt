package app.awrad.feature.account

import app.awrad.core.domain.account.InputProblem
import app.awrad.core.domain.account.PasswordError
import app.awrad.core.domain.account.PasswordPolicy

/** What the shared password policy finds wrong with a new password; empty when it may be sent. */
internal fun newPasswordProblems(password: String): Set<InputProblem> =
    PasswordPolicy.errors(password).mapTo(mutableSetOf()) { error ->
        when (error) {
            PasswordError.PASSWORD_TOO_SHORT -> InputProblem.PASSWORD_TOO_SHORT
            PasswordError.PASSWORD_TOO_LONG -> InputProblem.PASSWORD_TOO_LONG
        }
    }

/** The problems shown under a new-password field. */
internal val NewPasswordProblems: Set<InputProblem> = setOf(
    InputProblem.PASSWORD_TOO_SHORT,
    InputProblem.PASSWORD_TOO_LONG,
    InputProblem.PASSWORD_TOO_COMMON,
)

/** The problems shown under an email field. */
internal val EmailProblems: Set<InputProblem> = setOf(InputProblem.EMAIL_INVALID, InputProblem.EMAIL_UNCHANGED)

/** The first of these [problems] that belongs under a field showing [shown]. */
internal fun Set<InputProblem>.firstOf(shown: Set<InputProblem>): InputProblem? = firstOrNull { it in shown }
