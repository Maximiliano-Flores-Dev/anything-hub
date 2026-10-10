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
[Roadmap](#-roadmap) ·
[Compilar](#-compilar-desde-el-código-fuente)

</div>

---

## 🎯 Propósito

Tu teléfono tiene decenas de apps, enlaces sueltos, carpetas de proyectos y archivos repartidos por todas partes. **Anythings Hub nace para reunir todo eso en un único panel**, organizado por ti (y por tu uso real), sin depender de ningún servidor.

El proyecto se apoya en tres principios:

| Principio | Qué significa en la práctica |
|---|---|
| 🏠 **Local-first** | La configuración de la app declara `local_mode: true` y `telemetry_enabled: false`. El escaneo de apps, el orden por uso, los proyectos, la personalización y los modos de rendimiento se procesan y guardan en el dispositivo. |
| 🛡️ **Soberanía del usuario** | La app informa y advierte (riesgo de un APK, permisos que se piden, limpieza de procesos), pero la decisión final siempre es tuya. |
| 🔌 **Modular y opt-in** | Los módulos sensibles (Proyectos, plugins) están desactivados hasta que tú los activas, y si los desinstalas **no dejan rastro** en disco. |

---

## ✨ Features

> Esta sección describe **solo lo que existe hoy en el código**. Lo que aún está pendiente aparece en [Estado del proyecto](#-estado-del-proyecto) y en el [Roadmap](#-roadmap).

### 🧭 Dashboard principal
- Pantalla *mobile-first* con tema oscuro. La paleta por defecto (**Clásico**) usa fondo `#040A16` y acento pomelo `#F05A3C`, y ahora puedes cambiarla (ver [Personalización](#-personalización)).
- Cards con borde degradado que dan acceso a cada módulo: **Mis Aplicaciones**, **Carpetas del Proyecto**, **Webs Rápidas**, **Gestión de Archivos** y **Modos de Rendimiento**. La card **Favoritos** ya existe en pantalla, pero todavía no abre nada.
- Botón degradado **Escanear Apps Reales** (pasa a *Apps Sincronizadas* una vez hecho el escaneo).
- **Navegación inferior** (bottom nav): Inicio · Grid (Mis Aplicaciones) · Buscar (Explorador de archivos) · Perfil (Configuración).

### 🎨 Personalización
Nueva pestaña **Personalización** dentro de Configuración (disponible desde `v1.0.7`). Todo se guarda localmente y se aplica al instante:
- **6 paletas de color**: Clásico, Océano, Bosque, Violeta, Atardecer y Mono. Cambian fondos, acentos, textos y degradados de toda la app.
- **Sidebar de apps** activable / desactivable.
- **Modo para zurdos**: espejo funcional que mueve el sidebar al lado derecho.
- **Cards del dashboard**: activa o desactiva cada una y **reordénalas arrastrando**. Siempre queda al menos una visible.
- **Restaurar valores por defecto** con un solo botón.

### 📱 Sidebar inteligente de apps
- Barra lateral **colapsable con gesto de swipe** y resorte que hereda la velocidad del dedo.
- **Categorías automáticas preestablecidas**: Agentes de IA, Gaming Hub, Social, Multimedia, Productividad, Mapas y Navegación, Noticias y Otras apps.
- **Ordenadas por uso frecuente** (tiempo en primer plano de los últimos días) con el permiso *Acceso a datos de uso* de Android. Sin ese permiso, el orden es alfabético.
- Vista **extendida**: las 4 apps más usadas de cada grupo en cuadrícula 2×2. Vista **encogida**: las 4 principales apiladas.
- Muestra los **íconos reales** de tus apps instaladas y **se ignora a sí misma** en el escaneo.
- Siempre con **consentimiento previo**: nada se escanea hasta que aceptas el diálogo de permiso.
- **FAB radial**: mantén pulsado y arrastra hacia una opción. Hoy ejecuta **Escanear Apps**; el resto de las opciones (*Nuevo Grupo*, *Añadir App*, *Ajustes*) aparecen en el menú pero aún no tienen acción (ver [Estado del proyecto](#-estado-del-proyecto)).
- **Grupos personalizados**: el modelo, el guardado local, el auto-orden por uso y el render con ícono de edición ya existen en el código; la interfaz para **crearlos y editarlos** está pendiente.

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
- **Miniaturas** de imágenes y **ícono real de los APK**, con caché de íconos.
- **Detalles de archivo** con hashes **MD5 / SHA-1** y **previsualización de texto**.
- Favoritos de rutas.
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
- Catálogo remoto desde `plugins/catalog.json` del repositorio oficial (solo JSON), con **4 plugins** de ejemplo: filtros extra de archivos, etiquetas de riesgo de APK en español, plantillas básicas de proyectos y overlay FPS / modo juegos.
- Los plugins pueden declarar `extendsFeature` y `capabilities` para indicar qué función del núcleo extienden (por ejemplo, `performance-modes`).
- Instalación / desinstalación en `.anythinghub/plugins/` — **solo manifiestos y metadatos**, nunca ejecuta código remoto ni carga Dex/so dinámicos.
- Gestión desde la pestaña **Plugins** de Configuración.

### 🧑‍💻 Proyectos *(módulo opt-in para desarrolladores)*
- Se activa solo si tú lo aceptas, tras un aviso explícito, y crea la carpeta oculta `.anythinghub/`.
- Cada proyecto es un `project.md` (front-matter YAML + Markdown) con nombre, etiquetas, editor, ruta de Termux, lenguaje, comandos y notas.
- Integración con editores: **Acode**, **Markor**, **Termux** y **vscode.dev**.
- Ejecución de comandos en **Termux** mediante `RUN_COMMAND`.
- Inicio de sesión con **GitHub (OAuth 2.0 + PKCE)**; los tokens se guardan en almacenamiento seguro del sistema (`flutter_secure_storage`).
- **Documentación local** sin necesidad de red.
- **Desinstalación completa del módulo** con doble confirmación y garantía de aislamiento: módulo desactivado = cero rastro en disco.

### 🔬 Seguridad de APKs
- Anythings Hub se registra como destino de **“Abrir con”** y **“Compartir”** para archivos `.apk`, y muestra el origen (app que lo envió, cuando Android lo expone).
- **Inspección nativa del APK** (Kotlin): paquete, versión, permisos declarados, ícono y **SHA-256 de los certificados de firma**.
- **Matriz de riesgo 0–100** basada en permisos críticos y trackers conocidos. Si el APK no se puede leer, el resultado es *fail-closed*: se marca como fallo de análisis con puntaje alto, nunca como riesgo bajo.
- **Verificación de firma local** (oráculo *fail-closed*): compara contra la app ya instalada o contra *pins* guardados localmente (caché de hasta 200 pins, 90 días de vigencia). Sin evidencia, nunca dice “verificado”.
- **Consulta a VirusTotal por hash** (opt-in): solo si tú guardas tu propia API key; se envía el hash SHA-256, **no el APK**.
- Pantallas de **riesgo**, **soberanía de usuario** y **análisis complementario**.
- Override de instalación siempre visible (la decisión final es del usuario).

### 🚪 Puerto de Software
- Descarga el último APK de un release público de GitHub.
- **PuertoPipe**: tubo de descarga HTTPS por chunks a `cacheDir/puerto_limbo`, con progreso por eventos, validación de cabecera ZIP y SHA-256 al completar.
- El APK pasa por el **limbo** antes de instalarse: se calcula el hash, se lee el manifiesto y, si hay clave, se consulta VirusTotal. No se ofrece instalar hasta que el archivo esté íntegro.

### 🧱 Seguridad reforzada (*Code Hardening*)
- **`PathSecurity`** (Kotlin): sandbox de rutas para las operaciones de archivos.
- **`FileOpGuard`**: límites de operaciones por lotes (máx. 100 elementos por operación y 200 operaciones por minuto).
- Copias y movimientos de archivos más seguros, con tests propios de reglas de rutas.
- **R8 / ProGuard** con minificación activada y **`NetworkSecurityConfig`**.
- **Logger con redacción** de datos sensibles.
- Tokens en almacenamiento cifrado (`EncryptedSharedPreferences` en Android).
- Pantalla de **auditoría de permisos**.

### ⚙️ Configuración
Tres pestañas:
- **General**: ruta de `.anythinghub/`, notas de seguridad y acerca de.
- **Personalización**: paletas, sidebar, modo zurdos y cards (ver [Personalización](#-personalización)).
- **Plugins**: catálogo e instalados, instalar / desinstalar.

Accesible desde la bottom nav (Perfil).

---

## 🚦 Estado del proyecto

**Fase actual: Alpha (`v1.0.x`).** Última versión etiquetada: **v1.0.7** (9 de octubre de 2026). La app es usable en el día a día para los módulos marcados como ✅.

| Módulo / característica | Estado |
|---|:---:|
| Dashboard, tema y navegación (bottom nav) | ✅ Funcional |
| **Personalización**: 6 paletas, sidebar on/off, modo zurdos, cards activables y reordenables | ✅ Funcional |
| Sidebar: swipe, categorías y orden por uso | ✅ Funcional |
| Sidebar: vistas 2×2 extendida y apilada encogida | ✅ Funcional |
| FAB radial: opción *Escanear Apps* | ✅ Funcional |
| FAB radial: opciones *Nuevo Grupo*, *Añadir App* y *Ajustes* | 🚧 Visibles, sin acción |
| Grupos personalizados (modelo, guardado y auto-orden por uso) | 🚧 Base lista; falta la interfaz para crearlos y editarlos |
| Mis Aplicaciones (lanzar, ajustes, desinstalar, favoritos, reseñas) | ✅ Funcional |
| Webs Rápidas | ✅ Funcional |
| Gestión de Archivos (multi-select, clipboard, filtros, miniaturas, hashes, preview) | ✅ Funcional |
| Modos de Rendimiento (Equilibrado / Eco / Focus / Rendimiento + memoria) | ✅ Funcional |
| Configuración (General + Personalización + Plugins) | ✅ Funcional |
| Sistema de plugins (catálogo GitHub → metadatos locales) | ✅ Funcional |
| Proyectos (editores, Termux, `project.md`, aislamiento) | ✅ Funcional |
| Login con GitHub (OAuth + PKCE) | ✅ Implementado |
| Intercepción de APKs (Abrir con / Compartir) | ✅ Funcional |
| Parser nativo de APK (permisos, firma, SHA-256, ícono) + score de riesgo | ✅ Funcional |
| Verificación de firma local (oráculo + caché + *fail-closed*) | ✅ Funcional |
| PuertoPipe y Puerto de Software (descarga HTTPS + SHA-256 + validación ZIP) | ✅ Funcional |
| Consulta a VirusTotal por hash (con API key propia) | ✅ Funcional (opt-in) |
| Subida de APKs a VirusTotal | 🗓️ No implementada (por diseño, no se sube el archivo) |
| Hardening de seguridad (PathSecurity, FileOpGuard, R8, logger) | ✅ Funcional |
| Releases firmadas, con checksums y atestación de procedencia | ✅ Funcional |
| Card **Favoritos** del dashboard | 🚧 Pendiente (card visible, sin acción) |

**Leyenda:** ✅ funcional · 🚧 en construcción · 🗓️ planificado

### Descargas y versiones

Todas las versiones publicadas están en la pestaña de **Releases**:

👉 **<https://github.com/Maximiliano-Flores-Dev/anything-hub/releases>**

Cada release incluye un APK por arquitectura (`--split-per-abi`), firmado y generado automáticamente por GitHub Actions, junto con un archivo `SHA256SUMS.txt` para verificar la integridad de la descarga.

| Si tu teléfono es… | Descarga el APK |
|---|---|
| Casi cualquier Android moderno (64 bits) | `arm64-v8a` |
| Android antiguo o de 32 bits | `armeabi-v7a` |
| Emulador o dispositivo x86 de 64 bits | `x86_64` |

> 💡 ¿No sabes cuál elegir? Prueba primero con `arm64-v8a`.

### Historial de versiones

| Versión | Fecha | Hito principal |
|---|---|---|
| `v1.0.0` | 2026-10-02 | Primera release Alpha: build de APK, íconos propios y nombre de la app |
| `v1.0.1` | 2026-10-04 | Modularización del `main.dart` monolítico (sidebar y servicios extraídos) |
| `v1.0.2` | 2026-10-05 | Inspección nativa de APK, score de riesgo dinámico y recepción de APKs (Abrir con / Compartir) |
| `v1.0.3` | 2026-10-06 | Estabilización de CI: workflows de build y release |
| `v1.0.4` | 2026-10-07 | Puente nativo de Modos de Rendimiento y permisos de notificaciones para Focus |
| `v1.0.5` | 2026-10-07 | Mismo código que `v1.0.4` (el tag apunta al mismo commit) |
| `v1.0.6` | 2026-10-07 | `MainActivity` dividida en puentes Kotlin y **Puerto de Software** vía limbo |
| `v1.0.7` | 2026-10-09 | *Code Hardening* (`PathSecurity`, `FileOpGuard`, minificación) y **Personalización**: paletas, modo zurdos, sidebar y cards configurables |

> El detalle de cada versión está en sus [notas de release](https://github.com/Maximiliano-Flores-Dev/anything-hub/releases).

---

## 🗺️ Roadmap

### ✅ Cumplido

- [x] **Personalización macro** (`v1.0.7`): 6 paletas, sidebar on/off, modo zurdos y cards activables y reordenables, con persistencia local y tests propios.
- [x] **Parser del manifiesto de APK** (permisos, firma y hash SHA-256) integrado en el score de riesgo, con comportamiento *fail-closed* cuando el APK no se puede leer.
- [x] **Verificación de firmas** con caché local de pins y política *fail-closed* (nunca declara “verificado” sin evidencia).
- [x] **Integración con VirusTotal** por hash, opt-in y con la API key del usuario.
- [x] **Ampliar el catálogo de plugins**: 4 plugins, con `extendsFeature` y `capabilities`, y documentación del catálogo en `plugins/README.md`.
- [x] **Más tests**: reglas de rutas (`PathSecurity`), `FileOpGuard`, oráculo de firmas, modelo `project.md`, configuración OAuth de GitHub, paletas y `MacroCustomization`, además del *smoke test*.
- [x] **Releases semiautomáticas**: workflow manual con incremento `patch` / `minor` / `major`, modo `dry-run`, versionado calculado desde los tags, APK firmados, `SHA256SUMS.txt` y atestación de procedencia.
- [x] **CI de build y release**: formato, `flutter analyze` y tests se ejecutan en cada push y PR (hoy como avisos, sin bloquear el build), y los APK se compilan por arquitectura con **verificación de firma** obligatoria (se aborta si un release queda firmado con la clave *debug*).
- [x] **Hardening de seguridad** (sandbox de rutas, límites de operaciones por lotes, R8, logger con redacción, almacenamiento cifrado).
- [x] **Puerto de Software** con descarga a través del limbo antes de instalar.
- [x] **Gestión de Archivos completa**: miniaturas, íconos de APK, hashes MD5 / SHA-1 y previsualización de texto.
- [x] **Modos de Rendimiento** con puente nativo, acceso a No molestar y permiso de notificaciones.
- [x] **Pantalla de Configuración** con pestañas General, Personalización y Plugins, y bottom nav con Perfil.
- [x] **Sidebar de grupos** con vistas 2×2 (extendido) y apilada (encogido).
- [x] **Refactor del código nativo** en puentes Kotlin separados (apps, archivos, rendimiento, PuertoPipe, Termux, inspección de APK) y del `main.dart` monolítico en módulos.

### 🚧 Pendiente

- [ ] Interfaz para **crear y editar grupos personalizados** (*Nuevo Grupo* del FAB radial)
- [ ] Acciones del FAB radial: **Añadir App** y **Ajustes**
- [ ] Card **Favoritos** funcional en el dashboard
- [ ] Más tests (sidebar, explorador de archivos completo, servicios nativos, modos de rendimiento)
- [ ] Hacer que formato, analyzer y tests **bloqueen** el build en CI (hoy solo avisan)
- [ ] Capturas de pantalla y GIFs de demostración en este README

---

## 📲 Instalación

1. Abre la [pestaña de Releases](https://github.com/Maximiliano-Flores-Dev/anything-hub/releases) y descarga el APK que corresponda a tu dispositivo.
2. (Opcional) Verifica la integridad con `sha256sum -c SHA256SUMS.txt`.
3. Si Android lo pide, permite **instalar apps de orígenes desconocidos** para tu navegador o gestor de archivos.
4. Abre el APK e instala.
5. Al abrir la app por primera vez, concede **solo los permisos de los módulos que vayas a usar** (ver abajo).

---

## 🔐 Permisos y privacidad

Anythings Hub pide permisos **solo cuando activas la función que los necesita**, y te explica para qué antes de enviarte a Ajustes.

| Permiso | Para qué se usa |
|---|---|
| `PACKAGE_USAGE_STATS` (Acceso a datos de uso) | Ordenar tus apps por uso frecuente. Opcional: sin él el orden es alfabético. |
| Consulta de apps instaladas (`queries`) | Listar y clasificar tus apps (Android 11+). |
| `MANAGE_EXTERNAL_STORAGE` (Acceso a todos los archivos) | Explorador de archivos. Solo se solicita al abrir ese módulo. |
| `REQUEST_INSTALL_PACKAGES` | Instalar APKs desde el hub. |
| `REQUEST_DELETE_PACKAGES` | Desinstalar apps desde Mis Aplicaciones. |
| `ACCESS_NOTIFICATION_POLICY` (Acceso a No molestar) | Modo Focus: silenciar notificaciones de terceros. |
| `KILL_BACKGROUND_PROCESSES` | Modos Eco, Focus y Rendimiento: cerrar procesos en segundo plano de apps de usuario. |
| `POST_NOTIFICATIONS` (Android 13+) | Canal propio de avisos de rendimiento / Focus. |
| `com.termux.permission.RUN_COMMAND` | Módulo Proyectos: ejecutar comandos en Termux. |
| `INTERNET` | Login con GitHub, vscode.dev, favicons de Webs Rápidas, catálogo de plugins, PuertoPipe y consulta a VirusTotal. |

**Lo que hay que saber con total transparencia:**
- No hay telemetría ni analítica propia (`telemetry_enabled: false`).
- El escaneo de apps, el orden por uso, los proyectos, la personalización y los modos de rendimiento se procesan localmente; ningún dato de ellos sale del dispositivo.
- Los **favicons** de Webs Rápidas se obtienen de un servicio externo de favicons de Google (el dominio del sitio se envía en esa petición). Puedes evitarlo asignando una **imagen personalizada** a cada enlace.
- El inicio de sesión con GitHub, el catálogo de plugins y el Puerto de Software se comunican con GitHub, por definición.
- La consulta a **VirusTotal** es opcional: solo ocurre si guardas tu propia API key, y se envía únicamente el **hash SHA-256**, nunca el APK.
- Los plugins **solo descargan manifiestos JSON**; la app no ejecuta código remoto ni carga librerías dinámicas.

---

## 🧱 Arquitectura

Anythings Hub separa la **capa de interfaz (Flutter/Dart)** de la **capa de sistema (Kotlin)**, comunicadas por `MethodChannel`s propios y sin plugins nativos de terceros para esas tareas. Así, todo lo que toca el sistema operativo (apps instaladas, estadísticas de uso, archivos, instalación de APKs, Termux, rendimiento) está en un único lugar auditable.

Los colores de la interfaz se leen de la paleta activa (`HubColors` → `MacroCustomization` → `HubPalette`), por lo que un cambio en Personalización se refleja en toda la app sin reiniciarla.

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
│  ApkInspectHelper · PathSecurity · FileProvider         │
└────────────────────────────────────────────────────────┘
```

### Estructura del repositorio

```text
anything-hub/
├── lib/
│   ├── main.dart                  # Punto de entrada y tema
│   ├── core/                      # Paletas, personalización, HubColors, modelos y logger
│   ├── screens/                   # Dashboard, Webs, Explorador, Settings, Personalización, Performance
│   ├── services/                  # Puente Dart ↔ Android (apps, archivos, perf, preview)
│   ├── ui/                        # Sidebar colapsable y widgets compartidos
│   └── modules/
│       ├── apps/                  # Mis Aplicaciones + seguridad de APKs + Puerto de Software
│       ├── projects/              # Módulo opt-in de proyectos (GitHub, Termux)
│       └── plugins/               # Catálogo e instalación de plugins (metadatos)
├── android/                       # Capa nativa Kotlin y manifiesto
├── plugins/                       # Catálogo oficial de plugins (catalog.json)
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
dart run flutter_launcher_icons

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

Cubren el *smoke test* de la app, el sandbox de rutas (`PathSecurity`), `FileOpGuard`, el oráculo de firmas, el modelo `project.md` (ida y vuelta Markdown), la configuración de OAuth de GitHub, las paletas (`HubPalettes`) y el estado de personalización (`MacroCustomization`: valores por defecto, persistencia, reordenamiento y restauración).

El workflow de CI (`build.yml`) ejecuta la verificación de formato, `flutter analyze` y `flutter test` en cada push y *pull request*. Por ahora estos pasos **reportan advertencias pero no bloquean el build**; lo que sí aborta el proceso es que el analyzer falle con un error grave, que no se genere ningún APK o que un release salga firmado con la clave *debug*.

### Publicar un release

Los releases se lanzan a mano desde **Actions → Release → Run workflow** en la rama principal:

1. Elige el tipo de incremento: `patch`, `minor` o `major`.
2. (Opcional) Activa `dry-run` para calcular la versión sin compilar ni publicar.
3. El workflow calcula la siguiente versión a partir de los tags `v*`, compila los APK por arquitectura con la firma de release, genera `SHA256SUMS.txt`, atesta la procedencia del build y publica el release en GitHub.
4. La publicación corre en el entorno `release`, que permite exigir una aprobación manual antes de salir.

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
