package com.example.anything_hub

import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.net.Uri
import android.os.Build
import android.os.Process
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Canal anythings.hub/device_apps: listado, launch, install, inspect APK, estado.
 */
object DeviceAppsBridge {

    fun handle(activity: MainActivity, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "selfPackage" -> result.success(activity.packageName)

            "hasUsageAccess" -> result.success(hasUsageAccess(activity))

            "openUsageAccessSettings" -> {
                activity.startActivity(
                    Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
                result.success(null)
            }

            "listApps" -> {
                val days = call.argument<Int>("days") ?: 14
                activity.worker.execute {
                    try {
                        val data = listApps(activity, days)
                        activity.runOnUiThread { result.success(data) }
                    } catch (e: Exception) {
                        activity.runOnUiThread {
                            result.error("SCAN_FAILED", e.message, null)
                        }
                    }
                }
            }

            "launchApp" -> {
                val pkg = call.argument<String>("package")
                val intent = pkg?.let { activity.packageManager.getLaunchIntentForPackage(it) }
                if (intent != null) {
                    activity.startActivity(intent)
                    result.success(true)
                } else {
                    result.success(false)
                }
            }

            "listInstalledPackages" -> {
                activity.worker.execute {
                    try {
                        val pkgs = listInstalledPackages(activity)
                        activity.runOnUiThread { result.success(pkgs) }
                    } catch (e: Exception) {
                        activity.runOnUiThread {
                            result.error("PACKAGES", e.message, null)
                        }
                    }
                }
            }

            "launchAppWithPath" -> {
                val pkg = call.argument<String>("package")
                val path = call.argument<String>("path")
                if (pkg.isNullOrEmpty()) {
                    result.success(false)
                } else {
                    result.success(launchAppWithPath(activity, pkg, path))
                }
            }

            "termuxRunCommand" -> {
                val command = call.argument<String>("command") ?: ""
                val workdir = call.argument<String>("workdir") ?: ""
                val background = call.argument<Boolean>("background") ?: false
                result.success(TermuxHelper.runCommand(activity, command, workdir, background))
            }

            "loadState" -> result.success(prefs(activity).getString("state", null))

            "saveState" -> {
                prefs(activity).edit()
                    .putString("state", call.argument<String>("json"))
                    .apply()
                result.success(null)
            }

            "openAppSettings" -> {
                val pkg = call.argument<String>("package")
                if (pkg.isNullOrEmpty()) {
                    result.success(false)
                } else {
                    try {
                        activity.startActivity(
                            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$pkg")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                        )
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
                        activity.startActivity(
                            Intent(Intent.ACTION_DELETE).apply {
                                data = Uri.parse("package:$pkg")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                        )
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
                    activity.worker.execute {
                        try {
                            val file = File(activity.cacheDir, relative)
                            if (!file.exists()) {
                                activity.runOnUiThread {
                                    result.error("NOT_FOUND", "APK no encontrado en caché", null)
                                }
                                return@execute
                            }
                            val uri = FileProvider.getUriForFile(
                                activity,
                                "${activity.packageName}.fileprovider",
                                file
                            )
                            val intent = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(uri, "application/vnd.android.package-archive")
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            activity.runOnUiThread {
                                activity.startActivity(intent)
                                result.success(true)
                            }
                        } catch (e: Exception) {
                            activity.runOnUiThread {
                                result.error("INSTALL", e.message, null)
                            }
                        }
                    }
                }
            }

            "inspectApk" -> {
                val relative = call.argument<String>("cacheRelativePath")
                if (relative.isNullOrEmpty()) {
                    result.error("PATH", "cacheRelativePath requerido", null)
                } else {
                    activity.worker.execute {
                        try {
                            val data = ApkInspectHelper.inspectFromCache(activity, relative)
                            activity.runOnUiThread { result.success(data) }
                        } catch (e: Exception) {
                            activity.runOnUiThread {
                                result.error("INSPECT", e.message, null)
                            }
                        }
                    }
                }
            }

            "inspectApkPath" -> {
                val absolute = call.argument<String>("path")
                if (absolute.isNullOrEmpty()) {
                    result.error("PATH", "path requerido", null)
                } else {
                    activity.worker.execute {
                        try {
                            val data = ApkInspectHelper.inspectAtPath(activity, absolute)
                            activity.runOnUiThread { result.success(data) }
                        } catch (e: Exception) {
                            activity.runOnUiThread {
                                result.error("INSPECT", e.message, null)
                            }
                        }
                    }
                }
            }

            "consumePendingIncomingApk" -> {
                val pending = activity.pendingIncomingApk
                activity.pendingIncomingApk = null
                result.success(pending)
            }

            else -> result.notImplemented()
        }
    }

    private fun prefs(ctx: Context) =
        ctx.getSharedPreferences("anythings_hub", Context.MODE_PRIVATE)

    private fun hasUsageAccess(ctx: Context): Boolean {
        val appOps = ctx.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                ctx.packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                ctx.packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun listApps(ctx: Context, days: Int): List<Map<String, Any?>> {
        val pm = ctx.packageManager
        val launcher = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        @Suppress("DEPRECATION")
        val resolved = pm.queryIntentActivities(launcher, 0)
        val usageMap = mutableMapOf<String, Long>()
        try {
            val usm = ctx.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val end = System.currentTimeMillis()
            val start = end - days * 24L * 60 * 60 * 1000
            val stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, start, end)
            stats?.forEach { s ->
                usageMap[s.packageName] = (usageMap[s.packageName] ?: 0L) + s.totalTimeInForeground
            }
        } catch (_: Exception) {
        }
        val result = ArrayList<Map<String, Any?>>()
        for (ri in resolved) {
            val pkg = ri.activityInfo.packageName
            val ai = try {
                pm.getApplicationInfo(pkg, 0)
            } catch (_: Exception) {
                continue
            }
            val name = pm.getApplicationLabel(ai).toString()
            val icon = try {
                ApkInspectHelper.iconBytes(pm.getApplicationIcon(ai))
            } catch (_: Exception) {
                null
            }
            result.add(
                mapOf(
                    "package" to pkg,
                    "name" to name,
                    "category" to categoryOf(ai),
                    "usageMs" to (usageMap[pkg] ?: 0L),
                    "icon" to icon,
                )
            )
        }
        return result
    }

    private fun categoryOf(ai: ApplicationInfo): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            return when (ai.category) {
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

    private fun listInstalledPackages(ctx: Context): List<String> {
        val pm = ctx.packageManager
        val launcher = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        @Suppress("DEPRECATION")
        val resolved = pm.queryIntentActivities(launcher, 0)
        return resolved.map { it.activityInfo.packageName }.distinct()
    }

    private fun launchAppWithPath(
        activity: MainActivity,
        pkg: String,
        path: String?,
    ): Boolean {
        val pm = activity.packageManager
        if (!path.isNullOrEmpty()) {
            val file = File(path)
            val target = when {
                file.exists() && file.isFile -> file
                file.exists() && file.isDirectory -> {
                    val md = File(file, "project.md")
                    if (md.exists() && md.isFile) md else null
                }
                else -> null
            }
            if (target != null) {
                try {
                    val uri = FileProvider.getUriForFile(
                        activity,
                        "${activity.packageName}.fileprovider",
                        target
                    )
                    val viewIntent = Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(uri, "text/markdown")
                        setPackage(pkg)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    if (viewIntent.resolveActivity(pm) != null) {
                        activity.startActivity(viewIntent)
                        return true
                    }
                    val fallback = Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(uri, "*/*")
                        setPackage(pkg)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    if (fallback.resolveActivity(pm) != null) {
                        activity.startActivity(fallback)
                        return true
                    }
                } catch (_: Exception) {
                }
            }
        }
        val launch = pm.getLaunchIntentForPackage(pkg)
        if (launch != null) {
            activity.startActivity(launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            return true
        }
        return false
    }
}
