package com.anything.hub

import android.content.Context
import android.content.pm.PackageManager
import android.content.pm.Signature
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.os.Build
import java.io.ByteArrayOutputStream
import java.io.File
import java.security.MessageDigest

/**
 * Parseo real de APK vía PackageManager.getPackageArchiveInfo.
 * Incluye huellas SHA-256 de certificados de firma (oráculo local).
 *
 * Hardening: inspectFromCache delega la validación de path relativo a PathSecurity.
 */
object ApkInspectHelper {

    fun inspectFromCache(context: Context, relative: String): Map<String, Any?> {
        val file = PathSecurity.resolveCacheApk(context, relative)
        if (!file.exists() || !file.isFile) {
            throw IllegalArgumentException("APK no encontrado: $relative")
        }
        return inspectAtPath(context, file.absolutePath)
    }

    fun inspectAtPath(context: Context, path: String): Map<String, Any?> {
        val safePath = PathSecurity.requireValidPath(path)
        val file = File(safePath)
        if (!file.exists() || !file.isFile) {
            throw IllegalArgumentException("APK no encontrado: $path")
        }
        if (file.extension.isNotEmpty() && !file.extension.equals("apk", ignoreCase = true)) {
            throw IllegalArgumentException("Solo se admiten archivos .apk")
        }

        val flags = if (Build.VERSION.SDK_INT >= 28) {
            PackageManager.GET_PERMISSIONS or PackageManager.GET_SIGNING_CERTIFICATES
        } else {
            @Suppress("DEPRECATION")
            PackageManager.GET_PERMISSIONS or PackageManager.GET_SIGNATURES
        }

        val pi = context.packageManager.getPackageArchiveInfo(safePath, flags)
            ?: throw IllegalStateException("No se pudo parsear el APK")

        val ai = pi.applicationInfo
        if (ai != null) {
            ai.sourceDir = safePath
            ai.publicSourceDir = safePath
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

        val certs = extractCertSha256(pi)
        val installedCerts = pi.packageName?.let { pkg ->
            try {
                extractInstalledCertSha256(context, pkg)
            } catch (_: Exception) {
                emptyList()
            }
        } ?: emptyList()

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
            "signingCertSha256" to certs,
            "installedCertSha256" to installedCerts,
            "isPackageInstalled" to installedCerts.isNotEmpty(),
        )
    }

    private fun extractCertSha256(pi: android.content.pm.PackageInfo): List<String> {
        val sigs: Array<Signature>? = if (Build.VERSION.SDK_INT >= 28) {
            val info = pi.signingInfo ?: return emptyList()
            if (info.hasMultipleSigners()) {
                info.apkContentsSigners
            } else {
                info.signingCertificateHistory
            }
        } else {
            @Suppress("DEPRECATION")
            pi.signatures
        }
        if (sigs == null || sigs.isEmpty()) return emptyList()
        return sigs.mapNotNull { sig ->
            try {
                sha256Hex(sig.toByteArray())
            } catch (_: Exception) {
                null
            }
        }.distinct()
    }

    private fun extractInstalledCertSha256(context: Context, packageName: String): List<String> {
        val pm = context.packageManager
        val flags = if (Build.VERSION.SDK_INT >= 28) {
            PackageManager.GET_SIGNING_CERTIFICATES
        } else {
            @Suppress("DEPRECATION")
            PackageManager.GET_SIGNATURES
        }
        val pi = try {
            if (Build.VERSION.SDK_INT >= 33) {
                pm.getPackageInfo(packageName, PackageManager.PackageInfoFlags.of(flags.toLong()))
            } else {
                @Suppress("DEPRECATION")
                pm.getPackageInfo(packageName, flags)
            }
        } catch (_: PackageManager.NameNotFoundException) {
            return emptyList()
        }
        return extractCertSha256(pi)
    }

    private fun sha256Hex(bytes: ByteArray): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(bytes)
        return digest.joinToString("") { "%02x".format(it) }
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
