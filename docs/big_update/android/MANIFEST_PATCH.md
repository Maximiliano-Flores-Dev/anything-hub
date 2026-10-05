# Parche AndroidManifest.xml — Hito 2 (Compartir / Abrir con APK)

Dentro de `<activity android:name=".MainActivity" ...>` añadir **después** del intent-filter de OAuth:

```xml
<!-- APK: Abrir con / VIEW -->
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="content" />
    <data android:scheme="file" />
    <data android:mimeType="application/vnd.android.package-archive" />
</intent-filter>

<!-- APK: Compartir / SEND -->
<intent-filter>
    <action android:name="android.intent.action.SEND" />
    <category android:name="android.intent.category.DEFAULT" />
    <data android:mimeType="application/vnd.android.package-archive" />
    <data android:mimeType="application/octet-stream" />
</intent-filter>
```

Dentro de `<queries>` añadir (Android 11+):

```xml
<intent>
    <action android:name="android.intent.action.VIEW" />
    <data android:mimeType="application/vnd.android.package-archive" />
</intent>
```

Permiso opcional para instalar paquetes (Android 8+), si el flujo usa REQUEST_INSTALL:

```xml
<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />
```

`file_paths.xml` ya incluye `<cache-path name="cache" path="." />` — suficiente para APKs en `context.cacheDir` con `FLAG_GRANT_READ_URI_PERMISSION`.
