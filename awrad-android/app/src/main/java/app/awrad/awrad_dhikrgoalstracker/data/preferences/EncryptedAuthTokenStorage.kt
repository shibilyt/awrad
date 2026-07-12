package app.awrad.awrad_dhikrgoalstracker.data.preferences

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.AtomicFile
import java.io.File
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

class EncryptedAuthTokenStorage private constructor(context: Context) : AuthTokenStorage {
    private val directory = File(context.noBackupFilesDir, DIRECTORY).apply { mkdirs() }
    private val key: SecretKey by lazy(::loadOrCreateKey)

    @Synchronized
    override fun getString(keyName: String): String? {
        val file = AtomicFile(File(directory, safeName(keyName)))
        if (!file.baseFile.exists()) return null
        return runCatching {
            val payload = file.readFully()
            require(payload.size > IV_SIZE + 1 && payload[0] == VERSION)
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(TAG_BITS, payload, 1, IV_SIZE))
            String(cipher.doFinal(payload, 1 + IV_SIZE, payload.size - 1 - IV_SIZE), Charsets.UTF_8)
        }.getOrElse {
            file.delete()
            null
        }
    }

    @Synchronized
    override fun putString(keyName: String, value: String) {
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, key)
        val encrypted = cipher.doFinal(value.toByteArray(Charsets.UTF_8))
        val payload = byteArrayOf(VERSION) + cipher.iv + encrypted
        val file = AtomicFile(File(directory, safeName(keyName)))
        val output = file.startWrite()
        try {
            output.write(payload)
            file.finishWrite(output)
        } catch (error: Throwable) {
            file.failWrite(output)
            throw error
        }
    }

    @Synchronized
    override fun remove(keyName: String) {
        AtomicFile(File(directory, safeName(keyName))).delete()
    }

    private fun loadOrCreateKey(): SecretKey {
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (keyStore.getKey(KEY_ALIAS, null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").run {
            init(
                KeyGenParameterSpec.Builder(KEY_ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    .setKeySize(256)
                    .setRandomizedEncryptionRequired(true)
                    .build(),
            )
            generateKey()
        }
    }

    private fun safeName(key: String) = key.replace(Regex("[^A-Za-z0-9_.-]"), "_") + ".bin"

    companion object {
        const val FILE_NAME = "awrad_auth_tokens"
        private const val DIRECTORY = "auth_credentials_v2"
        private const val KEY_ALIAS = "awrad_auth_credentials_v2"
        private const val TRANSFORMATION = "AES/GCM/NoPadding"
        private const val IV_SIZE = 12
        private const val TAG_BITS = 128
        private const val VERSION: Byte = 1

        fun create(context: Context): EncryptedAuthTokenStorage = EncryptedAuthTokenStorage(context)
    }
}
