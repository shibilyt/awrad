package app.awrad.feature.account

import android.text.BidiFormatter
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import java.util.Locale

/*
 * Small pieces the account pages share.
 */

/** [email] isolated for bidi, so an address inside an Arabic sentence keeps its order. */
internal fun isolated(email: String): String = BidiFormatter.getInstance().unicodeWrap(email.trim())

@Composable
internal fun CodeSentTo(email: String, modifier: Modifier = Modifier) {
    BodyText(text = stringResource(R.string.account_code_sent_to, isolated(email)), modifier = modifier)
}

@Composable
internal fun BodyText(text: String, modifier: Modifier = Modifier) {
    Text(
        text = text,
        modifier = modifier,
        style = MaterialTheme.typography.bodyLarge,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
}

/** Sends a new code; shows the seconds left until it may. */
@Composable
internal fun ResendButton(secondsLeft: Int, enabled: Boolean, onClick: () -> Unit, modifier: Modifier = Modifier) {
    TextButton(onClick = onClick, enabled = enabled, modifier = modifier.fillMaxWidth()) {
        Text(
            text = if (secondsLeft > 0) {
                val clock = String.format(Locale.ROOT, "%d:%02d", secondsLeft / 60, secondsLeft % 60)
                stringResource(R.string.account_action_resend_wait, clock)
            } else {
                stringResource(R.string.account_action_resend)
            },
        )
    }
}

/** A full-width secondary action, the same size as the primary button. */
@Composable
internal fun SecondaryButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    isDestructive: Boolean = false,
) {
    OutlinedButton(
        onClick = onClick,
        enabled = enabled,
        modifier = modifier
            .fillMaxWidth()
            .height(56.dp),
        shape = MaterialTheme.shapes.medium,
        colors = if (isDestructive) {
            ButtonDefaults.outlinedButtonColors(contentColor = MaterialTheme.colorScheme.error)
        } else {
            ButtonDefaults.outlinedButtonColors()
        },
    ) {
        Text(text = text, style = MaterialTheme.typography.titleMedium)
    }
}

/** Asks before an action that can't be taken back. [isDestructive] colours the confirm button as an error. */
@Composable
internal fun ConfirmDialog(
    title: String,
    text: String,
    confirmLabel: String,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
    isDestructive: Boolean = false,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        modifier = modifier,
        title = { Text(text = title) },
        text = { Text(text = text) },
        confirmButton = {
            TextButton(
                onClick = onConfirm,
                colors = if (isDestructive) {
                    ButtonDefaults.textButtonColors(contentColor = MaterialTheme.colorScheme.error)
                } else {
                    ButtonDefaults.textButtonColors()
                },
            ) {
                Text(text = confirmLabel, fontWeight = FontWeight.SemiBold)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text(text = stringResource(R.string.account_action_cancel)) }
        },
    )
}
