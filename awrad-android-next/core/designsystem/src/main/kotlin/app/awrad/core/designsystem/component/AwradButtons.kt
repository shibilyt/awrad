package app.awrad.core.designsystem.component

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import app.awrad.core.designsystem.theme.AwradTheme

/*
 * Buttons by role. Material's outlined and text buttons draw their label in `primary`, which is too dark to read
 * on a dark background, and their border in the decorative `outline`; these use `onSurface`, `accent`,
 * `outlineStrong` and `error` instead.
 */

private val ButtonHeight = 56.dp

/** The one full-width call to action per screen: a `primary` fill. */
@Composable
public fun AwradPrimaryButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    trailingIcon: ImageVector? = null,
) {
    Button(
        onClick = onClick,
        enabled = enabled,
        modifier = modifier
            .fillMaxWidth()
            .height(ButtonHeight),
        shape = MaterialTheme.shapes.medium,
    ) {
        Text(text = text, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
        if (trailingIcon != null) {
            Spacer(modifier = Modifier.width(8.dp))
            Icon(imageVector = trailingIcon, contentDescription = null, modifier = Modifier.size(18.dp))
        }
    }
}

/** A full-width secondary action, the same size as the primary one: an `outlineStrong` border. */
@Composable
public fun AwradSecondaryButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
) {
    val colors = AwradTheme.colors
    OutlinedButton(
        onClick = onClick,
        enabled = enabled,
        modifier = modifier
            .fillMaxWidth()
            .height(ButtonHeight),
        shape = MaterialTheme.shapes.medium,
        colors = ButtonDefaults.outlinedButtonColors(contentColor = colors.onSurface),
        border = BorderStroke(width = 1.dp, color = if (enabled) colors.outlineStrong else colors.outline),
    ) {
        Text(text = text, style = MaterialTheme.typography.titleMedium)
    }
}

/** A full-width action that can't be taken back, such as deleting the account: an `error` fill. */
@Composable
public fun AwradDestructiveButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
) {
    val colors = AwradTheme.colors
    Button(
        onClick = onClick,
        enabled = enabled,
        modifier = modifier
            .fillMaxWidth()
            .height(ButtonHeight),
        shape = MaterialTheme.shapes.medium,
        colors = ButtonDefaults.buttonColors(containerColor = colors.error, contentColor = colors.onError),
    ) {
        Text(text = text, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
    }
}

/**
 * A text-only action, such as a link to another page or a dialog's buttons: `accent` text, or `error` when
 * [isDestructive]. [isEmphasized] sets it in semibold, for a dialog's confirm button.
 */
@Composable
public fun AwradTextButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    isDestructive: Boolean = false,
    isEmphasized: Boolean = false,
) {
    val colors = AwradTheme.colors
    TextButton(
        onClick = onClick,
        enabled = enabled,
        modifier = modifier,
        colors = ButtonDefaults.textButtonColors(contentColor = if (isDestructive) colors.error else colors.accent),
    ) {
        Text(text = text, fontWeight = if (isEmphasized) FontWeight.SemiBold else null)
    }
}
