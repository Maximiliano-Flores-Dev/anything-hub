# Enganche con MainLayoutScreen

## 1. Import

```dart
import 'modules/apps/ui/mis_aplicaciones_screen.dart';
```

## 2. Card "Mis Aplicaciones"

Donde se maneja el tap de `_cards[0]` (Mis Aplicaciones), reemplazar el placeholder por:

```dart
void _openCard(int index) {
  switch (index) {
    case 0: // Mis Aplicaciones
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const MisAplicacionesScreen()),
      );
      break;
    // ... resto de cards existentes
  }
}
```

## 3. DeviceAppsService (opcional, wrappers Dart)

Añadir en `lib/services/device_apps_service.dart`:

```dart
static Future<bool> openAppSettings(String packageName) async =>
    await _call<bool>('openAppSettings', {'package': packageName}) ?? false;

static Future<bool> requestUninstall(String packageName) async =>
    await _call<bool>('requestUninstall', {'package': packageName}) ?? false;

static Future<bool> installApkFromCache(String cacheRelativePath) async =>
    await _call<bool>('installApkFromCache', {
      'cacheRelativePath': cacheRelativePath,
    }) ?? false;
```

## 4. Orden de merge recomendado

1. Copiar `lib/modules/apps/` al proyecto.
2. Aplicar parche Kotlin (`android/NATIVE_PATCH_MainActivity.kt.md`).
3. Aplicar intent-filters (`android/MANIFEST_PATCH.md`).
4. Enganchar card del dashboard.
5. Probar grilla → gestión → Lanzar / bookmark.
6. Probar flujo APK con un `.apk` vía “Abrir con”.
