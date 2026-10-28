package app.awrad.core.network.session

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.AtomicFile
import app.awrad.core.network.IdGenerator
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json
import java.io.File
import java.io.IOException
import java.security.GeneralSecurityException
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * [CredentialStore] on files in `noBackupFilesDir`, each encrypted with AES-256-GCM under a non-exportable
 * Android Keystore key (ADR 0006). A file that can't be decrypted (for example after the key was lost) is
 * deleted and reads as empty: the device is then signed out, and a lost installation id is replaced.
 */
internal class KeystoreCredentialStore(context: Context, private val ids: IdGenerator) : CredentialStore {

    private val directory = File(context.noBackupFilesDir, DIRECTORY)
    private val key: SecretKey by lazy(::loadOrCreateKey)
    private val json = Json { ignoreUnknownKeys = true }
    private val lock = Any()

    override suspend fun installationId(): String = io {
        readFile(INSTALLATION_FILE) ?: ids.newId().also { writeFile(INSTALLATION_FILE, it) }
    }

    override suspend fun read(): StoredCredentials = io {
        val text = readFile(CREDENTIALS_FILE) ?: return@io StoredCredentials()
        try {
            json.decodeFromString(StoredCredentials.serializer(), text)
        } catch (_: SerializationException) {
            AtomicFile(File(directory, CREDENTIALS_FILE)).delete()
            StoredCredentials()
        }
    }

    override suspend fun write(credentials: StoredCredentials): Unit = io {
        if (credentials == StoredCredentials()) {
            AtomicFile(File(directory, CREDENTIALS_FILE)).delete()
        } else {
            writeFile(CREDENTIALS_FILE, json.encodeToString(StoredCredentials.serializer(), credentials))
        }
    }

    private suspend fun <T> io(block: () -> T): T = withContext(Dispatchers.IO) { synchronized(lock, block) }

    private fun readFile(name: String): String? {
        val file = AtomicFile(File(directory, name))
        if (!file.baseFile.exists()) return null
        return try {
            decrypt(file.readFully())
        } catch (_: GeneralSecurityException) {
            file.delete()
            null
        } catch (_: IOException) {
            file.delete()
            null
        }
    }

    private fun writeFile(name: String, value: String) {
        directory.mkdirs()
        val file = AtomicFile(File(directory, name))
        val output = file.startWrite()
        try {
            output.write(encrypt(value))
            file.finishWrite(output)
        } catch (error: IOException) {
            file.failWrite(output)
            throw error
        } catch (error: GeneralSecurityException) {
            file.failWrite(output)
            throw error
        }
    }

    /** `version (1 byte) ‖ IV (12 bytes) ‖ ciphertext with the GCM tag`. */
    private fun encrypt(value: String): ByteArray {
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, key)
        return byteArrayOf(VERSION) + cipher.iv + cipher.doFinal(value.toByteArray(Charsets.UTF_8))
    }

    private fun decrypt(payload: ByteArray): String {
        if (payload.size <= HEADER_SIZE || payload[0] != VERSION) throw GeneralSecurityException("Unknown payload")
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(TAG_BITS, payload, 1, IV_SIZE))
        return String(cipher.doFinal(payload, HEADER_SIZE, payload.size - HEADER_SIZE), Charsets.UTF_8)
    }

    private fun loadOrCreateKey(): SecretKey {
        val keyStore = KeyStore.getInstance(KEYSTORE).apply { load(null) }
        (keyStore.getKey(KEY_ALIAS, null) as? SecretKey)?.let { return it }
        val purposes = KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        val spec = KeyGenParameterSpec.Builder(KEY_ALIAS, purposes)
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(KEY_BITS)
            .setRandomizedEncryptionRequired(true)
            .build()
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE)
            .apply { init(spec) }
            .generateKey()
    }

    private companion object {
        const val DIRECTORY = "account_credentials"
        const val INSTALLATION_FILE = "installation.bin"
        const val CREDENTIALS_FILE = "credentials.bin"
        const val KEYSTORE = "AndroidKeyStore"
        const val KEY_ALIAS = "awrad_next_account_credentials"
        const val TRANSFORMATION = "AES/GCM/NoPadding"
        const val KEY_BITS = 256
        const val IV_SIZE = 12
        const val TAG_BITS = 128
        const val HEADER_SIZE = 1 + IV_SIZE
        const val VERSION: Byte = 1
    }
}
