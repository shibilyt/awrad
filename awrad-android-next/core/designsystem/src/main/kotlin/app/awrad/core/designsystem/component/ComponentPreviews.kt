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
import app.awrad.core.designsystem.theme.AwradTheme

/*
 * A quick look at the main components in the light and the dark theme, on the `background` and inside an
 * `AwradCard` (fields fill the other way there). The debug build's component gallery shows every component in
 * every state. Preview text isn't user-facing.
 */

@Preview(name = "light")
@Preview(name = "dark", uiMode = Configuration.UI_MODE_NIGHT_YES)
@Composable
private fun ComponentsPreview() {
    AwradTheme {
        Surface(color = MaterialTheme.colorScheme.background) {
            Column(
                modifier = Modifier.padding(AwradTheme.spacing.pageMargin),
                verticalArrangement = Arrangement.spacedBy(AwradTheme.spacing.rowGap),
            ) {
                AwradTopBar(title = "Title", onBack = {})
                AwradStepIndicator(step = 2, count = 7)
                AwradTextField(value = "amina@example.com", onValueChange = {}, label = "Email")
                AwradTextField(value = "short", onValueChange = {}, label = "Password", error = "At least 12")
                AwradButton(text = "Continue", onClick = {})
                AwradButton(text = "Notifications", onClick = {}, variant = AwradButtonVariant.Secondary)
                AwradButton(text = "Delete account", onClick = {}, variant = AwradButtonVariant.Error)
                AwradButton(text = "Saving", onClick = {}, isLoading = true)
                AwradTextButton(text = "View all", onClick = {})
                AwradOptionRow(label = "English", selected = true, onClick = {}, avatar = "Aa")
                AwradOptionRow(label = "العربية", selected = false, onClick = {}, avatar = "ع")
                AwradSegmentedPills(options = listOf("Active", "History"), selectedIndex = 0, onSelect = {})
                AwradCard {
                    Text(text = "On a card", style = AwradTheme.type.cardTitle)
                    AwradTextField(value = "", onValueChange = {}, label = "Code", placeholder = "123456")
                }
            }
        }
    }
}
