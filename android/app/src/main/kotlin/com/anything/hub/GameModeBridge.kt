package com.anything.hub

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.provider.Settings
import android.view.WindowManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Metricas gamer + permiso overlay + control del HUD flotante.
 * FPS del HUD con Choreographer en GameHudService.
 * Hz del panel = techo real del dispositivo.
 */
object GameModeBridge {
    fun handle(activity: MainActivity, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "canDrawOverlays" -> result.success(
                if (Build.VERSION.SDK_INT >= 23) Settings.canDrawOverlays(activity) else true
            )
            "requestOverlayPermission" -> {
                if (Build.VERSION.SDK_INT >= 23 && !Settings.canDrawOverlays(activity)) {
                    val intent = Intent(
                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        Uri.parse("package:${activity.packageName}")
                    )
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    activity.startActivity(intent)
                }
                result.success(null)
            }
            "getDisplayMetrics" -> result.success(displayMetrics(activity))
            "getBatteryStats" -> result.success(batteryStats(activity))
            "startHud" -> {
                val pkg = call.argument<String>("packageName") ?: ""
                val title = call.argument<String>("title") ?: "Game"
                val target = call.argument<Int>("targetFps") ?: 0
                result.success(GameHudService.start(activity, pkg, title, target))
            }
            "stopHud" -> {
                GameHudService.stop(activity)
                result.success(null)
            }
            "isHudActive" -> result.success(GameHudService.isActive)
            "getHudSnapshot" -> result.success(GameHudService.snapshot())
            "getForegroundPackage" -> result.success(foregroundPackage(activity))
            "setScreenTimeoutSec" -> {
                setTimeout(activity, call.argument<Int>("seconds") ?: 60)
                result.success(null)
            }
            "getScreenTimeoutSec" -> result.success(getTimeout(activity))
            "setBrightness" -> result.success(null)
            else -> result.notImplemented()
        }
    }

    private fun displayMetrics(ctx: Context): Map<String, Any?> {
        val wm = ctx.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val rate = try {
            if (Build.VERSION.SDK_INT >= 30) {
                wm.defaultDisplay?.mode?.refreshRate ?: 60f
            } else {
                @Suppress("DEPRECATION")
                wm.defaultDisplay?.refreshRate ?: 60f
            }
        } catch (_: Exception) {
            60f
        }
        return mapOf("refreshRate" to rate.toDouble())
    }

    private fun batteryStats(ctx: Context): Map<String, Any?> {
        return try {
            val battery = ctx.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            val level = battery?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
            val scale = battery?.getIntExtra(BatteryManager.EXTRA_SCALE, 100) ?: 100
            val pct = if (level >= 0 && scale > 0) (level * 100) / scale else -1
            val status = battery?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
            val charging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
                status == BatteryManager.BATTERY_STATUS_FULL
            val temp = (battery?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, 0) ?: 0) / 10.0
            mapOf("level" to pct, "charging" to charging, "tempC" to temp)
        } catch (_: Exception) {
            emptyMap()
        }
    }

    private fun foregroundPackage(ctx: Context): String? {
        return try {
            val usm = ctx.getSystemService(Context.USAGE_STATS_SERVICE)
                as android.app.usage.UsageStatsManager
            val end = System.currentTimeMillis()
            val stats = usm.queryUsageStats(
                android.app.usage.UsageStatsManager.INTERVAL_INTERVAL_DAILY, end - 60_000, end
            )
            if (stats.isNullOrEmpty()) return null
            var best: android.app.usage.UsageStats? = null
            for (s in stats) {
                if (best == null || s.lastTimeUsed > best!!.lastTimeUsed) best = s
            }
            best?.packageName
        } catch (_: Exception) {
            null
        }
    }

    private fun setTimeout(ctx: Context, seconds: Int) {
        try {
            Settings.System.putInt(
                ctx.contentResolver,
                Settings.System.SCREEN_OFF_TIMEOUT,
                (seconds * 1000).coerceIn(15_000, 600_000)
            )
        } catch (_: Exception) {
        }
    }

    private fun getTimeout(ctx: Context): Int {
        return try {
            Settings.System.getInt(ctx.contentResolver, Settings.System.SCREEN_OFF_TIMEOUT) / 1000
        } catch (_: Exception) {
            60
        }
    }
}
