package com.example.project1

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // بيحفظ نسخة من الملف في مجلد "التنزيلات" العام في الموبايل
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "project1/downloads")
            .setMethodCallHandler { call, result ->
                if (call.method != "saveToDownloads") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val path = call.argument<String>("path")
                val name = call.argument<String>("name")
                val mime = call.argument<String>("mime") ?: "application/octet-stream"
                if (path == null || name == null) {
                    result.error("ARGS", "path/name missing", null)
                    return@setMethodCallHandler
                }
                try {
                    result.success(saveToDownloads(File(path), name, mime))
                } catch (e: Exception) {
                    result.error("SAVE_FAILED", e.message, null)
                }
            }
    }

    private fun saveToDownloads(src: File, name: String, mime: String): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // أندرويد 10+: MediaStore من غير أي صلاحيات
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, name)
                put(MediaStore.Downloads.MIME_TYPE, mime)
                put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val resolver = contentResolver
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw Exception("insert failed")
            try {
                val out = resolver.openOutputStream(uri) ?: throw Exception("stream failed")
                out.use { o -> src.inputStream().use { it.copyTo(o) } }
                values.clear()
                values.put(MediaStore.Downloads.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
            } catch (e: Exception) {
                resolver.delete(uri, null, null)
                throw e
            }
            return uri.toString()
        } else {
            // أندرويد 9 وأقدم: كتابة مباشرة (محتاجة صلاحية التخزين)
            val dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            if (!dir.exists()) dir.mkdirs()
            var target = File(dir, name)
            if (target.exists()) {
                val dot = name.lastIndexOf('.')
                val base = if (dot > 0) name.substring(0, dot) else name
                val ext = if (dot > 0) name.substring(dot) else ""
                target = File(dir, base + "_" + System.currentTimeMillis() + ext)
            }
            src.copyTo(target, overwrite = false)
            return target.absolutePath
        }
    }
}