package com.algorisesoft.dartide

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Lets the user pick a file with Android's own "Choose a file" list
 * (ACTION_GET_CONTENT inside a chooser). Every app that offers files can show
 * up in it, for example Samsung's My Files. No permission is needed.
 *
 * This is used instead of the Google Files picker, which fails to list any
 * folder on some phones.
 */
class ImportChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private var pending: MethodChannel.Result? = null

    init {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "pickFile") {
            result.notImplemented()
            return
        }
        if (pending != null) {
            result.error("busy", "A file is already being picked", null)
            return
        }
        pending = result
        val getContent = Intent(Intent.ACTION_GET_CONTENT).apply {
            type = "*/*"
            addCategory(Intent.CATEGORY_OPENABLE)
        }
        activity.startActivityForResult(
            Intent.createChooser(getContent, "Choose a file"),
            REQUEST_CODE,
        )
    }

    /** Called by MainActivity. Returns true when the result was for this channel. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val result = pending ?: return true
        pending = null

        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null) // cancelled
            return true
        }
        try {
            result.success(read(uri))
        } catch (e: Exception) {
            result.error("read_failed", e.message, null)
        }
        return true
    }

    private fun read(uri: Uri): Map<String, Any> {
        val resolver = activity.contentResolver
        val name = resolver
            .query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { if (it.moveToFirst()) it.getString(0) else null }
            ?: uri.lastPathSegment
            ?: "imported.dart"
        val bytes = resolver.openInputStream(uri)?.use { it.readBytes() }
            ?: throw IllegalStateException("Could not open the file")
        return mapOf("name" to name, "bytes" to bytes)
    }

    private companion object {
        const val CHANNEL = "dartlab/import"
        const val REQUEST_CODE = 7421
    }
}
