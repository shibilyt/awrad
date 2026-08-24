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
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AssistChip
import androidx.compose.material3.AssistChipDefaults
import androidx.compose.material3.FilledTonalIconButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Remove
import app.awrad.awrad_dhikrgoalstracker.ui.theme.isAwradDarkTheme

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
    integratedStepper: Boolean = false,
    modifier: Modifier = Modifier,
) {
    val currentCount = value.toIntOrNull()
    val canDecrease = currentCount != null && currentCount > 1
    val decrease = {
        val next = ((currentCount ?: 1) - step).coerceAtLeast(1)
        onValueChange(next.toString())
    }
    val increase = {
        val base = currentCount ?: 0
        val next = if (base >= MaxTargetCount) {
            MaxTargetCount
        } else {
            (base + step).coerceIn(1, MaxTargetCount)
        }
        onValueChange(next.toString())
    }

    Column(modifier = modifier.fillMaxWidth()) {
        if (integratedStepper) {
            val fieldColor = if (isAwradDarkTheme()) {
                MaterialTheme.colorScheme.surfaceContainerHighest
            } else {
                Color.White
            }
            val buttonBorderColor = MaterialTheme.colorScheme.outline.copy(alpha = 0.72f)
            val buttonBackgroundColor = MaterialTheme.colorScheme.primary.copy(
                alpha = if (isAwradDarkTheme()) 0.16f else 0.12f,
            )
            val stepperRadius = 12.dp
            val stepperShape = RoundedCornerShape(stepperRadius)
            val decreaseButtonShape = RoundedCornerShape(
                topStart = stepperRadius,
                topEnd = 0.dp,
                bottomEnd = 0.dp,
                bottomStart = stepperRadius,
            )
            val increaseButtonShape = RoundedCornerShape(
                topStart = 0.dp,
                topEnd = stepperRadius,
                bottomEnd = stepperRadius,
                bottomStart = 0.dp,
            )
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(
                    text = label,
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("count-input-integrated-label"),
                )
                OutlinedTextField(
                    value = value,
                    onValueChange = { newValue ->
                        if (newValue.isEmpty() || newValue.all { it.isDigit() }) onValueChange(newValue)
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(64.dp)
                        .testTag("count-input-integrated-stepper"),
                    leadingIcon = {
                        IconButton(
                            onClick = decrease,
                            enabled = canDecrease,
                            modifier = Modifier
                                .size(64.dp)
                                .background(buttonBackgroundColor, decreaseButtonShape)
                                .border(1.dp, buttonBorderColor, decreaseButtonShape)
                                .testTag("count-input-decrease"),
                        ) {
                            Icon(
                                imageVector = Icons.Default.Remove,
                                contentDescription = decreaseContentDescription,
                            )
                        }
                    },
                    trailingIcon = {
                        IconButton(
                            onClick = increase,
                            modifier = Modifier
                                .size(64.dp)
                                .background(buttonBackgroundColor, increaseButtonShape)
                                .border(1.dp, buttonBorderColor, increaseButtonShape)
                                .testTag("count-input-increase"),
                        ) {
                            Icon(
                                imageVector = Icons.Default.Add,
                                contentDescription = increaseContentDescription,
                            )
                        }
                    },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    singleLine = true,
                    shape = stepperShape,
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedContainerColor = fieldColor,
                        unfocusedContainerColor = fieldColor,
                        disabledContainerColor = fieldColor,
                        focusedBorderColor = MaterialTheme.colorScheme.primary,
                        unfocusedBorderColor = MaterialTheme.colorScheme.outline,
                    ),
                    textStyle = MaterialTheme.typography.headlineSmall.copy(
                        textAlign = TextAlign.Center,
                        fontWeight = FontWeight.SemiBold,
                    ),
                )
            }
        } else {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                FilledTonalIconButton(
                    onClick = decrease,
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
                    onClick = increase,
                    modifier = Modifier.size(52.dp),
                ) {
                    Icon(
                        imageVector = Icons.Default.Add,
                        contentDescription = increaseContentDescription,
                    )
                }
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
                        modifier = if (integratedStepper) {
                            Modifier.testTag("count-input-quick-value-$qv")
                        } else {
                            Modifier
                        },
                        colors = if (integratedStepper) {
                            AssistChipDefaults.assistChipColors(
                                containerColor = MaterialTheme.colorScheme.primary.copy(
                                    alpha = if (isAwradDarkTheme()) 0.16f else 0.12f,
                                ),
                                labelColor = MaterialTheme.colorScheme.onSurface,
                            )
                        } else {
                            AssistChipDefaults.assistChipColors()
                        },
                        border = if (integratedStepper) {
                            null
                        } else {
                            BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant)
                        },
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
