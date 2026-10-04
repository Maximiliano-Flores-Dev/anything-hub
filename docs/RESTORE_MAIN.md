# Restaurar lib/main.dart (modulo proyectos)

El archivo monolítico `lib/main.dart` (~145 KB) no pudo subirse completo por limites de la API de commits. **Todo el modulo de proyectos si esta en el repo.**

## Pasos (2 minutos)

```bash
git pull origin main

# 1) Recuperar main.dart completo del historial
git checkout 708596b3b42c1d02f47a61677eef76187860e2ef -- lib/main.dart

# 2) Aplicar la integracion (4 cambios pequenos)
# Abre docs/MAIN_DART_INTEGRATION.md y aplica:
#   - imports del modulo
#   - OAuthDeepLinkHandler.init() en main()
#   - metodo _openProjectsModule()
#   - onTap de la card index 1 -> _openProjectsModule()
```

## Ya esta en el repo

| Componente | Estado |
|---|---|
| `lib/modules/projects/**` | OK (modelo, servicios, UI, tests) |
| `pubspec.yaml` | OK (path, uuid, path_provider, secure_storage, crypto, http, app_links) |
| `AndroidManifest.xml` | OK (deep-link OAuth + queries Termux/editores) |
| `MainActivity.kt` | OK (listInstalledPackages, launchAppWithPath, termuxRunCommand) |
| `lib/main.dart` | Restaurar con los pasos de arriba |

## OAuth Client ID

Cada usuario configura su propia GitHub OAuth App. No se comparte una sola cuenta. Pon tu Client ID en `github_oauth_service.dart`.
