package com.asiamatrix.matrixcondo

import android.Manifest
import android.content.ContentResolver
import android.content.ContentUris
import android.content.ContentValues
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.IOException

class MainActivity : FlutterActivity() {
    private var pendingPdfSave: PendingPdfSave? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "savePdfToDownloads" -> savePdfToDownloads(call, result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun savePdfToDownloads(call: MethodCall, result: MethodChannel.Result) {
        val bytes = call.argument<ByteArray>("bytes")
        val rawName = call.argument<String>("fileName")
        val mimeType = call.argument<String>("mimeType") ?: "application/pdf"

        if (bytes == null || bytes.isEmpty()) {
            result.error("invalid_receipt", "The receipt file is empty.", null)
            return
        }
        if (rawName.isNullOrBlank()) {
            result.error("invalid_receipt", "The receipt file name is missing.", null)
            return
        }

        val fileName = sanitizeFileName(rawName)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                result.success(saveWithMediaStore(bytes, fileName, mimeType))
            } catch (e: Exception) {
                result.error("save_failed", e.message ?: "Could not save the receipt.", null)
            }
            return
        }

        if (checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            try {
                result.success(saveToLegacyDownloads(bytes, fileName, mimeType))
            } catch (e: Exception) {
                result.error("save_failed", e.message ?: "Could not save the receipt.", null)
            }
            return
        }

        if (pendingPdfSave != null) {
            result.error("save_in_progress", "Another receipt is being saved.", null)
            return
        }
        pendingPdfSave = PendingPdfSave(bytes, fileName, mimeType, result)
        requestPermissions(
            arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
            REQUEST_WRITE_STORAGE,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_WRITE_STORAGE) return

        val pending = pendingPdfSave ?: return
        pendingPdfSave = null
        if (grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        ) {
            try {
                pending.result.success(
                    saveToLegacyDownloads(pending.bytes, pending.fileName, pending.mimeType),
                )
            } catch (e: Exception) {
                pending.result.error(
                    "save_failed",
                    e.message ?: "Could not save the receipt.",
                    null,
                )
            }
        } else {
            pending.result.error(
                "permission_denied",
                "Storage permission is required to save the receipt.",
                null,
            )
        }
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    private fun saveWithMediaStore(
        bytes: ByteArray,
        fileName: String,
        mimeType: String,
    ): String {
        val resolver = contentResolver
        val collection = MediaStore.Downloads.EXTERNAL_CONTENT_URI
        val existing = runCatching { findOwnedDownload(collection, fileName) }.getOrNull()
        val uri: Uri = if (existing != null) {
            resolver.update(
                existing,
                ContentValues().apply {
                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                },
                null,
                null,
            )
            existing
        } else {
            resolver.insert(
                collection,
                ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                    put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                    put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                },
            ) ?: throw IOException("Downloads is unavailable.")
        }

        try {
            resolver.openOutputStream(uri, "wt")?.use { out ->
                out.write(bytes)
                out.flush()
            } ?: throw IOException("Could not open the receipt file.")

            val written = querySize(resolver, uri)
            if (written != null && written > 0 && written != bytes.size.toLong()) {
                throw IOException("The receipt was not fully written.")
            }

            resolver.update(
                uri,
                ContentValues().apply {
                    put(MediaStore.MediaColumns.IS_PENDING, 0)
                },
                null,
                null,
            )
            return "Downloads/$fileName"
        } catch (e: Exception) {
            runCatching { resolver.delete(uri, null, null) }
            throw e
        }
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    private fun findOwnedDownload(collection: Uri, fileName: String): Uri? {
        val projection = arrayOf(
            MediaStore.MediaColumns._ID,
            MediaStore.MediaColumns.OWNER_PACKAGE_NAME,
        )
        val selection =
            "${MediaStore.MediaColumns.DISPLAY_NAME} = ? AND " +
                "(${MediaStore.MediaColumns.RELATIVE_PATH} = ? OR " +
                "${MediaStore.MediaColumns.RELATIVE_PATH} = ?)"
        val args = arrayOf(
            fileName,
            Environment.DIRECTORY_DOWNLOADS,
            "${Environment.DIRECTORY_DOWNLOADS}/",
        )
        contentResolver.query(collection, projection, selection, args, null)?.use { cursor ->
            while (cursor.moveToNext()) {
                val owner = cursor.getString(1)
                if (owner == null || owner == packageName) {
                    return ContentUris.withAppendedId(collection, cursor.getLong(0))
                }
            }
        }
        return null
    }

    private fun querySize(resolver: ContentResolver, uri: Uri): Long? {
        resolver.query(
            uri,
            arrayOf(MediaStore.MediaColumns.SIZE),
            null,
            null,
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst() && !cursor.isNull(0)) {
                return cursor.getLong(0)
            }
        }
        return null
    }

    private fun saveToLegacyDownloads(
        bytes: ByteArray,
        fileName: String,
        mimeType: String,
    ): String {
        val directory = Environment.getExternalStoragePublicDirectory(
            Environment.DIRECTORY_DOWNLOADS,
        )
        if (!directory.exists() && !directory.mkdirs()) {
            throw IOException("Downloads is unavailable.")
        }
        val file = File(directory, fileName)
        val temp = File(directory, "$fileName.part")
        try {
            FileOutputStream(temp).use { out ->
                out.write(bytes)
                out.flush()
                out.fd.sync()
            }
            if (temp.length() != bytes.size.toLong()) {
                throw IOException("The receipt was not fully written.")
            }
            if (file.exists() && !file.delete()) {
                throw IOException("Could not replace the existing receipt.")
            }
            if (!temp.renameTo(file)) {
                temp.copyTo(file, overwrite = true)
                temp.delete()
            }
        } catch (e: Exception) {
            temp.delete()
            throw e
        }
        if (file.length() != bytes.size.toLong()) {
            file.delete()
            throw IOException("The receipt was not fully written.")
        }
        MediaScannerConnection.scanFile(
            this,
            arrayOf(file.absolutePath),
            arrayOf(mimeType),
            null,
        )
        return "Downloads/$fileName"
    }

    private fun sanitizeFileName(name: String): String {
        val cleaned = name.replace(Regex("[^A-Za-z0-9._-]"), "_").trim('_', '.')
        val safe = cleaned.ifEmpty { "Receipt" }
        return if (safe.lowercase().endsWith(".pdf")) safe else "$safe.pdf"
    }

    private data class PendingPdfSave(
        val bytes: ByteArray,
        val fileName: String,
        val mimeType: String,
        val result: MethodChannel.Result,
    )

    companion object {
        private const val CHANNEL = "com.asiamatrix.matrixcondo/receipts"
        private const val REQUEST_WRITE_STORAGE = 41021
    }
}
