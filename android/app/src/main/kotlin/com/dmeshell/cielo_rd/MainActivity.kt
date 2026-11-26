package com.dmeshell.cielo_rd

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.util.concurrent.Executors

/** FlutterFragmentActivity: requisito de local_auth. */
class MainActivity : FlutterFragmentActivity() {
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var pendingPick: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler(::onCall)
    }

    private fun onCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "createDocument" -> pick(
                result,
                Intent(Intent.ACTION_CREATE_DOCUMENT)
                    .addCategory(Intent.CATEGORY_OPENABLE)
                    .setType(call.argument<String>("mimeType"))
                    .putExtra(Intent.EXTRA_TITLE, call.argument<String>("name")),
                REQUEST_CREATE,
            )
            "openDocument" -> pick(
                result,
                Intent(Intent.ACTION_OPEN_DOCUMENT)
                    .addCategory(Intent.CATEGORY_OPENABLE)
                    .setType("*/*")
                    .putExtra(
                        Intent.EXTRA_MIME_TYPES,
                        call.argument<List<String>>("mimeTypes")!!.toTypedArray(),
                    ),
                REQUEST_OPEN,
            )
            "writeDocument" -> inBackground(result) {
                writeDocument(privateFile(call), documentUri(call))
            }
            "readDocument" -> inBackground(result) {
                readDocument(
                    documentUri(call),
                    privateFile(call),
                    call.argument<Number>("maxBytes")!!.toLong(),
                )
            }
            "deleteDocument" -> inBackground(result) {
                deleteDocument(documentUri(call), call.argument<Boolean>("onlyIfEmpty")!!)
            }
            "clearPreferences" -> inBackground(result) { clearPreferences() }
            "setRecentsPrivacy" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    setRecentsScreenshotEnabled(!call.argument<Boolean>("hidden")!!)
                }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun pick(result: MethodChannel.Result, intent: Intent, request: Int) {
        if (pendingPick != null) {
            result.error("busy", "Ya hay un selector abierto.", null)
            return
        }
        pendingPick = result
        try {
            @Suppress("DEPRECATION")
            startActivityForResult(intent, request)
        } catch (error: ActivityNotFoundException) {
            pendingPick = null
            result.error("unavailable", error.message, null)
        }
    }

    @Deprecated("Deprecated in Java")
    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == REQUEST_CREATE || requestCode == REQUEST_OPEN) {
            val uri = if (resultCode == Activity.RESULT_OK) data?.data else null
            pendingPick?.success(uri?.toString())
            pendingPick = null
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    /** Solo se aceptan archivos dentro del espacio privado de la app. */
    private fun privateFile(call: MethodCall): File {
        val file = File(call.argument<String>("path")!!).canonicalFile
        val root = File(applicationInfo.dataDir).canonicalFile
        if (!file.startsWith(root)) throw IOException("Ruta no privada.")
        return file
    }

    private fun documentUri(call: MethodCall): Uri {
        val uri = Uri.parse(call.argument<String>("uri")!!)
        if (uri.scheme != "content") throw IOException("URI no admitida.")
        return uri
    }

    private fun writeDocument(source: File, target: Uri): Long {
        // "wt" trunca: al sobrescribir no quedan restos del archivo anterior.
        val output = contentResolver.openOutputStream(target, "wt")
            ?: throw IOException("No se pudo abrir el destino.")
        return output.use { out ->
            source.inputStream().use { it.copyTo(out, BUFFER) }.also { out.flush() }
        }
    }

    private fun readDocument(source: Uri, target: File, maxBytes: Long): Long {
        val input = contentResolver.openInputStream(source)
            ?: throw IOException("No se pudo abrir el origen.")
        var total = 0L
        input.use { stream ->
            target.outputStream().use { out ->
                val buffer = ByteArray(BUFFER)
                while (true) {
                    val read = stream.read(buffer)
                    if (read < 0) break
                    total += read
                    if (total > maxBytes) throw TooLarge()
                    out.write(buffer, 0, read)
                }
            }
        }
        return total
    }

    private fun deleteDocument(uri: Uri, onlyIfEmpty: Boolean) {
        if (onlyIfEmpty) {
            val size = contentResolver.openFileDescriptor(uri, "r")?.use { it.statSize } ?: -1L
            if (size != 0L) return
        }
        DocumentsContract.deleteDocument(contentResolver, uri)
    }

    /** Preferencias que guardan los plugins (p. ej. image_picker). */
    private fun clearPreferences() {
        val directory = File(applicationInfo.dataDir, "shared_prefs")
        for (file in directory.listFiles().orEmpty()) {
            if (!file.name.endsWith(".xml")) continue
            val name = file.name.removeSuffix(".xml")
            if (!getSharedPreferences(name, MODE_PRIVATE).edit().clear().commit()) {
                throw IOException("No se pudo limpiar $name.")
            }
            deleteSharedPreferences(name)
        }
    }

    private fun inBackground(result: MethodChannel.Result, work: () -> Any?) {
        worker.execute {
            try {
                val value = work().takeUnless { it is Unit }
                main.post { result.success(value) }
            } catch (error: TooLarge) {
                main.post { result.error("too_large", null, null) }
            } catch (error: Exception) {
                main.post { result.error("io", error.message, null) }
            }
        }
    }

    override fun onDestroy() {
        worker.shutdown()
        super.onDestroy()
    }

    private class TooLarge : IOException()

    private companion object {
        const val CHANNEL = "com.dmeshell.cielo_rd/platform"
        const val REQUEST_CREATE = 0x4301
        const val REQUEST_OPEN = 0x4302
        const val BUFFER = 64 * 1024
    }
}
