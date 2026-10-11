# =============================================================================
# ProGuard / R8 — Anythings Hub
# minifyEnabled + shrinkResources en release. Reglas mínimas para no romper
# Flutter embedding, MethodChannels y FileProvider.
# =============================================================================

# ---- Flutter / embedding ----
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# ---- Nuestros bridges nativos (MethodChannel handlers) ----
-keep class com.anything.hub.** { *; }

# ---- FileProvider / AndroidX ----
-keep class androidx.core.content.FileProvider { *; }
-keepnames class * extends android.content.ContentProvider

# ---- Serialización / reflexión mínima ----
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# ---- No ofuscar enums de Android usados por reflexión ----
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# ---- FlutterSecureStorage / plugins (si usan reflection) ----
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-dontwarn com.it_nomads.fluttersecurestorage.**

# ---- Evitar strip de clases usadas solo desde Dart vía channel ----
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
