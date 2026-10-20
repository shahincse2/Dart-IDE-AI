package com.example.dart_ide

import android.content.ContentValues
import android.content.Context
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.annotation.RequiresApi
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Saves a file into the public Downloads folder through MediaStore.
 *
 * No system file picker is opened and, on Android 10 and newer, no storage
 * permission is needed: an app may always add files of its own to Downloads.
 */
class DownloadsChannel(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    init {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "saveToDownloads") {
            result.notImplemented()
            return
        }
        val fileName = call.argument<String>("fileName")
        val bytes = call.argument<ByteArray>("bytes")
        if (fileName == null || bytes == null) {
            result.error("bad_args", "fileName and bytes are required", null)
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            result.error("unsupported", "Saving to Downloads needs Android 10 or newer", null)
            return
        }
        try {
            // "application/octet-stream" keeps the name exactly as given. With a real
            // type such as text/plain, Android adds its own extension (main.dart.txt).
            val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
            val subfolder = call.argument<String>("subfolder") ?: ""
            result.success(save(fileName, bytes, mimeType, subfolder))
        } catch (e: Exception) {
            result.error("save_failed", e.message, null)
        }
    }

    /** Returns where the file ended up, for example `Download/DartLab/main.dart`. */
    @RequiresApi(Build.VERSION_CODES.Q)
    private fun save(fileName: String, bytes: ByteArray, mimeType: String, subfolder: String): String {
        val folder = if (subfolder.isEmpty()) {
            Environment.DIRECTORY_DOWNLOADS
        } else {
            "${Environment.DIRECTORY_DOWNLOADS}/$subfolder"
        }
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, fileName)
            put(MediaStore.Downloads.MIME_TYPE, mimeType)
            put(MediaStore.Downloads.RELATIVE_PATH, folder)
            put(MediaStore.Downloads.IS_PENDING, 1)
        }
        val resolver = context.contentResolver
        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            ?: throw IllegalStateException("Could not create the file")
        try {
            val stream = resolver.openOutputStream(uri)
                ?: throw IllegalStateException("Could not open the file")
            stream.use { it.write(bytes) }
            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
        } catch (e: Exception) {
            resolver.delete(uri, null, null)
            throw e
        }
        // MediaStore adds " (1)" when the name is taken: report the real name.
        val finalName = resolver
            .query(uri, arrayOf(MediaStore.MediaColumns.DISPLAY_NAME), null, null, null)
            ?.use { if (it.moveToFirst()) it.getString(0) else null }
            ?: fileName
        return "$folder/$finalName"
    }

    private companion object {
        const val CHANNEL = "dartlab/downloads"
    }
}
