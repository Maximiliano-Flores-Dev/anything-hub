package com.anything.hub

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.StatFs
import android.provider.Settings
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream

/**
 * Canal anythings.hub/device_files: listado, CRUD, open/share, roots/storage.
 * Paths validados con PathSecurity (null-byte / rename seguro).
 */
object DeviceFilesBridge {

    fun handle(activity: MainActivity, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasStoragePermission" -> result.success(hasAllFilesAccess())

            "openStoragePermissionSettings" -> {
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION)
                        intent.data = Uri.parse("package:${activity.packageName}")
                        activity.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    } else {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                        intent.data = Uri.parse("package:${activity.packageName}")
                        activity.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    }
                    result.success(null)
                } catch (e: Exception) {
                    result.error("SETTINGS", e.message, null)
                }
            }

            "getRoots" -> {
                activity.worker.execute {
                    try {
                        activity.runOnUiThread { result.success(getStorageRoots()) }
                    } catch (e: Exception) {
                        activity.runOnUiThread {
                            result.error("ROOTS", e.message, null)
                        }
                    }
                }
            }

            "getStorageInfo" -> {
                val path = try {
                    PathSecurity.requireValidPath(call.argument<String>("path") ?: "")
                } catch (e: Exception) {
                    result.error("PATH", e.message, null)
                    return
                }
                activity.worker.execute {
                    try {
                        val info = storageInfo(path)
                        activity.runOnUiThread { result.success(info) }
                    } catch (e: Exception) {
                        activity.runOnUiThread {
                            result.error("STORAGE", e.message, null)
                        }
                    }
                }
            }

            "listDirectory" -> {
                val path = try {
                    PathSecurity.requireValidPath(call.argument<String>("path") ?: "")
                } catch (e: Exception) {
                    result.error("PATH", e.message, null)
                    return
                }
                val showHidden = call.argument<Boolean>("showHidden") ?: false
                activity.worker.execute {
                    try {
                        val list = listDir(path, showHidden)
                        activity.runOnUiThread { result.success(list) }
                    } catch (e: Exception) {
                        activity.runOnUiThread {
                            result.error("LIST", e.message, null)
                        }
                    }
                }
            }

            "createDirectory" -> {
                val path = try {
                    PathSecurity.requireValidPath(call.argument<String>("path") ?: "")
                } catch (e: Exception) {
                    result.error("PATH", e.message, null)
                    return
                }
                activity.worker.execute {
                    try {
                        activity.runOnUiThread { result.success(File(path).mkdirs()) }
                    } catch (e: Exception) {
                        activity.runOnUiThread {
                            result.error("MKDIR", e.message, null)
                        }
                    }
                }
            }

            "createFile" -> {
                val path = try {
                    PathSecurity.requireValidPath(call.argument<String>("path") ?: "")
                } catch (e: Exception) {
                    result.error("PATH", e.message, null)
                    return
                }
                activity.worker.execute {
                    try {
                        val f = File(path)
                        f.parentFile?.mkdirs()
                        activity.runOnUiThread { result.success(f.createNewFile()) }
                    } catch (e: Exception) {
                        activity.runOnUiThread {
                            result.error("CREATE", e.message, null)
                        }
                    }
                }
            }

            "delete" -> {
                val path = try {
                    PathSecurity.requireValidPath(call.argument<String>("path") ?: "")
                } catch (e: Exception) {
                    result.error("PATH", e.message, null)
                    return
                }
                activity.worker.execute {
                    try {
                        activity.runOnUiThread {
                            result.success(deleteRecursive(File(path)))
                        }
                    } catch (e: Exception) {
                        activity.runOnUiThread {
                            result.error("DELETE", e.message, null)
                        }
                    }
                }
            }

            "rename" -> {
                val path = try {
                    PathSecurity.requireValidPath(call.argument<String>("path") ?: "")
                } catch (e: Exception) {
                    result.error("PATH", e.message, null)
                    return
                }
                val newName = try {
                    PathSecurity.requireSafeFileName(call.argument<String>("newName") ?: "")
                } catch (e: Exception) {
                    result.error("NAME", e.message, null)
                    return
                }
                activity.worker.execute {
                    try {
                        val src = File(path)
                        val dest = File(src.parentFile, newName)
                        activity.runOnUiThread { result.success(src.renameTo(dest)) }
                    } catch (e: Exception) {
                        activity.runOnUiThread {
                            result.error("RENAME", e.message, null)
                        }
                    }
                }
            }

            "copy" -> {
                val src = try {
                    PathSecurity.requireValidPath(call.argument<String>("src") ?: "", "src")
                } catch (e: Exception) {
                    result.error("PATH", e.message, null)
                    return
                }
                val dest = try {
                    PathSecurity.requireValidPath(call.argument<String>("dest") ?: "", "dest")
                } catch (e: Exception) {
                    result.error("PATH", e.message, null)
                    return
                }
                activity.worker.execute {
                    try {
                        activity.runOnUiThread {
                            result.success(copyRecursive(File(src), File(dest)))
                        }
                    } catch (e: Exception) {
                        activity.runOnUiThread {
                            result.error("COPY", e.message, null)
                        }
                    }
                }
            }

            "move" -> {
                val src = try {
                    PathSecurity.requireValidPath(call.argument<String>("src") ?: "", "src")
                } catch (e: Exception) {
                    result.error("PATH", e.message, null)
                    return
                }
                val dest = try {
                    PathSecurity.requireValidPath(call.argument<String>("dest") ?: "", "dest")
                } catch (e: Exception) {
                    result.error("PATH", e.message, null)
                    return
                }
                activity.worker.execute {
                    try {
                        val s = File(src)
                        val d = File(dest)
                        var ok = s.renameTo(d)
                        if (!ok) {
                            ok = copyRecursive(s, d) && deleteRecursive(s)
                        }
                        activity.runOnUiThread { result.success(ok) }
                    } catch (e: Exception) {
                        activity.runOnUiThread {
                            result.error("MOVE", e.message, null)
                        }
                    }
                }
            }

            "openFile" -> {
                val path = try {
                    PathSecurity.requireValidPath(call.argument<String>("path") ?: "")
                } catch (e: Exception) {
                    result.error("PATH", e.message, null)
                    return
                }
                try {
                    val file = File(path)
                    if (!file.exists() || !file.isFile) {
                        result.success(false)
                        return
                    }
                    val uri = FileProvider.getUriForFile(
                        activity,
                        "${activity.packageName}.fileprovider",
                        file
                    )
                    val mime = MimeTypeMap.getSingleton()
                        .getMimeTypeFromExtension(file.extension.lowercase())
                        ?: "*/*"
                    val intent = Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(uri, mime)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    activity.startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("OPEN", e.message, null)
                }
            }

            "shareFile" -> {
                val path = try {
                    PathSecurity.requireValidPath(call.argument<String>("path") ?: "")
                } catch (e: Exception) {
                    result.error("PATH", e.message, null)
                    return
                }
                try {
                    val file = File(path)
                    if (!file.exists() || !file.isFile) {
                        result.success(false)
                        return
                    }
                    val uri = FileProvider.getUriForFile(
                        activity,
                        "${activity.packageName}.fileprovider",
                        file
                    )
                    val mime = MimeTypeMap.getSingleton()
                        .getMimeTypeFromExtension(file.extension.lowercase())
                        ?: "*/*"
                    val intent = Intent(Intent.ACTION_SEND).apply {
                        type = mime
                        putExtra(Intent.EXTRA_STREAM, uri)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    activity.startActivity(
                        Intent.createChooser(intent, "Compartir")
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    )
                    result.success(true)
                } catch (e: Exception) {
                    result.error("SHARE", e.message, null)
                }
            }

            else -> result.notImplemented()
        }
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
            roots.add(
                mapOf(
                    "path" to primary.absolutePath,
                    "label" to "Almacenamiento interno"
                )
            )
        }
        return roots
    }

    private fun storageInfo(path: String): Map<String, Any> {
        val stat = StatFs(path)
        val total = stat.totalBytes
        val free = stat.availableBytes
        return mapOf("total" to total, "free" to free, "used" to (total - free))
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
        if (f.isDirectory) {
            val children = f.listFiles() ?: return f.delete()
            var ok = true
            for (child in children) {
                if (!deleteRecursive(child)) ok = false
            }
            if (!ok) return false
        }
        return f.delete()
    }

    private fun copyRecursive(src: File, dest: File): Boolean {
        return try {
            val srcCanon = src.canonicalFile
            val destCanon = dest.canonicalFile
            if (srcCanon.absolutePath == destCanon.absolutePath) return false
            if (srcCanon.isDirectory &&
                destCanon.absolutePath.startsWith(srcCanon.absolutePath + "/")
            ) {
                return false
            }
            if (src.isDirectory) {
                if (!dest.exists() && !dest.mkdirs()) return false
                val children = src.listFiles() ?: return true
                var ok = true
                for (child in children) {
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
}
