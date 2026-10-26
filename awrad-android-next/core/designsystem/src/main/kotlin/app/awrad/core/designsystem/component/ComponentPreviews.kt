package app.awrad.core.designsystem.component

import android.content.res.Configuration
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import app.awrad.core.designsystem.theme.AwradTheme

/*
 * Every shared component in the light and the dark theme, on the `background` and inside an `AwradCard` (fields
 * and secondary buttons fill the other way there). Preview text isn't user-facing.
 */

@Preview(name = "light")
@Preview(name = "dark", uiMode = Configuration.UI_MODE_NIGHT_YES)
@Composable
private fun ComponentsPreview() {
    AwradTheme {
        Surface(color = MaterialTheme.colorScheme.background) {
            Column(modifier = Modifier.padding(24.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(text = "Title", style = MaterialTheme.typography.headlineMedium)
                Text(
                    text = "Secondary text",
                    style = MaterialTheme.typography.bodyLarge,
                    color = AwradTheme.colors.onSurfaceVariant,
                )
                Text(text = "7-day streak", color = AwradTheme.colors.accent)
                AwradLinearProgress()
                AwradTextField(value = "amina@example.com", onValueChange = {}, label = "Email")
                AwradTextField(
                    value = "short",
                    onValueChange = {},
                    label = "Password",
                    isError = true,
                    supportingText = "At least 12 characters",
                )
                AwradPrimaryButton(text = "Continue", onClick = {})
                AwradSecondaryButton(text = "Sign out", onClick = {})
                AwradSecondaryButton(text = "Retry", onClick = {}, enabled = false)
                AwradDestructiveButton(text = "Delete account", onClick = {})
                AwradTextButton(text = "Forgot password?", onClick = {})
                AwradTextButton(text = "Remove", onClick = {}, isDestructive = true)
                AwradCircularProgress()
                AwradCard {
                    Text(text = "On a card", style = MaterialTheme.typography.titleMedium)
                    AwradTextField(value = "", onValueChange = {}, label = "Code")
                    AwradTextField(
                        value = "12",
                        onValueChange = {},
                        label = "Code",
                        isError = true,
                        supportingText = "Enter the 6-digit code",
                    )
                    AwradSecondaryButton(text = "Send a new code", onClick = {})
                }
            }
        }
    }
}
