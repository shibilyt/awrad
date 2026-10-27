package app.awrad.next.gallery

import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import app.awrad.core.designsystem.component.AwradCard
import app.awrad.core.designsystem.component.AwradCheckbox
import app.awrad.core.designsystem.component.AwradIconButton
import app.awrad.core.designsystem.component.AwradSegmentedPills
import app.awrad.core.designsystem.component.AwradSwitch
import app.awrad.core.designsystem.component.AwradTextField
import app.awrad.core.designsystem.icon.AwradIcons
import app.awrad.core.designsystem.theme.AwradTheme
import app.awrad.next.R

/** Text fields (empty, filled, hint, error, disabled, on a card), checkboxes, switches and segmented pills. */
@Composable
internal fun InputsSection(modifier: Modifier = Modifier) {
    val disabled = stringResource(R.string.gallery_state_disabled)
    GallerySection(title = stringResource(R.string.gallery_section_inputs), modifier = modifier) {
        TextFields(disabled = disabled)
        Toggles(disabled = disabled)
        Segments()
    }
}

@Composable
private fun TextFields(disabled: String) {
    var email by rememberSaveable { mutableStateOf("") }
    var password by rememberSaveable { mutableStateOf("") }
    var visible by rememberSaveable { mutableStateOf(false) }
    AwradTextField(
        value = email,
        onValueChange = { email = it },
        label = stringResource(R.string.gallery_email),
        placeholder = stringResource(R.string.gallery_email_placeholder),
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
    )
    AwradTextField(
        value = password,
        onValueChange = { password = it },
        label = stringResource(R.string.gallery_password),
        supportingText = stringResource(R.string.gallery_password_hint),
        visualTransformation = if (visible) VisualTransformation.None else PasswordVisualTransformation(),
        trailingIcon = {
            AwradIconButton(
                icon = if (visible) AwradIcons.Hide else AwradIcons.Show,
                contentDescription = stringResource(
                    if (visible) R.string.gallery_hide_password else R.string.gallery_show_password,
                ),
                onClick = { visible = !visible },
                tint = AwradTheme.colors.onSurfaceVariant,
            )
        },
    )
    AwradTextField(
        value = "short",
        onValueChange = {},
        label = stringResource(R.string.gallery_password),
        error = stringResource(R.string.gallery_password_error),
        visualTransformation = PasswordVisualTransformation(),
    )
    AwradTextField(
        value = stringResource(R.string.gallery_email_placeholder),
        onValueChange = {},
        label = disabled,
        enabled = false,
    )
    AwradCard {
        StateLabel(text = stringResource(R.string.gallery_on_card))
        AwradTextField(
            value = "",
            onValueChange = {},
            label = stringResource(R.string.gallery_email),
            placeholder = stringResource(R.string.gallery_email_placeholder),
        )
        AwradTextField(
            value = "short",
            onValueChange = {},
            label = stringResource(R.string.gallery_password),
            error = stringResource(R.string.gallery_password_error),
        )
    }
}

@Composable
private fun Toggles(disabled: String) {
    var remind by rememberSaveable { mutableStateOf(true) }
    var daily by rememberSaveable { mutableStateOf(false) }
    var dailyOn by rememberSaveable { mutableStateOf(true) }
    val remindLabel = stringResource(R.string.gallery_remind_fajr)
    val dailyLabel = stringResource(R.string.gallery_daily_reminder)
    AwradCheckbox(checked = remind, onCheckedChange = { remind = it }, label = remindLabel)
    AwradCheckbox(checked = !remind, onCheckedChange = { remind = !it }, label = remindLabel)
    AwradCheckbox(checked = true, onCheckedChange = {}, label = disabled, enabled = false)
    AwradCheckbox(checked = false, onCheckedChange = {}, label = disabled, enabled = false)
    AwradSwitch(checked = daily, onCheckedChange = { daily = it }, label = dailyLabel)
    AwradSwitch(checked = dailyOn, onCheckedChange = { dailyOn = it }, label = dailyLabel)
    AwradSwitch(checked = true, onCheckedChange = {}, label = disabled, enabled = false)
    AwradSwitch(checked = false, onCheckedChange = {}, label = disabled, enabled = false)
}

@Composable
private fun Segments() {
    var two by rememberSaveable { mutableIntStateOf(0) }
    var three by rememberSaveable { mutableIntStateOf(1) }
    AwradSegmentedPills(
        options = listOf(stringResource(R.string.gallery_active), stringResource(R.string.gallery_history)),
        selectedIndex = two,
        onSelect = { two = it },
    )
    AwradSegmentedPills(
        options = listOf(
            stringResource(R.string.gallery_today),
            stringResource(R.string.gallery_week),
            stringResource(R.string.gallery_month),
        ),
        selectedIndex = three,
        onSelect = { three = it },
    )
    StateLabel(text = stringResource(R.string.gallery_state_disabled))
    AwradSegmentedPills(
        options = listOf(stringResource(R.string.gallery_active), stringResource(R.string.gallery_history)),
        selectedIndex = 1,
        onSelect = {},
        enabled = false,
    )
}
