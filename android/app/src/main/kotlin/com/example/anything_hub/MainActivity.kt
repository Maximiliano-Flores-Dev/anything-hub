package com.example.anything_hub

import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.os.Bundle
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
    private val perfChannel = "anythings.hub/performance"
    private val worker = Executors.newSingleThreadExecutor()

    @Volatile
    private var pendingIncomingApk: Map<String, Any?>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIncomingApk(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIncomingApk(intent)
    }

    private fun handleIncomingApk(intent: Intent?) {
        if (intent == null) return
        val action = intent.action ?: return
        val isApk = action == Intent.ACTION_VIEW || action == Intent.ACTION_SEND
        if (!isApk) return

        val caller = callingPackage
        val uri: Uri? = when (action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND -> if (Build.VERSION.SDK_INT >= 33) {
                intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra(Intent.EXTRA_STREAM)
            }
            else -> null
        }
        if (uri == null) return

        val mime = intent.type ?: contentResolver.getType(uri) ?: ""
        val pathHint = uri.toString().lowercase()
        val looksLikeApk = mime.contains("package-archive") ||
            mime == "application/octet-stream" ||
            pathHint.endsWith(".apk")
        if (!looksLikeApk) return

        worker.execute {
            try {
                val dest = File(cacheDir, "incoming_apk/${System.currentTimeMillis()}.apk")
                dest.parentFile?.mkdirs()
                contentResolver.openInputStream(uri)?.use { input ->
                    FileOutputStream(dest).use { output -> input.copyTo(output) }
                }
                if (!dest.exists() || dest.length() == 0L) return@execute

                val payload = mapOf(
                    "cacheRelativePath" to "incoming_apk/${dest.name}",
                    "fileName" to dest.name,
                    "sizeBytes" to dest.length(),
                    "callerPackage" to (caller ?: ""),
                )
                pendingIncomingApk = payload
            } catch (_: Exception) {
            }
        }
    }

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
                    "listInstalledPackages" -> {
                        worker.execute {
                            try {
                                val pkgs = listInstalledPackages()
                                runOnUiThread { result.success(pkgs) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("PACKAGES", e.message, null) }
                            }
                        }
                    }
                    "launchAppWithPath" -> {
                        val pkg = call.argument<String>("package")
                        val path = call.argument<String>("path")
                        if (pkg.isNullOrEmpty()) {
                            result.success(false)
                        } else {
                            result.success(launchAppWithPath(pkg, path))
                        }
                    }
                    "termuxRunCommand" -> {
                        val command = call.argument<String>("command") ?: ""
                        val workdir = call.argument<String>("workdir") ?: ""
                        val background = call.argument<Boolean>("background") ?: false
                        result.success(termuxRunCommand(command, workdir, background))
                    }
                    "loadState" -> result.success(prefs().getString("state", null))
                    "saveState" -> {
                        prefs().edit().putString("state", call.argument<String>("json")).apply()
                        result.success(null)
                    }
                    "openAppSettings" -> {
                        val pkg = call.argument<String>("package")
                        if (pkg.isNullOrEmpty()) {
                            result.success(false)
                        } else {
                            try {
                                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                    data = Uri.parse("package:$pkg")
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(intent)
                                result.success(true)
                            } catch (e: Exception) {
                                result.error("SETTINGS", e.message, null)
                            }
                        }
                    }
                    "requestUninstall" -> {
                        val pkg = call.argument<String>("package")
                        if (pkg.isNullOrEmpty()) {
                            result.success(false)
                        } else {
                            try {
                                val intent = Intent(Intent.ACTION_DELETE).apply {
                                    data = Uri.parse("package:$pkg")
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(intent)
                                result.success(true)
                            } catch (e: Exception) {
                                result.error("UNINSTALL", e.message, null)
                            }
                        }
                    }
                    "installApkFromCache" -> {
                        val relative = call.argument<String>("cacheRelativePath")
                        if (relative.isNullOrEmpty()) {
                            result.error("PATH", "cacheRelativePath requerido", null)
                        } else {
                            worker.execute {
                                try {
                                    val file = File(cacheDir, relative)
                                    if (!file.exists()) {
                                        runOnUiThread {
                                            result.error("NOT_FOUND", "APK no encontrado en caché", null)
                                        }
                                        return@execute
                                    }
                                    val uri = FileProvider.getUriForFile(
                                        this, "$packageName.fileprovider", file
                                    )
                                    val intent = Intent(Intent.ACTION_VIEW).apply {
                                        setDataAndType(uri, "application/vnd.android.package-archive")
                                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    }
                                    runOnUiThread {
                                        startActivity(intent)
                                        result.success(true)
                                    }
                                } catch (e: Exception) {
                                    runOnUiThread { result.error("INSTALL", e.message, null) }
                                }
                            }
                        }
                    }
                    "inspectApk" -> {
                        val relative = call.argument<String>("cacheRelativePath")
                        if (relative.isNullOrEmpty()) {
                            result.error("PATH", "cacheRelativePath requerido", null)
                        } else {
                            worker.execute {
                                try {
                                    val data = inspectApkFromCache(relative)
                                    runOnUiThread { result.success(data) }
                                } catch (e: Exception) {
                                    runOnUiThread { result.error("INSPECT", e.message, null) }
                                }
                            }
                        }
                    }
                    "inspectApkPath" -> {
                        val absolute = call.argument<String>("path")
                        if (absolute.isNullOrEmpty()) {
                            result.error("PATH", "path requerido", null)
                        } else {
                            worker.execute {
                                try {
                                    val data = inspectApkAtPath(absolute)
                                    runOnUiThread { result.success(data) }
                                } catch (e: Exception) {
                                    runOnUiThread { result.error("INSPECT", e.message, null) }
                                }
                            }
                        }
                    }
                    "consumePendingIncomingApk" -> {
                        val pending = pendingIncomingApk
                        pendingIncomingApk = null
                        result.success(pending)
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
                                runOnUiThread { result.success(storageInfo(path)) }
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
                                runOnUiThread { result.success(listDir(path, showHidden)) }
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
                                if (!ok) ok = copyRecursive(s, d) && deleteRecursive(s)
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
                            val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
                            val mime = MimeTypeMap.getSingleton()
                                .getMimeTypeFromExtension(file.extension.lowercase()) ?: "*/*"
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
                            val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
                            val mime = MimeTypeMap.getSingleton()
                                .getMimeTypeFromExtension(file.extension.lowercase()) ?: "*/*"
                            val intent = Intent(Intent.ACTION_SEND).apply {
                                type = mime
                                putExtra(Intent.EXTRA_STREAM, uri)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                            startActivity(Intent.createChooser(intent, "Compartir"))
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SHARE", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, perfChannel)
            .setMethodCallHandler { call, result ->
                try {
                    PerformanceBridge.handle(this, call, result)
                } catch (e: Exception) {
                    result.error("PERF", e.message, null)
                }
            }
    }


    private fun prefs() = getSharedPreferences("anythings_hub", Context.MODE_PRIVATE)

    private fun hasUsageAccess(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun hasAllFilesAccess(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) Environment.isExternalStorageManager() else true
    }

    private fun getStorageRoots(): List<Map<String, Any?>> {
        val roots = mutableListOf<Map<String, Any?>>()
        val primary = Environment.getExternalStorageDirectory()
        if (primary != null && primary.exists()) {
            roots.add(mapOf("path" to primary.absolutePath, "label" to "Almacenamiento interno", "isPrimary" to true))
        }
        val dirs = getExternalFilesDirs(null)
        for (d in dirs) {
            if (d == null) continue
            var root = d
            while (root.parentFile != null && root.parentFile!!.canRead()) {
                val parent = root.parentFile!!
                if (parent.absolutePath == "/" || parent.absolutePath == "/storage") break
                root = parent
            }
            val path = root.absolutePath
            if (roots.none { it["path"] == path }) {
                roots.add(mapOf("path" to path, "label" to root.name.ifEmpty { path }, "isPrimary" to false))
            }
        }
        return roots
    }

    private fun storageInfo(path: String): Map<String, Any?> {
        val stat = StatFs(path)
        val total = stat.totalBytes
        val free = stat.availableBytes
        return mapOf("totalBytes" to total, "freeBytes" to free, "usedBytes" to (total - free))
    }

    private fun listDir(path: String, showHidden: Boolean): List<Map<String, Any?>> {
        val dir = File(path)
        if (!dir.exists() || !dir.isDirectory) return emptyList()
        val files = dir.listFiles() ?: return emptyList()
        return files
            .filter { showHidden || !it.name.startsWith(".") }
            .sortedWith(compareBy({ !it.isDirectory }, { it.name.lowercase() }))
            .map { f ->
                mapOf(
                    "name" to f.name,
                    "path" to f.absolutePath,
                    "isDir" to f.isDirectory,
                    "size" to if (f.isFile) f.length() else 0L,
                    "modified" to f.lastModified(),
                    "ext" to if (f.isFile) f.extension.lowercase() else "",
                )
            }
    }

    private fun deleteRecursive(f: File): Boolean {
        var ok = true
        if (f.isDirectory) {
            f.listFiles()?.forEach { child ->
                if (!deleteRecursive(child)) ok = false
            }
        }
        if (!f.delete()) ok = false
        return ok
    }

    private fun copyRecursive(src: File, dest: File): Boolean {
        return try {
            if (src.canonicalPath == dest.canonicalPath) return true
            if (src.isDirectory && dest.canonicalPath.startsWith(src.canonicalPath + File.separator)) {
                return false
            }
            if (src.isDirectory) {
                if (!dest.exists() && !dest.mkdirs()) return false
                var ok = true
                src.listFiles()?.forEach { child ->
                    if (!copyRecursive(child, File(dest, child.name))) ok = false
                }
                ok
            } else {
                dest.parentFile?.mkdirs()
                FileInputStream(src).use { input ->
                    FileOutputStream(dest).use { output -> input.copyTo(output) }
                }
                true
            }
        } catch (_: Exception) {
            false
        }
    }

    private fun listApps(days: Int): List<Map<String, Any?>> {
        val pm = packageManager
        val packages = pm.getInstalledApplications(0)
        val usageMap = mutableMapOf<String, Long>()
        if (hasUsageAccess()) {
            try {
                val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
                val end = System.currentTimeMillis()
                val start = end - days * 24L * 60 * 60 * 1000
                usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, start, end)?.forEach { s ->
                    usageMap[s.packageName] = (usageMap[s.packageName] ?: 0L) + s.totalTimeInForeground
                }
            } catch (_: Exception) {}
        }
        return packages.mapNotNull { ai ->
            try {
                val label = pm.getApplicationLabel(ai).toString()
                val iconBytes = iconBytes(pm.getApplicationIcon(ai))
                val mins = ((usageMap[ai.packageName] ?: 0L) / 60000L).toInt()
                mapOf(
                    "name" to label,
                    "packageName" to ai.packageName,
                    "icon" to iconBytes,
                    "usageMinutes" to mins,
                    "category" to categoryOf(ai),
                    "isSystem" to ((ai.flags and ApplicationInfo.FLAG_SYSTEM) != 0),
                )
            } catch (_: Exception) {
                null
            }
        }
    }

    private fun categoryOf(ai: ApplicationInfo): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            return when (ai.category) {
                ApplicationInfo.CATEGORY_GAME -> "games"
                ApplicationInfo.CATEGORY_AUDIO -> "media"
                ApplicationInfo.CATEGORY_VIDEO -> "media"
                ApplicationInfo.CATEGORY_IMAGE -> "media"
                ApplicationInfo.CATEGORY_SOCIAL -> "social"
                ApplicationInfo.CATEGORY_NEWS -> "news"
                ApplicationInfo.CATEGORY_MAPS -> "maps"
                ApplicationInfo.CATEGORY_PRODUCTIVITY -> "productivity"
                else -> "other"
            }
        }
        return "other"
    }

    private fun iconBytes(drawable: Drawable, size: Int = 96): ByteArray {
        val w = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else size
        val h = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else size
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)
        val stream = ByteArrayOutputStream()
        bmp.compress(Bitmap.CompressFormat.PNG, 90, stream)
        return stream.toByteArray()
    }

    private fun listInstalledPackages(): List<String> {
        return packageManager.getInstalledApplications(0).map { it.packageName }
    }

    private fun launchAppWithPath(pkg: String, path: String?): Boolean {
        return try {
            var targetPath = path
            if (!path.isNullOrEmpty()) {
                val file = File(path)
                if (file.isDirectory) {
                    val md = File(file, "project.md")
                    if (md.exists() && md.isFile) targetPath = md.absolutePath
                }
            }
            if (!targetPath.isNullOrEmpty()) {
                val file = File(targetPath)
                if (file.exists() && file.isFile) {
                    val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
                    val intent = Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(uri, "text/markdown")
                        setPackage(pkg)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                    return true
                }
            }
            val launch = packageManager.getLaunchIntentForPackage(pkg)
            if (launch != null) {
                startActivity(launch)
                true
            } else false
        } catch (e: Exception) {
            false
        }
    }

    private fun inspectApkFromCache(relative: String): Map<String, Any?> {
        val file = File(cacheDir, relative)
        if (!file.exists() || !file.isFile) throw IllegalArgumentException("APK no encontrado: $relative")
        return inspectApkAtPath(file.absolutePath)
    }

    private fun inspectApkAtPath(path: String): Map<String, Any?> {
        val file = File(path)
        if (!file.exists() || !file.isFile) throw IllegalArgumentException("APK no encontrado: $path")
        @Suppress("DEPRECATION")
        val flags = PackageManager.GET_PERMISSIONS
        val pi = packageManager.getPackageArchiveInfo(path, flags)
            ?: throw IllegalStateException("No se pudo parsear el APK")

        val ai = pi.applicationInfo
        if (ai != null) {
            ai.sourceDir = path
            ai.publicSourceDir = path
        }

        val label = if (ai != null) {
            try { packageManager.getApplicationLabel(ai).toString() }
            catch (_: Exception) { pi.packageName ?: file.name }
        } else pi.packageName ?: file.name

        val perms = pi.requestedPermissions?.toList() ?: emptyList()

        var icon: ByteArray? = null
        if (ai != null) {
            try { icon = iconBytes(packageManager.getApplicationIcon(ai), 96) }
            catch (_: Exception) {}
        }

        return mapOf(
            "packageName" to (pi.packageName ?: ""),
            "appLabel" to label,
            "versionName" to (pi.versionName ?: ""),
            "versionCode" to if (Build.VERSION.SDK_INT >= 28) pi.longVersionCode else {
                @Suppress("DEPRECATION") pi.versionCode.toLong()
            },
            "permissions" to perms,
            "fileName" to file.name,
            "sizeBytes" to file.length(),
            "icon" to icon,
        )
    }

    private fun termuxRunCommand(command: String, workdir: String, background: Boolean): Boolean {
        return try {
            val intent = Intent().apply {
                setClassName("com.termux", "com.termux.app.RunCommandService")
                action = "com.termux.RUN_COMMAND"
                putExtra("com.termux.RUN_COMMAND_PATH", "/data/data/com.termux/files/usr/bin/bash")
                putExtra("com.termux.RUN_COMMAND_ARGUMENTS", arrayOf("-c", command))
                if (workdir.isNotEmpty()) putExtra("com.termux.RUN_COMMAND_WORKDIR", workdir)
                putExtra("com.termux.RUN_COMMAND_BACKGROUND", background)
                putExtra("com.termux.RUN_COMMAND_SESSION_ACTION", "0")
            }
            startService(intent)
            true
        } catch (e: Exception) {
            false
        }
    }
}
