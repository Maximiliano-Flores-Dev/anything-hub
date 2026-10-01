// Ajusta la línea `package` a tu applicationId real (android/app/build.gradle)
// y deja este archivo en la carpeta que corresponda a ese package.
package com.anythings.hub

import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.os.Build
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val channelName = "anythings.hub/device_apps"
    private val worker = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Nombre real del paquete de ESTA app: sirve para ignorarse a sí misma
                    "selfPackage" -> result.success(packageName)

                    "hasUsageAccess" -> result.success(hasUsageAccess())

                    "openUsageAccessSettings" -> {
                        startActivity(
                            Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        )
                        result.success(null)
                    }

                    // Trabajo pesado (íconos → PNG) fuera del hilo principal
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
    }

    private fun prefs() = getSharedPreferences("anythings_hub", Context.MODE_PRIVATE)

    // "Acceso a datos de uso" es un permiso especial: no hay diálogo de runtime,
    // el usuario lo activa en Ajustes. Aquí solo comprobamos si ya lo concedió.
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

    private fun listApps(days: Int): List<Map<String, Any?>> {
        val pm = packageManager

        // Solo apps con ícono de lanzador. Requiere el bloque <queries> del manifest.
        val launcher = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        @Suppress("DEPRECATION")
        val resolved = pm.queryIntentActivities(launcher, 0)

        // Tiempo en primer plano de los últimos `days` días, por paquete
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
            if (pkg == packageName) continue      // se ignora a sí misma
            if (!seen.add(pkg)) continue          // evita duplicados
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

    // Categoría declarada por Android (API 26+). Muchas apps no la declaran →
    // "undefined"; Dart las manda a "Otras apps" o las detecta por palabras clave.
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

    // Dibuja el Drawable (incluye íconos adaptativos) a un PNG de 96x96
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
