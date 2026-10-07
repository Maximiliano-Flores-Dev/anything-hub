package com.example.anything_hub

import android.app.ActivityManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Best-effort performance controls without root.
 * - Memory snapshot
 * - Focus via NotificationManager interruption filter
 * - Trim only non-system, non-critical user packages via killBackgroundProcesses
 */
object PerformanceBridge {
    private const val PREFS = "hub_performance"
    private const val KEY_MODE = "active_mode"
    private const val KEY_PREV_FILTER = "prev_interruption_filter"

    private val HARD_WHITELIST = setOf(
        "android",
        "com.android.systemui",
        "com.android.phone",
        "com.android.launcher",
        "com.google.android.gms",
        "com.google.android.gsf",
        "com.android.settings",
        "com.android.providers.settings",
        "com.android.permissioncontroller",
    )

    fun handle(activity: MainActivity, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getMemoryInfo" -> result.success(memoryInfo(activity))
            "hasNotificationPolicyAccess" -> result.success(hasPolicyAccess(activity))
            "openNotificationPolicySettings" -> {
                openPolicySettings(activity)
                result.success(null)
            }
            "setFocusNotifications" -> {
                val enable = call.argument<Boolean>("enable") ?: false
                result.success(setFocusNotifications(activity, enable))
            }
            "trimUnnecessaryBackground" -> {
                val level = call.argument<String>("aggressiveness") ?: "eco"
                result.success(trimUnnecessary(activity, level))
            }
            "getActiveMode" -> {
                result.success(
                    activity.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                        .getString(KEY_MODE, "balanced")
                )
            }
            "setActiveMode" -> {
                val mode = call.argument<String>("mode") ?: "balanced"
                activity.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                    .edit().putString(KEY_MODE, mode).apply()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun memoryInfo(ctx: Context): Map<String, Any> {
        val am = ctx.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val mi = ActivityManager.MemoryInfo()
        am.getMemoryInfo(mi)
        val total = if (mi.totalMem > 0) mi.totalMem else 1L
        return mapOf(
            "availMb" to (mi.availMem / (1024 * 1024)).toInt(),
            "totalMb" to (total / (1024 * 1024)).toInt(),
            "lowMemory" to mi.lowMemory,
            "thresholdMb" to (mi.threshold / (1024 * 1024)).toInt(),
        )
    }

    private fun hasPolicyAccess(ctx: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return nm.isNotificationPolicyAccessGranted
    }

    private fun openPolicySettings(activity: MainActivity) {
        try {
            val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
            } else {
                Intent(Settings.ACTION_SETTINGS)
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            activity.startActivity(intent)
        } catch (_: Exception) {
        }
    }

    private fun setFocusNotifications(ctx: Context, enable: Boolean): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return false
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (!nm.isNotificationPolicyAccessGranted) return false
        val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        return try {
            if (enable) {
                val current = nm.currentInterruptionFilter
                prefs.edit().putInt(KEY_PREV_FILTER, current).apply()
                nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
            } else {
                val prev = prefs.getInt(
                    KEY_PREV_FILTER,
                    NotificationManager.INTERRUPTION_FILTER_ALL
                )
                nm.setInterruptionFilter(prev)
            }
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun trimUnnecessary(ctx: Context, level: String): Map<String, Any> {
        val am = ctx.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val pm = ctx.packageManager
        val self = ctx.packageName
        val candidates = mutableListOf<String>()

        val limit = when (level) {
            "performance" -> 18
            "focus" -> 12
            else -> 8
        }

        try {
            @Suppress("DEPRECATION")
            val running = am.runningAppProcesses ?: emptyList()
            for (proc in running) {
                if (proc.importance <= ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND) {
                    continue
                }
                if (proc.importance <= ActivityManager.RunningAppProcessInfo.IMPORTANCE_VISIBLE) {
                    continue
                }
                val pkgs = proc.pkgList ?: continue
                for (pkg in pkgs) {
                    if (pkg == self) continue
                    if (HARD_WHITELIST.any { pkg == it || pkg.startsWith("$it.") }) continue
                    if (pkg.startsWith("com.android.") || pkg.startsWith("android.")) continue
                    try {
                        val ai = pm.getApplicationInfo(pkg, 0)
                        val isSystem = (ai.flags and ApplicationInfo.FLAG_SYSTEM) != 0
                        if (isSystem) continue
                        if (proc.importance >= ActivityManager.RunningAppProcessInfo.IMPORTANCE_CACHED ||
                            proc.importance >= ActivityManager.RunningAppProcessInfo.IMPORTANCE_SERVICE
                        ) {
                            if (!candidates.contains(pkg)) candidates.add(pkg)
                        }
                    } catch (_: PackageManager.NameNotFoundException) {
                    }
                }
            }
        } catch (_: Exception) {
        }

        val target = candidates.take(limit)
        var killed = 0
        for (pkg in target) {
            try {
                am.killBackgroundProcesses(pkg)
                killed++
            } catch (_: Exception) {
            }
        }

        val note = if (target.isEmpty()) {
            "No habia procesos de usuario en segundo plano elegibles (o el SO restringe la limpieza)."
        } else {
            "Solo apps de usuario no criticas en background. El SO puede limitar killBackgroundProcesses."
        }

        return mapOf(
            "attempted" to target.size,
            "killed" to killed,
            "packages" to target,
            "note" to note,
        )
    }
}
