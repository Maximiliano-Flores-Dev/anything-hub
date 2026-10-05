# Parche MainActivity.kt — métodos del canal `anythings.hub/device_apps`

Añadir dentro del `when (call.method)` del canal de apps, **antes** del `else -> result.notImplemented()`:

```kotlin
"openAppSettings" -> {
    val pkg = call.argument<String>("package")
    if (pkg.isNullOrEmpty()) {
        result.success(false)
    } else {
        try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$pkg")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
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
            val intent = Intent(Intent.ACTION_DELETE).apply {
                data = Uri.parse("package:$pkg")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("UNINSTALL", e.message, null)
        }
    }
}
"getCallingPackageSafe" -> {
    result.success(callingActivity?.packageName)
}
"installApkFromCache" -> {
    val relative = call.argument<String>("cacheRelativePath")
    if (relative.isNullOrEmpty()) {
        result.error("PATH", "cacheRelativePath requerido", null)
    } else {
        worker.execute {
            try {
                val file = File(cacheDir, relative)
                if (!file.exists()) {
                    runOnUiThread { result.error("NOT_FOUND", "APK no encontrado en caché", null) }
                    return@execute
                }
                val uri = FileProvider.getUriForFile(
                    this,
                    "${applicationContext.packageName}.fileprovider",
                    file
                )
                val intent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(uri, "application/vnd.android.package-archive")
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                runOnUiThread {
                    startActivity(intent)
                    result.success(true)
                }
            } catch (e: Exception) {
                runOnUiThread { result.error("INSTALL", e.message, null) }
            }
        }
    }
}
```

## Recepción de APK (onCreate / onNewIntent)

```kotlin
override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    handleIncomingApk(intent)
}

override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    setIntent(intent)
    handleIncomingApk(intent)
}

private fun handleIncomingApk(intent: Intent?) {
    if (intent == null) return
    val action = intent.action
    val isApk = action == Intent.ACTION_VIEW || action == Intent.ACTION_SEND
    if (!isApk) return

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
    }
    if (uri == null) return

    worker.execute {
        try {
            val dest = File(cacheDir, "incoming_apk/${System.currentTimeMillis()}.apk")
            dest.parentFile?.mkdirs()
            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(dest).use { output -> input.copyTo(output) }
            }
            val payload = mapOf(
                "cacheRelativePath" to "incoming_apk/${dest.name}",
                "fileName" to (dest.name),
                "sizeBytes" to dest.length(),
                "callerPackage" to (caller ?: ""),
            )
        } catch (_: Exception) { }
    }
}
```

> Validar `caller` contra una allowlist o exigir que no esté vacío según política del Hito 2.2.
