package com.google.ai.edge.examples.litert_edge_demos

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.text.PDFTextStripper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.nio.ByteBuffer
import java.nio.charset.CodingErrorAction
import java.util.UUID
import java.util.concurrent.Executors

/** SAF only, no network client. Large model imports never allocate the file as byte[]. */
class LivingMemoryDocuments(private val activity: Activity) : MethodChannel.MethodCallHandler {
    private val worker = Executors.newSingleThreadExecutor()
    private var pending: MethodChannel.Result? = null
    private var modelPick = false
    private var audioPick = false
    private var closed = false
    private val modelDir get() = File(activity.cacheDir, "living-memory-model-import").apply { mkdirs() }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "availableModelBytes") { result.success(activity.filesDir.usableSpace); return }
        if (call.method == "modelCache") { result.success(modelDir.absolutePath); return }
        if (call.method != "pickDocument" && call.method != "pickModel" && call.method != "pickAudio") { result.notImplemented(); return }
        if (closed || pending != null) { result.error("BUSY", "Un import est déjà en cours.", null); return }
        modelPick = call.method == "pickModel"
        audioPick = call.method == "pickAudio"
        pending = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            if (audioPick) putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("audio/wav", "audio/x-wav", "audio/wave"))
            else if (!modelPick) putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("text/plain", "application/pdf"))
        }
        try { activity.startActivityForResult(intent, REQUEST) }
        catch (e: Exception) { pending = null; result.error("PICKER", e.message, null) }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST) return false
        val reply = pending ?: return true
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            pending = null; reply.success(null); return true
        }
        val model = modelPick
        val audio = audioPick
        worker.execute {
            var error: Exception? = null
            var value: Any? = null
            try { value = if (model) copyModel(uri) else if (audio) readAudio(uri) else extractDocument(uri) }
            catch (e: Exception) { error = e }
            activity.runOnUiThread {
                if (!closed && pending === reply) {
                    pending = null
                    if (error != null) reply.error("IMPORT", error.message ?: "Import impossible", null)
                    else reply.success(value)
                }
            }
        }
        return true
    }

    private fun name(uri: Uri): String {
        activity.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use {
            if (it.moveToFirst()) return it.getString(0).take(200)
        }
        throw IllegalArgumentException("Nom de fichier indisponible.")
    }

    private fun copyModel(uri: Uri): String {
        val name = name(uri)
        require(name.endsWith(".litertlm", ignoreCase = true)) { "Choisis un modèle .litertlm, pas .task, GGUF ou safetensors." }
        // Remove only stale temporary model copies, never installed files.
        modelDir.listFiles()?.filter { System.currentTimeMillis() - it.lastModified() > 86400000L }?.forEach { it.delete() }
        val target = File(modelDir, "${UUID.randomUUID()}-${File(name).name}")
        try {
            activity.contentResolver.openInputStream(uri)?.use { input ->
                target.outputStream().use { output ->
                    val buffer = ByteArray(1024 * 1024)
                    var total = 0L
                    while (true) {
                        val n = input.read(buffer); if (n < 0) break
                        total += n
                        require(total <= 8L * 1024 * 1024 * 1024) { "Modèle supérieur à 8 Gio." }
                        require(modelDir.usableSpace > n + 64L * 1024 * 1024) { "Espace de stockage insuffisant." }
                        output.write(buffer, 0, n)
                    }
                    require(total > 0) { "Fichier vide." }
                }
            } ?: throw IllegalArgumentException("Fichier illisible.")
            return target.absolutePath
        } catch (e: Exception) { target.delete(); throw e }
    }

    /** Bounded WAV only; Dart validates 16 kHz mono PCM16 and <=30 s. No cache file. */
    private fun readAudio(uri: Uri): Map<String, Any> {
        val filename = name(uri)
        require(filename.endsWith(".wav", ignoreCase = true)) { "Choisis un fichier WAV PCM16 mono 16 kHz." }
        val raw = ByteArrayOutputStream()
        activity.contentResolver.openInputStream(uri)?.use { input ->
            val buffer = ByteArray(65536)
            var total = 0
            while (true) {
                val n = input.read(buffer); if (n < 0) break
                total += n
                require(total <= 2 * 1024 * 1024) { "Audio supérieur à 2 Mio." }
                raw.write(buffer, 0, n)
            }
        } ?: throw IllegalArgumentException("Fichier audio illisible.")
        return mapOf("name" to filename, "bytes" to raw.toByteArray())
    }

    private fun extractDocument(uri: Uri): Map<String, Any> {
        val filename = name(uri)
        val isPdf = filename.endsWith(".pdf", ignoreCase = true)
        require(isPdf || filename.endsWith(".txt", ignoreCase = true)) { "Formats acceptés : TXT UTF-8 et PDF texte." }
        val raw = ByteArrayOutputStream()
        activity.contentResolver.openInputStream(uri)?.use { input ->
            val buffer = ByteArray(65536)
            var total = 0
            while (true) {
                val n = input.read(buffer); if (n < 0) break
                total += n
                require(total <= 16 * 1024 * 1024) { "Document supérieur à 16 Mio." }
                raw.write(buffer, 0, n)
            }
        } ?: throw IllegalArgumentException("Document illisible.")
        val pages: List<String> = if (!isPdf) {
            val decoder = Charsets.UTF_8.newDecoder().onMalformedInput(CodingErrorAction.REPORT)
                .onUnmappableCharacter(CodingErrorAction.REPORT)
            listOf(decoder.decode(ByteBuffer.wrap(raw.toByteArray())).toString().removePrefix("\uFEFF"))
        } else {
            PDFBoxResourceLoader.init(activity.applicationContext)
            PDDocument.load(raw.toByteArray()).use { pdf ->
                require(!pdf.isEncrypted) { "PDF chiffré non pris en charge." }
                require(pdf.currentAccessPermission.canExtractContent()) { "Extraction de ce PDF interdite." }
                require(pdf.numberOfPages <= 200) { "PDF supérieur à 200 pages." }
                val stripper = PDFTextStripper()
                var chars = 0
                (1..pdf.numberOfPages).map { page ->
                    stripper.startPage = page; stripper.endPage = page
                    stripper.getText(pdf).also {
                        chars += it.length
                        require(chars <= 4 * 1024 * 1024) { "Texte extrait supérieur à 4 Mio de caractères." }
                    }
                }
            }
        }
        require(pages.any { it.isNotBlank() }) { "Aucun texte : PDF scanné non pris en charge (pas d’OCR)." }
        return mapOf("name" to filename, "pages" to pages, "kind" to if (isPdf) "pdf" else "txt")
    }

    fun close() {
        closed = true
        pending?.error("CLOSED", "Import interrompu par la fermeture de l’activité.", null)
        pending = null
        worker.shutdown()
    }

    companion object { const val REQUEST = 9341 }
}
