package com.google.ai.edge.examples.litert_edge_demos

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.AtomicFile
import java.io.File
import java.security.KeyStore
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Device-local envelope; never export the Keystore wrapping key or log errors.
 * Losing either part is an error, not permission to replace the database key.
 * No user-auth binding: changing biometrics must not invalidate existing data.
 */
class LivingMemorySecurity(context: Context) : MethodChannel.MethodCallHandler {
    private val envelope = AtomicFile(File(context.noBackupFilesDir, "living-memory-key-v1"))
    private val alias = "living-memory-wrap-v1"
    private val aad = "living-memory/sqlcipher/v1".toByteArray(Charsets.UTF_8)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "databaseKey") { result.notImplemented(); return }
        try {
            result.success(databaseKey(call.argument<Boolean>("mayCreate") == true))
        } catch (_: Exception) {
            result.error("memory_key_unavailable", "Clé indisponible. Données conservées ; ne pas désinstaller.", null)
        }
    }

    @Synchronized
    private fun databaseKey(mayCreate: Boolean): String {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val exists = envelope.baseFile.exists() || File(envelope.baseFile.path + ".bak").exists()
        if (exists) {
            val key = store.getKey(alias, null) as? SecretKey ?: error("missing key")
            val bytes = envelope.readFully()
            require(bytes.size == 1 + 12 + 32 + 16 && bytes[0] == 1.toByte())
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(128, bytes.copyOfRange(1, 13)))
            cipher.updateAAD(aad)
            val raw = cipher.doFinal(bytes.copyOfRange(13, bytes.size))
            try {
                require(raw.size == 32)
                return raw.joinToString("") { "%02x".format(it.toInt() and 255) }
            } finally { raw.fill(0) }
        }
        check(mayCreate) // never create a new key for an encrypted database
        val key = if (store.containsAlias(alias)) {
            store.getKey(alias, null) as SecretKey
        } else {
            KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").run {
                init(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    .setKeySize(256)
                    .setRandomizedEncryptionRequired(true)
                    .build())
                generateKey()
            }
        }
        val raw = ByteArray(32).also { SecureRandom().nextBytes(it) }
        try {
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.ENCRYPT_MODE, key)
            cipher.updateAAD(aad)
            val ciphertext = cipher.doFinal(raw)
            require(cipher.iv.size == 12)
            val output = envelope.startWrite()
            try {
                output.write(byteArrayOf(1) + cipher.iv + ciphertext)
                envelope.finishWrite(output)
            } catch (e: Exception) {
                envelope.failWrite(output)
                throw e
            }
            // Verify persistent envelope before permitting any DB creation/migration.
            return databaseKey(false)
        } finally { raw.fill(0) }
    }
}
