package com.google.ai.edge.examples.litert_edge_demos

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.InputStream
import java.io.OutputStream
import java.util.UUID
import java.util.concurrent.Executors

/** SAF transfers encrypted bytes only. Keys never cross this channel. */
class LivingMemoryTransfer(private val activity: Activity) : MethodChannel.MethodCallHandler {
    private val worker = Executors.newSingleThreadExecutor()
    private var pending: MethodChannel.Result? = null
    private var exportFile: File? = null
    @Volatile private var closed = false

    private fun directory(): File {
        val trustedRoot = activity.cacheDir.canonicalFile
        val file = File(trustedRoot, "living-memory-transfer").absoluteFile
        require(file.parentFile == trustedRoot)
        require(file.canonicalFile == file)
        if (!file.exists()) check(file.mkdirs())
        require(file.isDirectory && file.canonicalFile == file)
        return file
    }

    private fun confined(path: String): File {
        val file = File(path).absoluteFile
        require(file.canonicalFile == file && file.parentFile == directory())
        require(file.isFile && file.length() > 0 && file.length() <= MAX_BACKUP_BYTES)
        return file
    }

    private fun clean(file: File?) {
        try {
            if (file != null && file.canonicalFile == file && file.parentFile == directory()) file.delete()
        } catch (_: Exception) { /* Private encrypted remnant; never touch active data. */ }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (closed) { result.error("CLOSED", "Transfert indisponible.", null); return }
        if (call.method == "transferDirectory") {
            try { result.success(directory().path) }
            catch (_: Exception) { result.error("STORAGE", "Stockage de transfert indisponible.", null) }
            return
        }
        if (call.method != "saveBackup" && call.method != "pickBackup") { result.notImplemented(); return }
        if (pending != null) { result.error("BUSY", "Un transfert est déjà en cours.", null); return }
        val exporting = call.method == "saveBackup"
        try {
            exportFile = if (exporting) confined(call.argument<String>("path") ?: error("path")) else null
            pending = result
            val intent = Intent(if (exporting) Intent.ACTION_CREATE_DOCUMENT else Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "application/octet-stream"
                if (exporting) putExtra(Intent.EXTRA_TITLE, "living-memory-${System.currentTimeMillis()}.lmemory")
            }
            activity.startActivityForResult(intent, REQUEST)
        } catch (_: Exception) {
            pending = null
            clean(exportFile)
            exportFile = null
            result.error("TRANSFER", "Sélection de fichier impossible.", null)
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST) return false
        val reply = pending ?: return true
        val uri = data?.data
        val source = exportFile
        if (resultCode != Activity.RESULT_OK || uri == null) {
            pending = null
            exportFile = null
            clean(source)
            reply.success(if (source != null) false else null)
            return true
        }
        // Leave pending in place until worker completion so a second picker
        // cannot race this transfer or receive its result.
        worker.execute {
            var imported: File? = null
            var success = false
            try {
                if (source != null) {
                    val input = confined(source.path)
                    input.inputStream().use { from ->
                        activity.contentResolver.openOutputStream(uri, "wt")?.use { to -> copyBounded(from, to) }
                            ?: error("output")
                    }
                } else {
                    val target = File(directory(), "import-${UUID.randomUUID()}.lmemory")
                    check(target.createNewFile())
                    imported = target
                    activity.contentResolver.openInputStream(uri)?.use { from ->
                        target.outputStream().use { to -> copyBounded(from, to) }
                    } ?: error("input")
                }
                success = true
            } catch (_: Exception) {
                clean(imported)
                imported = null
                if (source != null) removePartialDocument(uri)
            } finally {
                clean(source)
            }
            val completedFile = imported
            val succeeded = success
            activity.runOnUiThread {
                if (!closed && pending === reply) {
                    pending = null
                    exportFile = null
                    if (succeeded) reply.success(if (source != null) true else completedFile?.path)
                    else reply.error("TRANSFER", "Transfert chiffré impossible. La mémoire active est conservée.", null)
                } else {
                    clean(completedFile)
                    if (source != null) removePartialDocument(uri)
                }
            }
        }
        return true
    }

    private fun copyBounded(input: InputStream, output: OutputStream) {
        val buffer = ByteArray(64 * 1024)
        var total = 0L
        while (true) {
            check(!closed && !Thread.currentThread().isInterrupted)
            val count = input.read(buffer)
            if (count < 0) break
            total += count
            require(total <= MAX_BACKUP_BYTES)
            require(directory().usableSpace > 16L * 1024 * 1024 + count)
            output.write(buffer, 0, count)
        }
        require(total > 0)
        output.flush()
    }

    private fun removePartialDocument(uri: Uri) {
        try { DocumentsContract.deleteDocument(activity.contentResolver, uri) }
        catch (_: Exception) { /* Provider may not support deletion. */ }
    }

    fun close() {
        closed = true
        val reply = pending
        pending = null
        clean(exportFile)
        exportFile = null
        reply?.error("CLOSED", "Transfert interrompu. La mémoire active est conservée.", null)
        worker.shutdownNow()
    }

    companion object {
        const val REQUEST = 9342
        const val MAX_BACKUP_BYTES = 1024L * 1024 * 1024
    }
}
