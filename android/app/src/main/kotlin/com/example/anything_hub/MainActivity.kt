package com.example.anything_hub

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Entry point nativo. Solo registra canales y delega a bridges.
 * Lógica de apps / files / APK / performance vive en archivos separados.
 */
class MainActivity : FlutterActivity() {
    private val appsChannel = "anythings.hub/device_apps"
    private val filesChannel = "anythings.hub/device_files"
    private val perfChannel = "anythings.hub/performance"

    val worker: ExecutorService = Executors.newSingleThreadExecutor()

    /** Payload del último APK recibido vía VIEW/SEND (consume desde Flutter). */
    @Volatile
    var pendingIncomingApk: Map<String, Any?>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIncomingApk(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIncomingApk(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, appsChannel)
            .setMethodCallHandler { call, result ->
                DeviceAppsBridge.handle(this, call, result)
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, filesChannel)
            .setMethodCallHandler { call, result ->
                DeviceFilesBridge.handle(this, call, result)
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

    /**
     * Copia el APK entrante a cacheDir/incoming_apk/ y guarda el payload
     * para que Flutter lo consuma con consumePendingIncomingApk.
     */
    private fun handleIncomingApk(intent: Intent?) {
        if (intent == null) return
        val action = intent.action ?: return
        if (action != Intent.ACTION_VIEW && action != Intent.ACTION_SEND) return

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
        } ?: return

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
                pendingIncomingApk = mapOf(
                    "cacheRelativePath" to "incoming_apk/${dest.name}",
                    "fileName" to dest.name,
                    "sizeBytes" to dest.length(),
                    "callerPackage" to (caller ?: ""),
                )
            } catch (_: Exception) {
                // Silencioso: el usuario puede reintentar compartir el APK
            }
        }
    }
}
