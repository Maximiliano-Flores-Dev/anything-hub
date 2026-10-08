package com.anything.hub

import android.content.Context
import java.io.File

/**
 * Hardening de rutas: validación centralizada para operaciones de archivos y caché.
 *
 * Principios:
 * - Rutas de caché de APK: solo prefijos allowlist (incoming_apk/, puerto_limbo/).
 * - Nombres de archivo (rename): sin separadores ni path traversal.
 * - Paths generales: no vacíos, sin null bytes; canonicalización donde aplica.
 * - El explorador mantiene soberanía del usuario (MANAGE_EXTERNAL_STORAGE),
 *   pero se bloquean los vectores clásicos de escape y abuse.
 */
object PathSecurity {

    /** Prefijos relativos permitidos bajo cacheDir para APKs. */
    private val ALLOWED_CACHE_PREFIXES = listOf(
        "incoming_apk/",
        "puerto_limbo/",
    )

    /** Tamaño máximo de descarga PuertoPipe (500 MB). */
    const val MAX_APK_DOWNLOAD_BYTES: Long = 500L * 1024 * 1024

    /** Edad máxima de APKs en limbo / incoming antes de limpieza (24 h). */
    const val MAX_CACHE_APK_AGE_MS: Long = 24L * 60 * 60 * 1000

    fun resolveCacheApk(context: Context, relative: String): File {
        val rel = relative.trim()
        if (rel.isEmpty()) {
            throw IllegalArgumentException("cacheRelativePath vacío")
        }
        if (rel.contains('\u0000')) {
            throw IllegalArgumentException("Null byte en path")
        }
        val normalized = rel.replace('\\', '/')
        if (normalized.startsWith("/") || normalized.startsWith("../") ||
            normalized.contains("/../") || normalized.endsWith("/..") ||
            normalized == ".." || normalized.contains("..")
        ) {
            throw IllegalArgumentException("Path traversal en cacheRelativePath")
        }
        val allowed = ALLOWED_CACHE_PREFIXES.any { normalized.startsWith(it) }
        if (!allowed) {
            throw IllegalArgumentException(
                "Prefijo de caché no permitido. Solo: ${ALLOWED_CACHE_PREFIXES.joinToString()}"
            )
        }
        val parts = normalized.split('/')
        if (parts.size != 2 || parts[1].isBlank() || parts[1].contains('/')) {
            throw IllegalArgumentException("Formato de cacheRelativePath inválido")
        }
        if (!parts[1].endsWith(".apk", ignoreCase = true)) {
            throw IllegalArgumentException("Solo se admiten archivos .apk en caché de instalación")
        }

        val base = context.cacheDir.canonicalFile
        val resolved = File(base, normalized).canonicalFile
        if (!resolved.absolutePath.startsWith(base.absolutePath + File.separator) &&
            resolved.absolutePath != base.absolutePath
        ) {
            throw IllegalArgumentException("Path resuelto fuera de cacheDir")
        }
        return resolved
    }

    fun requireValidPath(path: String, label: String = "path"): String {
        val p = path.trim()
        if (p.isEmpty()) {
            throw IllegalArgumentException("$label vacío")
        }
        if (p.contains('\u0000')) {
            throw IllegalArgumentException("Null byte en $label")
        }
        return p
    }

    fun requireSafeFileName(name: String): String {
        val n = name.trim()
        if (n.isEmpty()) {
            throw IllegalArgumentException("Nombre vacío")
        }
        if (n.contains('\u0000')) {
            throw IllegalArgumentException("Null byte en nombre")
        }
        if (n.contains('/') || n.contains('\\')) {
            throw IllegalArgumentException("El nombre no puede contener separadores de ruta")
        }
        if (n == "." || n == ".." || n.contains("..")) {
            throw IllegalArgumentException("Nombre de traversal no permitido")
        }
        if (n.any { it < ' ' }) {
            throw IllegalArgumentException("Caracteres de control en nombre")
        }
        return n
    }

    fun cleanupStaleApkCache(context: Context) {
        try {
            val now = System.currentTimeMillis()
            for (subdir in listOf("incoming_apk", "puerto_limbo")) {
                val dir = File(context.cacheDir, subdir)
                if (!dir.isDirectory) continue
                dir.listFiles()?.forEach { f ->
                    if (f.isFile && (now - f.lastModified()) > MAX_CACHE_APK_AGE_MS) {
                        f.delete()
                    }
                }
            }
        } catch (_: Exception) {
        }
    }
}
