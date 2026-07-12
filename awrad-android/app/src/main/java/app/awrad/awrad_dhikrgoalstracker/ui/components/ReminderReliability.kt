package app.awrad.awrad_dhikrgoalstracker.ui.components

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.notification.OemBatteryInfo
import app.awrad.awrad_dhikrgoalstracker.notification.OemBatteryType

data class ReminderReliabilityUiState(
    val canScheduleExactAlarms: Boolean = true,
    val isIgnoringBatteryOptimizations: Boolean = true,
    val oemBatteryInfo: OemBatteryInfo? = null,
)

enum class ReminderReliabilityAction {
    ExactAlarmSettings,
    BatteryOptimizationSettings,
}

object ReminderReliabilityPolicy {
    fun requiredSystemActions(state: ReminderReliabilityUiState): List<ReminderReliabilityAction> =
        buildList {
            if (!state.canScheduleExactAlarms) {
                add(ReminderReliabilityAction.ExactAlarmSettings)
            }
            if (!state.isIgnoringBatteryOptimizations) {
                add(ReminderReliabilityAction.BatteryOptimizationSettings)
            }
        }

    fun shouldShowOemGuide(state: ReminderReliabilityUiState): Boolean =
        state.oemBatteryInfo != null

    fun hasRequiredSystemActions(state: ReminderReliabilityUiState): Boolean =
        requiredSystemActions(state).isNotEmpty()
}

@Composable
fun OemBatteryGuideDialog(
    info: OemBatteryInfo,
    onDismiss: () -> Unit,
) {
    val context = LocalContext.current
    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text(stringResource(R.string.settings_oem_battery_dialog_title, oemBatteryName(info.type)))
        },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(
                    text = oemBatteryIssue(info.type),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                oemBatterySteps(info.type).forEachIndexed { index, step ->
                    Text(
                        text = stringResource(R.string.settings_oem_battery_step, index + 1, step),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                }
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    try {
                        context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(info.dontKillMyAppUrl)))
                    } catch (_: ActivityNotFoundException) {
                        // No browser available; keep the dialog open.
                    }
                },
            ) {
                Text(stringResource(R.string.settings_oem_battery_open_guide))
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text(stringResource(R.string.action_close))
            }
        },
    )
}

@Composable
fun oemBatteryName(type: OemBatteryType): String = when (type) {
    OemBatteryType.SAMSUNG -> stringResource(R.string.settings_oem_samsung)
    OemBatteryType.XIAOMI -> stringResource(R.string.settings_oem_xiaomi)
    OemBatteryType.HUAWEI -> stringResource(R.string.settings_oem_huawei)
    OemBatteryType.OPPO_ONEPLUS_REALME -> stringResource(R.string.settings_oem_oppo_oneplus_realme)
    OemBatteryType.VIVO -> stringResource(R.string.settings_oem_vivo)
}

@Composable
fun oemBatteryIssue(type: OemBatteryType): String = when (type) {
    OemBatteryType.SAMSUNG -> stringResource(R.string.settings_oem_samsung_issue)
    OemBatteryType.XIAOMI -> stringResource(R.string.settings_oem_xiaomi_issue)
    OemBatteryType.HUAWEI -> stringResource(R.string.settings_oem_huawei_issue)
    OemBatteryType.OPPO_ONEPLUS_REALME -> stringResource(R.string.settings_oem_oppo_oneplus_realme_issue)
    OemBatteryType.VIVO -> stringResource(R.string.settings_oem_vivo_issue)
}

@Composable
fun oemBatterySteps(type: OemBatteryType): List<String> = when (type) {
    OemBatteryType.SAMSUNG -> listOf(
        stringResource(R.string.settings_oem_samsung_step_1),
        stringResource(R.string.settings_oem_samsung_step_2),
        stringResource(R.string.settings_oem_samsung_step_3),
    )
    OemBatteryType.XIAOMI -> listOf(
        stringResource(R.string.settings_oem_xiaomi_step_1),
        stringResource(R.string.settings_oem_xiaomi_step_2),
        stringResource(R.string.settings_oem_xiaomi_step_3),
    )
    OemBatteryType.HUAWEI -> listOf(
        stringResource(R.string.settings_oem_huawei_step_1),
        stringResource(R.string.settings_oem_huawei_step_2),
        stringResource(R.string.settings_oem_huawei_step_3),
    )
    OemBatteryType.OPPO_ONEPLUS_REALME -> listOf(
        stringResource(R.string.settings_oem_oppo_oneplus_realme_step_1),
        stringResource(R.string.settings_oem_oppo_oneplus_realme_step_2),
        stringResource(R.string.settings_oem_oppo_oneplus_realme_step_3),
        stringResource(R.string.settings_oem_oppo_oneplus_realme_step_4),
    )
    OemBatteryType.VIVO -> listOf(
        stringResource(R.string.settings_oem_vivo_step_1),
        stringResource(R.string.settings_oem_vivo_step_2),
    )
}
