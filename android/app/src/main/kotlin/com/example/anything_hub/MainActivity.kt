package com.example.anything_hub

import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Process
import android.os.StatFs
import android.provider.Settings
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val appsChannel = "anythings.hub/device_apps"
    private val filesChannel = "anythings.hub/device_files"
    private val worker = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, appsChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "selfPackage" -> result.success(packageName)
                    "hasUsageAccess" -> result.success(hasUsageAccess())
                    "openUsageAccessSettings" -> {
                        startActivity(
                            Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        )
                        result.success(null)
                    }
                    "listApps" -> {
                        val days = call.argument<Int>("days") ?: 14
                        worker.execute {
                            try {
                                val data = listApps(days)
                                runOnUiThread { result.success(data) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("SCAN_FAILED", e.message, null) }
                            }
                        }
                    }
                    "launchApp" -> {
                        val pkg = call.argument<String>("package")
                        val intent = pkg?.let { packageManager.getLaunchIntentForPackage(it) }
                        if (intent != null) {
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    }
                    "loadState" -> result.success(prefs().getString("state", null))
                    "saveState" -> {
                        prefs().edit().putString("state", call.argument<String>("json")).apply()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, filesChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasStoragePermission" -> result.success(hasAllFilesAccess())
                    "openStoragePermissionSettings" -> {
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                                val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION)
                                intent.data = Uri.parse("package:$packageName")
                                startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                            } else {
                                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                                intent.data = Uri.parse("package:$packageName")
                                startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                            }
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("SETTINGS", e.message, null)
                        }
                    }
                    "getRoots" -> {
                        worker.execute {
                            try {
                                runOnUiThread { result.success(getStorageRoots()) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("ROOTS", e.message, null) }
                            }
                        }
                    }
                    "getStorageInfo" -> {
                        val path = call.argument<String>("path") ?: ""
                        worker.execute {
                            try {
                                val info = storageInfo(path)
                                runOnUiThread { result.success(info) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("STORAGE", e.message, null) }
                            }
                        }
                    }
                    "listDirectory" -> {
                        val path = call.argument<String>("path") ?: ""
                        val showHidden = call.argument<Boolean>("showHidden") ?: false
                        worker.execute {
                            try {
                                val list = listDir(path, showHidden)
                                runOnUiThread { result.success(list) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("LIST", e.message, null) }
                            }
                        }
                    }
                    "createDirectory" -> {
                        val path = call.argument<String>("path") ?: ""
                        worker.execute {
                            try {
                                runOnUiThread { result.success(File(path).mkdirs()) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("MKDIR", e.message, null) }
                            }
                        }
                    }
                    "createFile" -> {
                        val path = call.argument<String>("path") ?: ""
                        worker.execute {
                            try {
                                val f = File(path)
                                f.parentFile?.mkdirs()
                                runOnUiThread { result.success(f.createNewFile()) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("CREATE", e.message, null) }
                            }
                        }
                    }
                    "delete" -> {
                        val path = call.argument<String>("path") ?: ""
                        worker.execute {
                            try {
                                runOnUiThread { result.success(deleteRecursive(File(path))) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("DELETE", e.message, null) }
                            }
                        }
                    }
                    "rename" -> {
                        val path = call.argument<String>("path") ?: ""
                        val newName = call.argument<String>("newName") ?: ""
                        worker.execute {
                            try {
                                val src = File(path)
                                val dest = File(src.parentFile, newName)
                                runOnUiThread { result.success(src.renameTo(dest)) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("RENAME", e.message, null) }
                            }
                        }
                    }
                    "copy" -> {
                        val src = call.argument<String>("src") ?: ""
                        val dest = call.argument<String>("dest") ?: ""
                        worker.execute {
                            try {
                                runOnUiThread { result.success(copyRecursive(File(src), File(dest))) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("COPY", e.message, null) }
                            }
                        }
                    }
                    "move" -> {
                        val src = call.argument<String>("src") ?: ""
                        val dest = call.argument<String>("dest") ?: ""
                        worker.execute {
                            try {
                                val s = File(src)
                                val d = File(dest)
                                var ok = s.renameTo(d)
                                if (!ok) {
                                    ok = copyRecursive(s, d) && deleteRecursive(s)
                                }
                                runOnUiThread { result.success(ok) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("MOVE", e.message, null) }
                            }
                        }
                    }
                    "openFile" -> {
                        val path = call.argument<String>("path") ?: ""
                        try {
                            val file = File(path)
                            if (!file.exists() || !file.isFile) {
                                result.success(false)
                                return@setMethodCallHandler
                            }
                            val uri = FileProvider.getUriForFile(
                                this, "$packageName.fileprovider", file
                            )
                            val mime = MimeTypeMap.getSingleton()
                                .getMimeTypeFromExtension(file.extension.lowercase())
                                ?: "*/*"
                            val intent = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(uri, mime)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("OPEN", e.message, null)
                        }
                    }
                    "shareFile" -> {
                        val path = call.argument<String>("path") ?: ""
                        try {
                            val file = File(path)
                            if (!file.exists() || !file.isFile) {
                                result.success(false)
                                return@setMethodCallHandler
                            }
                            val uri = FileProvider.getUriForFile(
                                this, "$packageName.fileprovider", file
                            )
                            val mime = MimeTypeMap.getSingleton()
                                .getMimeTypeFromExtension(file.extension.lowercase())
                                ?: "*/*"
                            val intent = Intent(Intent.ACTION_SEND).apply {
                                type = mime
                                putExtra(Intent.EXTRA_STREAM, uri)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                            startActivity(Intent.createChooser(intent, "Compartir").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SHARE", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun prefs() = getSharedPreferences("anythings_hub", Context.MODE_PRIVATE)

    private fun hasUsageAccess(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun hasAllFilesAccess(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Environment.isExternalStorageManager()
        } else {
            true
        }
    }

    private fun getStorageRoots(): List<Map<String, String>> {
        val roots = ArrayList<Map<String, String>>()
        val primary = Environment.getExternalStorageDirectory()
        if (primary != null && primary.exists()) {
            roots.add(mapOf("label" to "Almacenamiento interno", "path" to primary.absolutePath))
        }
        val candidates = listOf(
            "/storage/sdcard1", "/storage/extSdCard", "/mnt/sdcard", "/mnt/external_sd"
        )
        for (c in candidates) {
            val f = File(c)
            if (f.exists() && f.canRead() && f.absolutePath != primary?.absolutePath) {
                roots.add(mapOf("label" to "Tarjeta SD", "path" to f.absolutePath))
                break
            }
        }
        return roots
    }

    private fun storageInfo(path: String): Map<String, Long> {
        return try {
            val stat = StatFs(path)
            val total = stat.blockCountLong * stat.blockSizeLong
            val free = stat.availableBlocksLong * stat.blockSizeLong
            mapOf("total" to total, "free" to free)
        } catch (_: Exception) {
            mapOf("total" to 0L, "free" to 0L)
        }
    }

    private fun listDir(path: String, showHidden: Boolean): List<Map<String, Any?>> {
        val dir = File(path)
        if (!dir.exists() || !dir.isDirectory) return emptyList()
        val files = dir.listFiles() ?: return emptyList()
        val out = ArrayList<Map<String, Any?>>()
        for (f in files) {
            if (!showHidden && f.name.startsWith(".")) continue
            val ext = if (f.isFile) f.extension.lowercase() else ""
            out.add(
                mapOf(
                    "name" to f.name,
                    "path" to f.absolutePath,
                    "isDir" to f.isDirectory,
                    "size" to if (f.isFile) f.length() else 0L,
                    "modified" to f.lastModified(),
                    "ext" to ext
                )
            )
        }
        return out
    }

    private fun deleteRecursive(file: File): Boolean {
        if (file.isDirectory) {
            val children = file.listFiles()
            if (children != null) {
                for (child in children) {
                    if (!deleteRecursive(child)) return false
                }
            }
        }
        return file.delete()
    }

    private fun copyRecursive(src: File, dest: File): Boolean {
        return try {
            if (src.isDirectory) {
                if (!dest.exists() && !dest.mkdirs()) return false
                val children = src.listFiles() ?: return true
                for (child in children) {
                    if (!copyRecursive(child, File(dest, child.name))) return false
                }
                true
            } else {
                dest.parentFile?.mkdirs()
                FileInputStream(src).use { input ->
                    FileOutputStream(dest).use { output ->
                        input.copyTo(output)
                    }
                }
                true
            }
        } catch (_: Exception) {
            false
        }
    }

    private fun listApps(days: Int): List<Map<String, Any?>> {
        val pm = packageManager
        val launcher = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        @Suppress("DEPRECATION")
        val resolved = pm.queryIntentActivities(launcher, 0)
        val usageMs: Map<String, Long> = if (hasUsageAccess()) {
            val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val end = System.currentTimeMillis()
            val start = end - days * 24L * 60L * 60L * 1000L
            usm.queryAndAggregateUsageStats(start, end)
                .mapValues { it.value.totalTimeInForeground }
        } else {
            emptyMap()
        }
        val seen = HashSet<String>()
        val out = ArrayList<Map<String, Any?>>()
        for (ri in resolved) {
            val pkg = ri.activityInfo.packageName
            if (pkg == packageName) continue
            if (!seen.add(pkg)) continue
            out.add(
                mapOf(
                    "package" to pkg,
                    "name" to ri.loadLabel(pm).toString(),
                    "category" to categoryOf(ri.activityInfo.applicationInfo),
                    "usageMs" to (usageMs[pkg] ?: 0L),
                    "icon" to iconBytes(ri.loadIcon(pm))
                )
            )
        }
        return out
    }

    private fun categoryOf(info: ApplicationInfo): String {
        @Suppress("DEPRECATION")
        if ((info.flags and ApplicationInfo.FLAG_IS_GAME) != 0) return "game"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            return when (info.category) {
                ApplicationInfo.CATEGORY_GAME -> "game"
                ApplicationInfo.CATEGORY_AUDIO,
                ApplicationInfo.CATEGORY_VIDEO,
                ApplicationInfo.CATEGORY_IMAGE -> "media"
                ApplicationInfo.CATEGORY_SOCIAL -> "social"
                ApplicationInfo.CATEGORY_NEWS -> "news"
                ApplicationInfo.CATEGORY_MAPS -> "maps"
                ApplicationInfo.CATEGORY_PRODUCTIVITY -> "productivity"
                else -> "undefined"
            }
        }
        return "undefined"
    }

    private fun iconBytes(drawable: Drawable, size: Int = 96): ByteArray {
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        drawable.setBounds(0, 0, size, size)
        drawable.draw(canvas)
        val stream = ByteArrayOutputStream()
        bmp.compress(Bitmap.CompressFormat.PNG, 100, stream)
        bmp.recycle()
        return stream.toByteArray()
    }
}
