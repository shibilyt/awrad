package app.awrad.awrad_dhikrgoalstracker.data.network

import okhttp3.HttpUrl.Companion.toHttpUrlOrNull

object NetworkConfig {
    fun normalizedBaseUrl(rawBaseUrl: String, isDebug: Boolean): String {
        val normalized = if (rawBaseUrl.endsWith("/")) rawBaseUrl else "$rawBaseUrl/"
        val url = normalized.toHttpUrlOrNull()
            ?: error("Invalid API base URL: $rawBaseUrl")

        check(isDebug || url.isHttps) {
            "Release API base URL must use HTTPS: $rawBaseUrl"
        }
        check(isDebug || url.host != "10.0.2.2") {
            "Release API base URL must not point at the Android emulator host"
        }
        return normalized
    }
}
