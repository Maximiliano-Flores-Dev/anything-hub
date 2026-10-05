# Anythings Hub — Big Update (módulo Apps + Seguridad)

Entregable de **opción 2 (código Flutter)** y **opción 4 (wireframes + especificación UI)**.

## Contenido

```
docs/
  UI_SPEC_WIREFRAMES.md     ← especificación + wireframes texto + tokens

lib/modules/apps/
  models/app_models.dart
  services/
    apps_local_store.dart     ← bookmarks + reseñas (SharedPreferences)
    apk_risk_scorer.dart      ← matriz de riesgo Hito 3
  widgets/
    hub_panel.dart
    app_icon_cell.dart        ← celda compacta (solo icono, sin botones)
  ui/
    mis_aplicaciones_screen.dart   ← grilla 4 columnas → tap abre gestión
    app_gestion_screen.dart        ← Lanzar / Ajustes / Desinstalar / ★ / reseña
    revisar_apk_screen.dart        ← risk + soberanía + override
    analisis_complementario_screen.dart
    verificacion_firma_screen.dart ← oráculo / caché / fail-closed
```

## Integración rápida

1. Copia `lib/modules/apps/` dentro del repo `anything_hub`.
2. Asegura imports a:
   - `lib/core/hub_colors.dart`
   - `lib/services/device_apps_service.dart`
   - `lib/ui/widgets/gradient_pill_button.dart`
3. En `MainLayoutScreen`, la card **Mis Aplicaciones** debe navegar a:

```dart
Navigator.of(context).push(
  MaterialPageRoute(builder: (_) => const MisAplicacionesScreen()),
);
```

4. Amplía el canal nativo `anythings.hub/device_apps` (Kotlin) con:
   - `openAppSettings` → `Settings.ACTION_APPLICATION_DETAILS_SETTINGS`
   - `requestUninstall` → `Intent.ACTION_DELETE` / `ACTION_UNINSTALL_PACKAGE`
   - (Hito 3) parse de APK: permisos, package, cert hash, SHA-256 del archivo

5. Intent filters (Hito 2) en `AndroidManifest.xml` para `VIEW` / `SEND` de `application/vnd.android.package-archive`, con `FileProvider` en `cacheDir`.

## Decisiones de UI (según feedback)

- **Mis Aplicaciones** = grilla densa de iconos (estilo launcher), **sin** botones Lanzar/Ajustes en cada celda.
- El centro de control vive en **AppGestionScreen** al tocar un icono.
- Bookmark = estrella amarilla `#F2B531` sobre el icono.
- Override de instalación y de firma siempre visibles (soberanía de usuario).

## Dependencias ya presentes en el proyecto

`shared_preferences`, `http`, `crypto`, `path_provider`, `flutter_secure_storage` — suficientes para bookmarks, hash y caché del oráculo.

## Pendiente nativo / backend

| Ítem | Capa |
|------|------|
| Parser de manifiesto APK | Kotlin / Dart |
| Certificate pinning cliente | `http` + pines |
| Endpoint oráculo `_signatures.json` | Backend |
| Caché firmada TTL 7 días | Local cifrada |
| API VirusTotal automatizada | Fase futura (UI ya preparada) |
