package com.anything.hub

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Tubo de descarga: el APK entra por chunks a cacheDir/puerto_limbo.
 * Solo HTTPS, límite de tamaño, cabecera ZIP, SHA-256.
 */
object PuertoPipeBridge : EventChannel.StreamHandler {
    private val main = Handler(Looper.getMainLooper())
    private val cancel = AtomicBoolean(false)
    @Volatile
    private var sink: EventChannel.EventSink? = null

    fun register(messenger: io.flutter.plugin.common.BinaryMessenger, activity: MainActivity) {
        MethodChannel(messenger, "anythings.hub/puerto").setMethodCallHandler { call, result ->
            handle(activity, call, result)
        }
        EventChannel(messenger, "anythings.hub/puerto_events").setStreamHandler(this)
        // Limpieza best-effort de limbo/incoming al registrar
        activity.worker.execute { PathSecurity.cleanupStaleApkCache(activity) }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
        cancel.set(true)
    }

    private fun handle(activity: MainActivity, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "download" -> {
                val url = call.argument<String>("url")
                if (url.isNullOrBlank() || !(url.startsWith("https://"))) {
                    result.error("URL", "Solo https", null)
                    return
                }
                try {
                    val parsed = URL(url)
                    if (parsed.userInfo != null) {
                        result.error("URL", "URL con credenciales no permitida", null)
                        return
                    }
                    if (parsed.host.isNullOrBlank()) {
                        result.error("URL", "Host inválido", null)
                        return
                    }
                } catch (e: Exception) {
                    result.error("URL", e.message, null)
                    return
                }
                cancel.set(false)
                result.success(true)
                activity.worker.execute {
                    try {
                        val payload = streamToLimbo(activity, url)
                        main.post { sink?.success(payload) }
                    } catch (e: Exception) {
                        main.post {
                            sink?.error("PIPE", e.message, null)
                        }
                    }
                }
            }
            "cancel" -> {
                cancel.set(true)
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun streamToLimbo(activity: MainActivity, url: String): Map<String, Any?> {
        val conn = (URL(url).openConnection() as HttpURLConnection).apply {
            instanceFollowRedirects = true
            connectTimeout = 20000
            readTimeout = 60000
            setRequestProperty("User-Agent", "AnythingsHub/puerto")
        }
        try {
            val code = conn.responseCode
            if (code !in 200..299) throw IllegalStateException("HTTP $code")
            val total = conn.contentLengthLong
            if (total > PathSecurity.MAX_APK_DOWNLOAD_BYTES) {
                throw IllegalStateException(
                    "APK demasiado grande (máx ${PathSecurity.MAX_APK_DOWNLOAD_BYTES} bytes)"
                )
            }
            val dir = File(activity.cacheDir, "puerto_limbo")
            dir.mkdirs()
            val dest = File(dir, "${System.currentTimeMillis()}.apk")
            val digest = MessageDigest.getInstance("SHA-256")
            var readTotal = 0L
            conn.inputStream.use { input ->
                FileOutputStream(dest).use { output ->
                    val buf = ByteArray(8192)
                    while (true) {
                        if (cancel.get()) {
                            dest.delete()
                            throw IllegalStateException("Descarga cancelada")
                        }
                        val n = input.read(buf)
                        if (n < 0) break
                        output.write(buf, 0, n)
                        digest.update(buf, 0, n)
                        readTotal += n
                        if (readTotal > PathSecurity.MAX_APK_DOWNLOAD_BYTES) {
                            dest.delete()
                            throw IllegalStateException("APK demasiado grande durante descarga")
                        }
                        val progress = mapOf(
                            "phase" to "downloading",
                            "bytes" to readTotal,
                            "total" to total,
                        )
                        main.post { sink?.success(progress) }
                    }
                }
            }
            if (readTotal < 4L) {
                dest.delete()
                throw IllegalStateException("Archivo vacío")
            }
            val head = ByteArray(4)
            dest.inputStream().use { it.read(head) }
            val isZip = head[0] == 0x50.toByte() && head[1] == 0x4B.toByte()
            if (!isZip) {
                dest.delete()
                throw IllegalStateException("No es un APK (falta cabecera ZIP)")
            }
            val sha = digest.digest().joinToString("") { "%02x".format(it) }
            return mapOf(
                "phase" to "complete",
                "cacheRelativePath" to "puerto_limbo/${dest.name}",
                "fileName" to dest.name,
                "sizeBytes" to dest.length(),
                "sha256" to sha,
            )
        } finally {
            conn.disconnect()
        }
    }
}
