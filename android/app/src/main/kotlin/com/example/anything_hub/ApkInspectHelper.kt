package com.example.anything_hub

import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.os.Build
import java.io.ByteArrayOutputStream
import java.io.File

/**
 * Parseo real de APK vía PackageManager.getPackageArchiveInfo.
 * Usado por inspectApk (caché) e inspectApkPath (ruta absoluta).
 */
object ApkInspectHelper {

    fun inspectFromCache(context: Context, relative: String): Map<String, Any?> {
        val file = File(context.cacheDir, relative)
        if (!file.exists() || !file.isFile) {
            throw IllegalArgumentException("APK no encontrado: $relative")
        }
        return inspectAtPath(context, file.absolutePath)
    }

    fun inspectAtPath(context: Context, path: String): Map<String, Any?> {
        val file = File(path)
        if (!file.exists() || !file.isFile) {
            throw IllegalArgumentException("APK no encontrado: $path")
        }
        @Suppress("DEPRECATION")
        val flags = PackageManager.GET_PERMISSIONS
        val pi = context.packageManager.getPackageArchiveInfo(path, flags)
            ?: throw IllegalStateException("No se pudo parsear el APK")

        val ai = pi.applicationInfo
        if (ai != null) {
            ai.sourceDir = path
            ai.publicSourceDir = path
        }

        val label = if (ai != null) {
            try {
                context.packageManager.getApplicationLabel(ai).toString()
            } catch (_: Exception) {
                pi.packageName ?: file.name
            }
        } else {
            pi.packageName ?: file.name
        }

        val perms = pi.requestedPermissions?.toList() ?: emptyList()

        var icon: ByteArray? = null
        if (ai != null) {
            try {
                icon = iconBytes(context.packageManager.getApplicationIcon(ai), 96)
            } catch (_: Exception) {
            }
        }

        return mapOf(
            "packageName" to (pi.packageName ?: ""),
            "appLabel" to label,
            "versionName" to (pi.versionName ?: ""),
            "versionCode" to if (Build.VERSION.SDK_INT >= 28) {
                pi.longVersionCode
            } else {
                @Suppress("DEPRECATION")
                pi.versionCode.toLong()
            },
            "permissions" to perms,
            "fileName" to file.name,
            "sizeBytes" to file.length(),
            "icon" to icon,
        )
    }

    fun iconBytes(drawable: Drawable, size: Int = 96): ByteArray {
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
