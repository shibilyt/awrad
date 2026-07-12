package app.awrad.awrad_dhikrgoalstracker.notification

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Helps detect battery optimization state and OEM-specific issues that
 * prevent reliable alarm/notification delivery.
 */
@Singleton
class BatteryOptimizationHelper @Inject constructor(
    @ApplicationContext private val context: Context,
) {
    private val powerManager: PowerManager =
        context.getSystemService(PowerManager::class.java)

    /**
     * Returns true if the app is exempt from battery optimizations.
     */
    fun isIgnoringBatteryOptimizations(): Boolean =
        powerManager.isIgnoringBatteryOptimizations(context.packageName)

    /**
     * Returns an intent to request battery optimization exemption.
     */
    fun createBatteryOptimizationIntent(): Intent =
        Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
            data = Uri.parse("package:${context.packageName}")
        }

    /**
     * Returns an intent to the app's battery settings page (fallback).
     */
    fun createAppBatterySettingsIntent(): Intent =
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.parse("package:${context.packageName}")
        }

    /**
     * Detects the device manufacturer and returns OEM-specific info
     * about battery killer behavior and how to fix it.
     */
    fun getOemBatteryInfo(): OemBatteryInfo? {
        val manufacturer = Build.MANUFACTURER.lowercase()
        return when {
            manufacturer.contains("samsung") -> OemBatteryInfo(
                type = OemBatteryType.SAMSUNG,
                dontKillMyAppUrl = "https://dontkillmyapp.com/samsung",
            )
            manufacturer.contains("xiaomi") || manufacturer.contains("redmi") -> OemBatteryInfo(
                type = OemBatteryType.XIAOMI,
                dontKillMyAppUrl = "https://dontkillmyapp.com/xiaomi",
            )
            manufacturer.contains("huawei") || manufacturer.contains("honor") -> OemBatteryInfo(
                type = OemBatteryType.HUAWEI,
                dontKillMyAppUrl = "https://dontkillmyapp.com/huawei",
            )
            manufacturer.contains("oneplus") || manufacturer.contains("oppo") || manufacturer.contains("realme") -> OemBatteryInfo(
                type = OemBatteryType.OPPO_ONEPLUS_REALME,
                dontKillMyAppUrl = "https://dontkillmyapp.com/oneplus",
            )
            manufacturer.contains("vivo") -> OemBatteryInfo(
                type = OemBatteryType.VIVO,
                dontKillMyAppUrl = "https://dontkillmyapp.com/vivo",
            )
            else -> null // Stock Android or unknown OEM — no special steps needed
        }
    }
}

data class OemBatteryInfo(
    val type: OemBatteryType,
    val dontKillMyAppUrl: String,
)

enum class OemBatteryType {
    SAMSUNG,
    XIAOMI,
    HUAWEI,
    OPPO_ONEPLUS_REALME,
    VIVO,
}
