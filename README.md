<div align="center">

<img src="assets/mylogo.png" alt="Anythings Hub" width="120" />

# Anythings Hub

**Tu centro de control personal para Android: apps, enlaces, archivos, proyectos y rendimiento en un solo lugar, 100 % en tu dispositivo.**

[![Último release](https://img.shields.io/github/v/release/Maximiliano-Flores-Dev/anything-hub?include_prereleases&label=release&color=F05A3C)](https://github.com/Maximiliano-Flores-Dev/anything-hub/releases)
[![Build APK](https://github.com/Maximiliano-Flores-Dev/anything-hub/actions/workflows/build.yml/badge.svg)](https://github.com/Maximiliano-Flores-Dev/anything-hub/actions/workflows/build.yml)
[![Licencia: MIT](https://img.shields.io/badge/licencia-MIT-F2B531.svg)](LICENSE)
![Plataforma](https://img.shields.io/badge/plataforma-Android-3DDC84?logo=android&logoColor=white)
![Flutter](https://img.shields.io/badge/Flutter-Dart%203-02569B?logo=flutter&logoColor=white)
![Estado](https://img.shields.io/badge/estado-alpha-E0384C)

[**⬇️ Descargar APK**](https://github.com/Maximiliano-Flores-Dev/anything-hub/releases) ·
[Features](#-features) ·
[Estado del proyecto](#-estado-del-proyecto) ·
[Compilar](#-compilar-desde-el-código-fuente) ·
[Roadmap](#-roadmap)

</div>

---

## 🎯 Propósito

Tu teléfono tiene decenas de apps, enlaces sueltos, carpetas de proyectos y archivos repartidos por todas partes. **Anythings Hub nace para reunir todo eso en un único panel**, organizado por ti (y por tu uso real), sin depender de ningún servidor.

El proyecto se apoya en tres principios:

| Principio | Qué significa en la práctica |
|---|---|
| 🏠 **Local-first** | La configuración de la app declara `local_mode: true` y `telemetry_enabled: false`. El escaneo de apps, el orden por uso, los proyectos y los modos de rendimiento se procesan en el dispositivo. |
| 🛡️ **Soberanía del usuario** | La app informa y advierte (riesgo de un APK, permisos que se piden, limpieza de procesos), pero la decisión final siempre es tuya. |
| 🔌 **Modular y opt-in** | Los módulos sensibles (Proyectos, plugins) están desactivados hasta que tú los activas, y si los desinstalas **no dejan rastro** en disco. |

---

## ✨ Features

> Esta sección describe **solo lo que existe hoy en el código**. Lo que aún es parcial o está en desarrollo aparece marcado y detallado en [Estado del proyecto](#-estado-del-proyecto).

### 🧭 Dashboard principal
- Pantalla *mobile-first* con tema oscuro y paleta propia (fondo `#040A16`, acento pomelo `#F05A3C`).
- Cards con borde degradado que dan acceso a cada módulo: **Mis Aplicaciones**, **Carpetas del Proyecto**, **Webs Rápidas**, **Favoritos**, **Gestión de Archivos** y **Modos de Rendimiento**.
- **FAB radial** en el sidebar: *Nuevo Grupo*, *Añadir App*, *Escanear Apps* y *Ajustes*.
- **Navegación inferior** (bottom nav): Inicio · Grid (Mis Aplicaciones) · Buscar (Explorador) · Perfil (Configuración).

### 📱 Sidebar inteligente de apps
- Barra lateral **colapsable con gesto de swipe** y resorte que hereda la velocidad del dedo.
- **Categorías automáticas preestablecidas**: Agentes de IA, Gaming Hub, Social, Multimedia, Productividad, Mapas y Navegación, Noticias y Otras apps.
- **Ordenadas por uso frecuente** (tiempo en primer plano de los últimos días) usando el permiso *Acceso a datos de uso* de Android. Sin ese permiso, el orden es alfabético.
- **Grupos personalizados** creados por ti, con apps elegidas a mano y auto-ordenadas por uso.
- Vista **extendida**: las 4 apps más usadas de cada grupo en cuadrícula 2×2. Vista **encogida**: las 4 principales apiladas.
- Muestra los **íconos reales** de tus apps instaladas y **se ignora a sí misma** en el escaneo.
- Siempre con **consentimiento previo**: nada se escanea hasta que aceptas el diálogo de permiso.

### 📱 Mis Aplicaciones
- Cuadrícula densa de 4 columnas con pestañas **Todas / Favoritos**.
- Pantalla de gestión por app: **Lanzar**, abrir **Ajustes** del sistema, **Desinstalar** (con confirmación) y marcar como **favorita** (⭐).
- **Reseñas personales** (rendimiento y privacidad) guardadas únicamente en tu dispositivo.
- Bookmarks y reseñas persistidos con `shared_preferences` (local).

### 🌐 Webs Rápidas
- Lista vertical de tus sitios favoritos: avatar circular + título.
- Se abren en el **navegador nativo** del sistema (sin WebView embebido).
- **Crear, editar, eliminar y reordenar** (arrastrando) tus enlaces.
- Ícono automático desde el favicon del sitio o **imagen personalizada** a elección.
- Validación de URLs y persistencia local.

### 📁 Gestión de Archivos
- Explorador de almacenamiento interno con vista **lista o cuadrícula**.
- **Crear** carpetas y archivos, **renombrar**, **copiar**, **cortar/pegar**, **mover**, **eliminar** (recursivo) y **compartir**.
- **Buscar**, **filtrar por tipo**, mostrar **archivos ocultos** y **ordenar** (nombre, fecha o tamaño, ascendente o descendente).
- Selección múltiple, salto directo a una **ruta**, e **información de espacio** usado/libre (barra de almacenamiento).
- Favoritos de rutas y previsualización de archivos.
- Abre archivos con la app externa adecuada mediante `FileProvider`.

### ⚡ Modos de Rendimiento
- Cuatro modos nativos (sin root, best-effort):
  | Modo | Qué hace |
  |---|---|
  | **Equilibrado** | Sin cambios agresivos; el sistema gestiona con normalidad. |
  | **Eco** | Prioriza batería: cierra procesos en segundo plano innecesarios de apps de usuario. |
  | **Focus** | Silencia notificaciones de terceros (siguen visibles, sin sonido) vía *Acceso a No molestar* + limpieza de procesos. |
  | **Rendimiento** | Libera memoria cerrando solo procesos en segundo plano no críticos. |
- Panel de **memoria en tiempo real** (libres / total, indicador de memoria baja).
- Solo se tocan apps de usuario; **whitelist dura** de procesos del sistema (SystemUI, GMS, launcher, phone, settings, etc.).
- El SO puede limitar `killBackgroundProcesses`; la app informa cuántos procesos se intentaron y cuántos se trataron.
- Canal de notificaciones propio para Focus y permiso `POST_NOTIFICATIONS` (Android 13+) cuando aplica.

### 🔌 Plugins (metadatos locales)
- Catálogo remoto desde `plugins/catalog.json` del repositorio oficial (solo JSON).
- Instalación / desinstalación en `.anythinghub/plugins/` — **solo manifiestos y metadatos**, nunca ejecuta código remoto ni carga Dex/so dinámicos.
- Gestión desde la pestaña **Plugins** de Configuración.
- Ejemplo de uso: plugin de overlay FPS / juegos (opcional, no forma parte del núcleo).

### 🧑‍💻 Proyectos *(módulo opt-in para desarrolladores)*
- Se activa solo si tú lo aceptas, tras un aviso explícito, y crea la carpeta oculta `.anythinghub/`.
- Cada proyecto es un `project.md` (front-matter YAML + Markdown) con nombre, etiquetas, editor, ruta de Termux, lenguaje, comandos y notas.
- Integración con editores: **Acode**, **Markor**, **Termux** y **vscode.dev**.
- Ejecución de comandos en **Termux** mediante `RUN_COMMAND`.
- Inicio de sesión con **GitHub (OAuth 2.0 + PKCE)**; los tokens se guardan en almacenamiento seguro del sistema (`flutter_secure_storage`).
- **Documentación local** sin necesidad de red.
- **Desinstalación completa del módulo** con doble confirmación y garantía de aislamiento: módulo desactivado = cero rastro en disco.

### 🔬 Seguridad de APKs
- Anythings Hub se registra como destino de **“Abrir con”** y **“Compartir”** para archivos `.apk`.
- Copia el APK recibido a caché y muestra el origen (app que lo envió, cuando Android lo expone).
- Pantallas de **riesgo**, **soberanía de usuario** y **análisis complementario (hash SHA-256)**, con matriz de puntuación 0–100 basada en permisos críticos y trackers conocidos.
- **PuertoPipe**: tubo de descarga HTTPS por chunks a `cacheDir/puerto_limbo`, con progreso por eventos, validación de cabecera ZIP y SHA-256 al completar. No se ofrece instalar hasta que el archivo esté íntegro.
- Override de instalación siempre visible (la decisión final es del usuario).

### ⚙️ Configuración
- Pestaña **General**: ruta de `.anythinghub/`, notas de seguridad y acerca de.
- Pestaña **Plugins**: catálogo e instalados, instalar / desinstalar.
- Accesible desde la bottom nav (Perfil) y desde el FAB radial.

---

## 🚦 Estado del proyecto

**Fase actual: Alpha (`v1.0.x`).** Última release publicada: **v1.0.2**. La app es usable en el día a día para los módulos marcados como ✅; el resto está en construcción o experimental.

| Módulo / característica | Estado |
|---|:---:|
| Dashboard, tema y navegación (bottom nav) | ✅ Funcional |
| Sidebar: swipe, categorías y orden por uso | ✅ Funcional |
| Grupos personalizados | ✅ Funcional |
| FAB radial: *Nuevo Grupo*, *Añadir App*, *Escanear Apps* | ✅ Funcional |
| Mis Aplicaciones (lanzar, ajustes, desinstalar, favoritos, reseñas) | ✅ Funcional |
| Webs Rápidas | ✅ Funcional |
| Gestión de Archivos (multi-select, clipboard, filtros, storage bar, share…) | ✅ Funcional |
| Modos de Rendimiento (Eco / Focus / Rendimiento / memoria) | ✅ Funcional |
| Configuración (General + Plugins) | ✅ Funcional |
| Sistema de plugins (catálogo GitHub → metadatos locales) | ✅ Funcional |
| Proyectos (editores, Termux, `project.md`, aislamiento) | ✅ Funcional |
| Login con GitHub (OAuth + PKCE) | ✅ Implementado |
| Intercepción de APKs (Abrir con / Compartir) | ✅ Funcional |
| PuertoPipe (descarga HTTPS + SHA-256 + validación ZIP) | ✅ Funcional |
| Análisis de riesgo de APK (UI + matriz de puntuación) | 🧪 Experimental (parser nativo parcial) |
| Verificación de firma (oráculo + caché + *fail-closed*) | 🚧 UI de prototipo; backend pendiente |
| Card **Favoritos** del dashboard | 🚧 Pendiente (card visible, sin acción) |
| Acción **Ajustes** del FAB radial (ruta completa) | ✅ Cubierta por SettingsScreen vía bottom nav |
| API de VirusTotal | 🗓️ Planificado |

**Leyenda:** ✅ funcional · 🧪 experimental · 🚧 en construcción · 🗓️ planificado

### Descargas y versiones

Todas las versiones publicadas están en la pestaña de **Releases**:

👉 **<https://github.com/Maximiliano-Flores-Dev/anything-hub/releases>**

Cada release incluye un APK por arquitectura (`--split-per-abi`), generados automáticamente por GitHub Actions al publicar un tag `v*`.

| Si tu teléfono es… | Descarga el APK |
|---|---|
| Casi cualquier Android moderno (64 bits) | `arm64-v8a` |
| Android antiguo o de 32 bits | `armeabi-v7a` |
| Emulador o dispositivo x86 de 64 bits | `x86_64` |

> 💡 ¿No sabes cuál elegir? Prueba primero con `arm64-v8a`.

---

## 📲 Instalación

1. Abre la [pestaña de Releases](https://github.com/Maximiliano-Flores-Dev/anything-hub/releases) y descarga el APK que corresponda a tu dispositivo.
2. Si Android lo pide, permite **instalar apps de orígenes desconocidos** para tu navegador o gestor de archivos.
3. Abre el APK e instala.
4. Al abrir la app por primera vez, concede **solo los permisos de los módulos que vayas a usar** (ver abajo).

---

## 🔐 Permisos y privacidad

Anythings Hub pide permisos **solo cuando activas la función que los necesita**, y te explica para qué antes de enviarte a Ajustes.

| Permiso | Para qué se usa |
|---|---|
| `PACKAGE_USAGE_STATS` (Acceso a datos de uso) | Ordenar tus apps por uso frecuente. Opcional: sin él el orden es alfabético. |
| Consulta de apps instaladas (`queries`) | Listar y clasificar tus apps (Android 11+). |
| `MANAGE_EXTERNAL_STORAGE` (Acceso a todos los archivos) | Explorador de archivos. Solo se solicita al abrir ese módulo. |
| `REQUEST_INSTALL_PACKAGES` | Instalar APKs desde el hub. |
| `ACCESS_NOTIFICATION_POLICY` (Acceso a No molestar) | Modo Focus: silenciar notificaciones de terceros. |
| `POST_NOTIFICATIONS` (Android 13+) | Canal propio de avisos de rendimiento / Focus. |
| `INTERNET` | Login con GitHub, vscode.dev, favicons de Webs Rápidas, catálogo de plugins y PuertoPipe. |

**Lo que hay que saber con total transparencia:**
- No hay telemetría ni analítica propia (`telemetry_enabled: false`).
- El escaneo de apps, el orden por uso, los proyectos y los modos de rendimiento se procesan localmente; ningún dato de ellos sale del dispositivo.
- Los **favicons** de Webs Rápidas se obtienen de un servicio externo de favicons de Google (el dominio del sitio se envía en esa petición). Puedes evitarlo asignando una **imagen personalizada** a cada enlace.
- El inicio de sesión con GitHub y el catálogo de plugins se comunican con GitHub, por definición.
- Los plugins **solo descargan manifiestos JSON**; la app no ejecuta código remoto ni carga librerías dinámicas.

---

## 🧱 Arquitectura

Anythings Hub separa la **capa de interfaz (Flutter/Dart)** de la **capa de sistema (Kotlin)**, comunicadas por `MethodChannel`s propios y sin plugins nativos de terceros para esas tareas. Así, todo lo que toca el sistema operativo (apps instaladas, estadísticas de uso, archivos, instalación de APKs, Termux, rendimiento) está en un único lugar auditable.

```text
┌────────────────────────────────────────────────────────┐
│                  Flutter / Dart (UI)                    │
│  screens/  ui/sidebar  ui/widgets  modules/{apps,       │
│  projects, plugins}  core/ (paleta, modelos, logger)    │
└───────────────┬────────────────────────────────────────┘
                │ MethodChannel / EventChannel
                │  • anythings.hub/device_apps
                │  • anythings.hub/device_files
                │  • anythings.hub/performance
                │  • anythings.hub/puerto (+ events)
┌───────────────▼────────────────────────────────────────┐
│                Kotlin — MainActivity                    │
│  DeviceAppsBridge · DeviceFilesBridge ·                 │
│  PerformanceBridge · PuertoPipeBridge · TermuxHelper ·  │
│  ApkInspectHelper · UsageStatsManager · FileProvider    │
└────────────────────────────────────────────────────────┘
```

### Estructura del repositorio

```text
anything-hub/
├── lib/
│   ├── main.dart                  # Punto de entrada y tema
│   ├── core/                      # Paleta (HubColors), modelos y logger
│   ├── screens/                   # Dashboard, Webs, Explorador, Settings, Performance
│   ├── services/                  # Puente Dart ↔ Android (apps, archivos, perf, preview)
│   ├── ui/                        # Sidebar colapsable y widgets compartidos
│   └── modules/
│       ├── apps/                  # Mis Aplicaciones + seguridad de APKs
│       ├── projects/              # Módulo opt-in de proyectos (GitHub, Termux)
│       └── plugins/               # Catálogo e instalación de plugins (metadatos)
├── android/                       # Capa nativa Kotlin y manifiesto
├── assets/                        # Logo, imágenes y config.json
├── docs/                          # Notas de diseño, integración y big_update
├── test/                          # Tests unitarios y de widgets
└── .github/workflows/             # CI: build y release del APK
```

### Stack

| Capa | Tecnología |
|---|---|
| UI | Flutter (SDK Dart `>=3.0.0 <4.0.0`), Material 3 en tema oscuro |
| Nativo | Kotlin (`MethodChannel`, `EventChannel`, `UsageStatsManager`, `FileProvider`, `NotificationManager`) |
| Persistencia | `shared_preferences` · `flutter_secure_storage` · archivos locales (`.anythinghub/`) |
| Red y auth | `http` · `app_links` · `crypto` (PKCE + SHA-256) · `url_launcher` |
| CI/CD | GitHub Actions (JDK 17, Flutter stable) |

---

## 🛠️ Compilar desde el código fuente

**Requisitos:** Flutter (canal *stable*), JDK 17 y Android SDK.

```bash
# 1. Clonar
git clone https://github.com/Maximiliano-Flores-Dev/anything-hub.git
cd anything-hub

# 2. Dependencias
flutter pub get

# 3. Generar los íconos de la app
flutter pub run flutter_launcher_icons

# 4. Ejecutar en un dispositivo o emulador Android
flutter run

# 5. (Opcional) APKs de release, uno por arquitectura
flutter build apk --release --split-per-abi
```

Los APK quedan en `build/app/outputs/flutter-apk/`.

### Tests

```bash
flutter test
```

Actualmente cubren el *smoke test* de la app, el modelo `project.md` (ida y vuelta Markdown) y la configuración de OAuth de GitHub.

### Publicar un release

Los workflows de `.github/workflows/` compilan y publican los APK automáticamente al subir un tag con formato `v*`:

```bash
git tag v1.0.3
git push origin v1.0.3
```

---

## 🗺️ Roadmap

- [ ] Parser completo del manifiesto de APK (permisos, firma y hash SHA-256) integrado en el score de riesgo
- [ ] Verificación de firmas con caché local y política *fail-closed*
- [ ] Integración con la API de VirusTotal
- [ ] Card **Favoritos** funcional en el dashboard
- [ ] Más tests (sidebar, explorador de archivos, servicios nativos, modos de rendimiento)
- [ ] Capturas de pantalla y GIFs de demostración en este README
- [ ] Ampliar catálogo de plugins y documentación de manifiestos

---

## 🤝 Contribuir

Las ideas, los *issues* y los *pull requests* son bienvenidos.

1. Haz un *fork* del repositorio.
2. Crea tu rama: `git checkout -b feature/mi-mejora`.
3. Haz *commit* de tus cambios y abre un *Pull Request*.

Si encuentras un bug, abre un *issue* indicando tu modelo de teléfono, tu versión de Android y los pasos para reproducirlo.

---

## 📄 Licencia

Distribuido bajo la licencia **MIT**. Consulta el archivo [LICENSE](LICENSE) para más información.

© 2026 Maximiliano Flores

---

<div align="center">

Hecho con Flutter y mucho café por **[Maximiliano Flores](https://github.com/Maximiliano-Flores-Dev)**

</div>
