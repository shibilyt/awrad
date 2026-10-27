package app.awrad.feature.account

import android.text.BidiFormatter
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import app.awrad.core.designsystem.component.AwradButtonVariant
import app.awrad.core.designsystem.component.AwradDialog
import app.awrad.core.designsystem.component.AwradRowButton
import app.awrad.core.designsystem.component.AwradTextButton
import app.awrad.core.designsystem.icon.AwradIcons
import app.awrad.core.designsystem.theme.AwradTheme
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
        style = AwradTheme.type.body,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
}

/** Body text that says practice stays on this device, led by the `phone` icon. */
@Composable
internal fun DeviceNote(text: String, modifier: Modifier = Modifier) {
    Row(
        modifier = modifier,
        horizontalArrangement = Arrangement.spacedBy(AwradTheme.spacing.inlineGap),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            imageVector = AwradIcons.Phone,
            contentDescription = null,
            modifier = Modifier.size(AwradTheme.sizes.iconSmall),
            tint = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        BodyText(text = text, modifier = Modifier.weight(1f))
    }
}

/** Sends a new code; shows the seconds left until it may. */
@Composable
internal fun ResendButton(secondsLeft: Int, enabled: Boolean, onClick: () -> Unit, modifier: Modifier = Modifier) {
    AwradTextButton(
        text = if (secondsLeft > 0) {
            val clock = String.format(Locale.ROOT, "%d:%02d", secondsLeft / 60, secondsLeft % 60)
            stringResource(R.string.account_action_resend_wait, clock)
        } else {
            stringResource(R.string.account_action_resend)
        },
        onClick = onClick,
        modifier = modifier.fillMaxWidth(),
        enabled = enabled,
    )
}

/** Asks before an action that can't be taken back. [isDestructive] makes the confirm button the error one. */
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
    AwradDialog(
        onDismissRequest = onDismiss,
        title = title,
        text = text,
        modifier = modifier,
        confirmButton = {
            AwradRowButton(
                text = confirmLabel,
                onClick = onConfirm,
                variant = if (isDestructive) AwradButtonVariant.Error else AwradButtonVariant.Main,
            )
        },
        dismissButton = {
            AwradTextButton(text = stringResource(R.string.account_action_cancel), onClick = onDismiss)
        },
    )
}
