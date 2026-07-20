package app.awrad.awrad_dhikrgoalstracker.ui.navigation

import java.net.URI
import java.net.URLDecoder
import java.nio.charset.StandardCharsets

object AuthVerificationLink {
    fun token(url: String, expectedHttpsHost: String): String? {
        val uri = runCatching { URI(url) }.getOrNull() ?: return null
        if (uri.scheme == "awrad" && uri.host == "verify-email") {
            return uri.rawQuery.orEmpty().split('&')
                .mapNotNull { item ->
                    val parts = item.split('=', limit = 2)
                    if (parts.firstOrNull() == "token") parts.getOrNull(1) else null
                }
                .firstOrNull()
                ?.let { URLDecoder.decode(it, StandardCharsets.UTF_8.name()) }
                ?.takeIf { it.isNotBlank() }
        }
        if (uri.scheme != "https" || !uri.host.equals(expectedHttpsHost, ignoreCase = true)) return null

        val segments = uri.path.trim('/').split('/').filter { it.isNotEmpty() }
        val isLegacy = segments.size == 3 && segments.take(2) == listOf("auth", "verify-email")
        val isMobile = segments.size == 4 && segments.take(3) == listOf("auth", "mobile", "verify-email")
        return if (isLegacy || isMobile) {
            URLDecoder.decode(segments.last(), StandardCharsets.UTF_8.name()).takeIf { it.isNotBlank() }
        } else null
    }
}
