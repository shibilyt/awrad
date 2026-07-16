package app.awrad.awrad_dhikrgoalstracker.ui.screens.counting

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import app.awrad.awrad_dhikrgoalstracker.R

@Composable
fun CountingAvailabilityDialog(
    prompt: CountingAvailabilityPromptUiState,
    onConfirm: () -> Unit,
    onCancel: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onCancel,
        title = { Text(stringResource(R.string.counting_availability_title)) },
        text = {
            Column {
                Text(stringResource(R.string.counting_availability_intro))
                Spacer(Modifier.height(8.dp))
                prompt.decision.reasons.forEach { reason ->
                    Text("• ${reason.localizedMessage(prompt)}")
                }
            }
        },
        confirmButton = {
            TextButton(onClick = onConfirm) {
                Text(
                    stringResource(
                        when (prompt.actionLabel) {
                            CountingAvailabilityActionLabel.COUNT -> R.string.counting_availability_count_anyway
                            CountingAvailabilityActionLabel.START -> R.string.counting_availability_start_anyway
                            CountingAvailabilityActionLabel.RESUME -> R.string.counting_availability_resume_anyway
                        },
                    ),
                )
            }
        },
        dismissButton = {
            TextButton(onClick = onCancel) {
                Text(stringResource(R.string.action_cancel))
            }
        },
    )
}

@Composable
private fun CountingAvailabilityReason.localizedMessage(
    prompt: CountingAvailabilityPromptUiState,
): String = when (this) {
    CountingAvailabilityReason.FUTURE_START -> stringResource(
        R.string.counting_availability_future_start,
        prompt.goalStartDate.toString(),
    )
    CountingAvailabilityReason.OFF_RECURRENCE ->
        stringResource(R.string.counting_availability_off_recurrence)
    CountingAvailabilityReason.SLOT_UPCOMING -> if (prompt.slotStartText.isNotBlank()) {
        stringResource(R.string.counting_availability_slot_upcoming, prompt.slotStartText)
    } else {
        stringResource(R.string.counting_availability_slot_upcoming_unknown)
    }
    CountingAvailabilityReason.SLOT_ENDED -> if (prompt.slotEndText.isNotBlank()) {
        stringResource(R.string.counting_availability_slot_ended, prompt.slotEndText)
    } else {
        stringResource(R.string.counting_availability_slot_ended_unknown)
    }
    CountingAvailabilityReason.SLOT_TIMING_UNAVAILABLE ->
        stringResource(R.string.counting_availability_slot_unknown)
}
