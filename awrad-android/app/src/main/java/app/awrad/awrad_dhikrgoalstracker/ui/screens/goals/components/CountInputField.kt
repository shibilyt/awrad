package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.AssistChip
import androidx.compose.material3.FilledTonalIconButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Remove

private const val MaxTargetCount = 999_999_999

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun CountInputField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    quickValues: List<Int> = listOf(33, 100, 1000),
    step: Int = 1,
    decreaseContentDescription: String? = null,
    increaseContentDescription: String? = null,
    modifier: Modifier = Modifier,
) {
    val currentCount = value.toIntOrNull()
    val canDecrease = currentCount != null && currentCount > 1

    Column(modifier = modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            FilledTonalIconButton(
                onClick = {
                    val next = ((currentCount ?: 1) - step).coerceAtLeast(1)
                    onValueChange(next.toString())
                },
                enabled = canDecrease,
                modifier = Modifier.size(52.dp),
            ) {
                Icon(
                    imageVector = Icons.Default.Remove,
                    contentDescription = decreaseContentDescription,
                )
            }
            OutlinedTextField(
                value = value,
                onValueChange = { newValue ->
                    if (newValue.isEmpty() || newValue.all { it.isDigit() }) onValueChange(newValue)
                },
                modifier = Modifier.weight(1f).widthIn(min = 0.dp),
                label = { Text(label) },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                singleLine = true,
                textStyle = MaterialTheme.typography.headlineSmall.copy(
                    textAlign = TextAlign.Center,
                    fontWeight = FontWeight.SemiBold,
                ),
            )
            FilledTonalIconButton(
                onClick = {
                    val base = currentCount ?: 0
                    val next = if (base >= MaxTargetCount) {
                        MaxTargetCount
                    } else {
                        (base + step).coerceIn(1, MaxTargetCount)
                    }
                    onValueChange(next.toString())
                },
                modifier = Modifier.size(52.dp),
            ) {
                Icon(
                    imageVector = Icons.Default.Add,
                    contentDescription = increaseContentDescription,
                )
            }
        }
        if (quickValues.isNotEmpty()) {
            Spacer(modifier = Modifier.height(8.dp))
            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
                modifier = Modifier.fillMaxWidth(),
            ) {
                quickValues.forEach { qv ->
                    AssistChip(
                        onClick = { onValueChange(qv.toString()) },
                        label = {
                            Box(contentAlignment = Alignment.Center) {
                                Text("%,d".format(qv))
                            }
                        },
                    )
                }
            }
        }
    }
}
