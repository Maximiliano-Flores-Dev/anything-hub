<div align="center">

<img src="assets/mylogo.png" alt="Anythings Hub" width="120" />

# Anythings Hub

**Tu centro de control personal para Android: apps, enlaces, archivos y proyectos en un solo lugar, 100 % en tu dispositivo.**

[![Último release](https://img.shields.io/github/v/release/Maximiliano-Flores-Dev/anything-hub?include_prereleases&label=release&color=F05A3C)](https://github.com/Maximiliano-Flores-Dev/anything-hub/releases)
[![Build APK](https://github.com/Maximiliano-Flores-Dev/anything-hub/actions/workflows/build_apk.yml/badge.svg)](https://github.com/Maximiliano-Flores-Dev/anything-hub/actions/workflows/build_apk.yml)
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
| 🏠 **Local-first** | La configuración de la app declara `local_mode: true` y `telemetry_enabled: false`. El escaneo de apps, el orden por uso y los proyectos se procesan en el dispositivo. |
| 🛡️ **Soberanía del usuario** | La app informa y advierte (riesgo de un APK, permisos que se piden), pero la decisión final siempre es tuya. |
| 🔌 **Modular y opt-in** | Los módulos sensibles (por ejemplo, Proyectos) están desactivados hasta que tú los activas, y si los desinstalas **no dejan rastro** en disco. |

---

## ✨ Features

> Esta sección describe **solo lo que existe hoy en el código**. Lo que aún es parcial o está en desarrollo aparece marcado y detallado en [Estado del proyecto](#-estado-del-proyecto).

### 🧭 Dashboard principal
- Pantalla *mobile-first* con tema oscuro y paleta propia (fondo `#040A16`, acento pomelo `#F05A3C`).
- Cards con borde degradado que dan acceso a cada módulo.
- **FAB radial**: mantén pulsado y arrastra hacia la acción que quieras — *Nuevo Grupo*, *Añadir App*, *Escanear Apps* y *Ajustes*.

### 📱 Sidebar inteligente de apps
- Barra lateral **colapsable con gesto de swipe** y resorte que hereda la velocidad del dedo.
- **Categorías automáticas preestablecidas**: Agentes de IA, Gaming Hub, Social, Multimedia, Productividad, Mapas y Navegación, Noticias y Otras apps.
- **Ordenadas por uso frecuente** (tiempo en primer plano de los últimos días) usando el permiso *Acceso a datos de uso* de Android. Sin ese permiso, el orden es alfabético.
- **Grupos personalizados** creados por ti, con apps elegidas a mano y auto-ordenadas por uso.
- Vista **extendida**: las 4 apps más usadas de cada grupo en cuadrícula 2×2. Vista **encogida**: las 4 principales apiladas.
- Muestra los **íconos reales** de tus apps instaladas y **se ignora a sí misma** en el escaneo.
- Siempre con **consentimiento previo**: nada se escanea hasta que aceptas el diálogo de permiso.

### 🗂️ Mis Aplicaciones
- Cuadrícula densa de 4 columnas con pestañas **Todas / Favoritos**.
- Pantalla de gestión por app: **Lanzar**, abrir **Ajustes** del sistema, **Desinstalar** (con confirmación) y marcar como **favorita** (⭐).
- **Reseñas personales** (rendimiento y privacidad) guardadas únicamente en tu dispositivo.

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
- Selección múltiple, salto directo a una **ruta**, e **información de espacio** usado/libre.
- Abre archivos con la app externa adecuada mediante `FileProvider`.

### 🧑‍💻 Proyectos *(módulo opt-in para desarrolladores)*
- Se activa solo si tú lo aceptas, tras un aviso explícito, y crea la carpeta oculta `.anythinghub/`.
- Cada proyecto es un `project.md` (front-matter YAML + Markdown) con nombre, etiquetas, editor, ruta de Termux, lenguaje, comandos y notas.
- Integración con editores: **Acode**, **Markor**, **Termux** y **vscode.dev**.
- Ejecución de comandos en **Termux** mediante `RUN_COMMAND`.
- Inicio de sesión con **GitHub (OAuth 2.0 + PKCE)**; los tokens se guardan en almacenamiento seguro del sistema (`flutter_secure_storage`).
- **Documentación local** sin necesidad de red.
- **Desinstalación completa del módulo** con doble confirmación y garantía de aislamiento: módulo desactivado = cero rastro en disco.

### 🔬 Seguridad de APKs *(en desarrollo, ver estado)*
- Anythings Hub se registra como destino de **"Abrir con"** y **"Compartir"** para archivos `.apk`.
- Copia el APK recibido a caché y muestra el origen (app que lo envió, cuando Android lo expone).
- Pantallas de **riesgo**, **soberanía de usuario** y **análisis complementario (hash SHA-256)**, con una matriz de puntuación 0–100 basada en permisos críticos y trackers conocidos.

---

## 🚦 Estado del proyecto

**Fase actual: Alpha (`v1.0.x`).** La app es usable en el día a día para los módulos marcados como ✅; el resto está en construcción.

| Módulo / característica | Estado |
|---|:---:|
| Dashboard, tema y navegación | ✅ Funcional |
| Sidebar: swipe, categorías y orden por uso | ✅ Funcional |
| Grupos personalizados | ✅ Funcional |
| FAB radial: *Nuevo Grupo*, *Añadir App*, *Escanear Apps* | ✅ Funcional |
| Mis Aplicaciones (lanzar, ajustes, desinstalar, favoritos, reseñas) | ✅ Funcional |
| Webs Rápidas | ✅ Funcional |
| Gestión de Archivos | ✅ Funcional |
| Proyectos (editores, Termux, `project.md`, aislamiento) | ✅ Funcional |
| Login con GitHub (OAuth + PKCE) | ✅ Implementado |
| Intercepción de APKs (Abrir con / Compartir) | 🧪 Experimental |
| Análisis de riesgo de APK | 🧪 Prototipo: la UI y la matriz de puntuación existen, pero el parseo real del manifiesto del APK está pendiente |
| Verificación de firma (oráculo + caché + *fail-closed*) | 🚧 UI de prototipo con datos simulados; el backend está pendiente |
| FAB radial → *Ajustes* | 🚧 Pendiente |
| Card **Favoritos** del dashboard | 🚧 Pendiente |
| Card **Modos de Rendimiento** | 🚧 Pendiente |
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
| `INTERNET` | Login con GitHub, vscode.dev y favicons de Webs Rápidas. |

**Lo que hay que saber con total transparencia:**
- No hay telemetría ni analítica propia (`telemetry_enabled: false`).
- El escaneo de apps, el orden por uso y los proyectos se procesan localmente; ningún dato de ellos sale del dispositivo.
- Los **favicons** de Webs Rápidas se obtienen de un servicio externo de favicons de Google (el dominio del sitio se envía en esa petición). Puedes evitarlo asignando una **imagen personalizada** a cada enlace.
- El inicio de sesión con GitHub se comunica con GitHub, por definición.

---

## 🧱 Arquitectura

Anythings Hub separa la **capa de interfaz (Flutter/Dart)** de la **capa de sistema (Kotlin)**, comunicadas por `MethodChannel`s propios y sin plugins nativos de terceros para esas tareas. Así, todo lo que toca el sistema operativo (apps instaladas, estadísticas de uso, archivos, instalación de APKs, Termux) está en un único lugar auditable.

```text
┌────────────────────────────────────────────────────────┐
│                  Flutter / Dart (UI)                    │
│  screens/  ui/sidebar  ui/widgets  modules/{apps,       │
│  projects}  core/ (paleta, modelos, logger)             │
└───────────────┬────────────────────────────────────────┘
                │ MethodChannel
                │  • anythings.hub/device_apps
                │  • anythings.hub/device_files
┌───────────────▼────────────────────────────────────────┐
│                Kotlin — MainActivity                    │
│  UsageStatsManager · PackageManager · FileProvider ·    │
│  Intents (VIEW/SEND/DELETE) · Termux RUN_COMMAND        │
└────────────────────────────────────────────────────────┘
```

### Estructura del repositorio

```text
anything-hub/
├── lib/
│   ├── main.dart                  # Punto de entrada y tema
│   ├── core/                      # Paleta (HubColors), modelos y logger
│   ├── screens/                   # Dashboard, Webs Rápidas, Explorador de archivos
│   ├── services/                  # Puente Dart ↔ Android (apps, archivos)
│   ├── ui/                        # Sidebar colapsable y widgets compartidos
│   └── modules/
│       ├── apps/                  # Mis Aplicaciones + seguridad de APKs
│       └── projects/              # Módulo opt-in de proyectos (GitHub, Termux)
├── android/                       # Capa nativa Kotlin y manifiesto
├── assets/                        # Logo, imágenes y config.json
├── docs/                          # Notas de diseño e integración
├── test/                          # Tests unitarios y de widgets
└── .github/workflows/             # CI: build y release del APK
```

### Stack

| Capa | Tecnología |
|---|---|
| UI | Flutter (SDK Dart `>=3.0.0 <4.0.0`), Material 3 en tema oscuro |
| Nativo | Kotlin (`MethodChannel`, `UsageStatsManager`, `FileProvider`) |
| Persistencia | `shared_preferences` · `flutter_secure_storage` · archivos locales |
| Red y auth | `http` · `app_links` · `crypto` (PKCE) · `url_launcher` |
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

El workflow `build_apk.yml` compila y publica los APK automáticamente al subir un tag con formato `v*`:

```bash
git tag v1.0.2
git push origin v1.0.2
```

---

## 🗺️ Roadmap

- [ ] Parser real del manifiesto de APK (permisos, firma y hash SHA-256)
- [ ] Verificación de firmas con caché local y política *fail-closed*
- [ ] Integración con la API de VirusTotal
- [ ] Card **Favoritos** funcional
- [ ] Card **Modos de Rendimiento** funcional
- [ ] Acción **Ajustes** del FAB radial
- [ ] Más tests (sidebar, explorador de archivos, servicios nativos)
- [ ] Capturas de pantalla y GIFs de demostración en este README

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
