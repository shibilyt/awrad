package app.awrad.awrad_dhikrgoalstracker.data.preferences

import android.content.Context
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

class EncryptedAuthTokenStorage private constructor(
    private val preferences: android.content.SharedPreferences,
) : AuthTokenStorage {

    override fun getString(key: String): String? = preferences.getString(key, null)

    override fun putString(key: String, value: String) {
        check(preferences.edit().putString(key, value).commit()) {
            "Failed to persist auth token"
        }
    }

    override fun remove(key: String) {
        check(preferences.edit().remove(key).commit()) {
            "Failed to remove auth token"
        }
    }

    companion object {
        const val FILE_NAME = "awrad_auth_tokens"

        fun create(context: Context): EncryptedAuthTokenStorage {
            val masterKey = MasterKey.Builder(context)
                .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                .build()
            val preferences = EncryptedSharedPreferences.create(
                context,
                FILE_NAME,
                masterKey,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
            )
            return EncryptedAuthTokenStorage(preferences)
        }
    }
}
