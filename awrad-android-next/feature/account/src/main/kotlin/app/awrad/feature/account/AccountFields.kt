package app.awrad.feature.account

import androidx.annotation.StringRes
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import app.awrad.core.designsystem.component.AwradTextField
import app.awrad.core.domain.account.InputProblem

@Composable
internal fun EmailField(
    value: String,
    problem: InputProblem?,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    @StringRes label: Int = R.string.account_field_email,
    enabled: Boolean = true,
) {
    AwradTextField(
        value = value,
        onValueChange = onValueChange,
        label = stringResource(label),
        modifier = modifier,
        enabled = enabled,
        isError = problem != null,
        supportingText = problem?.text(),
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email, imeAction = ImeAction.Next),
    )
}

/**
 * A password field. With [showRule], the hint states the 12-character rule (the shared password policy);
 * sign-in doesn't check the rule, so it shows no hint.
 */
@Composable
internal fun PasswordField(
    value: String,
    problem: InputProblem?,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    @StringRes label: Int = R.string.account_field_password,
    showRule: Boolean = false,
    enabled: Boolean = true,
) {
    var visible by rememberSaveable { mutableStateOf(false) }
    val hint = when {
        problem != null -> problem.text()
        showRule -> passwordRuleText()
        else -> null
    }
    AwradTextField(
        value = value,
        onValueChange = onValueChange,
        label = stringResource(label),
        modifier = modifier,
        enabled = enabled,
        isError = problem != null,
        supportingText = hint,
        visualTransformation = if (visible) VisualTransformation.None else PasswordVisualTransformation(),
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password, imeAction = ImeAction.Done),
        trailingIcon = {
            IconButton(onClick = { visible = !visible }) {
                Icon(
                    imageVector = if (visible) Icons.Filled.VisibilityOff else Icons.Filled.Visibility,
                    contentDescription = stringResource(
                        if (visible) R.string.account_action_hide_password else R.string.account_action_show_password,
                    ),
                )
            }
        },
    )
}

@Composable
internal fun CodeField(
    value: String,
    problem: InputProblem?,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
) {
    AwradTextField(
        value = value,
        onValueChange = onValueChange,
        label = stringResource(R.string.account_field_code),
        modifier = modifier,
        enabled = enabled,
        isError = problem != null,
        supportingText = problem?.text(),
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword, imeAction = ImeAction.Next),
    )
}
