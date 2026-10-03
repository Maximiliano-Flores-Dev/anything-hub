import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

const double radius12 = 12.0;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: HubColors.fondoPrincipal,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const AnythingsHubApp());
}

// ============================================================================
// LOGGER
// ============================================================================
class SystemLogger {
  static void log(String message) {
    // ignore: avoid_print
    print('[AnythingsHub] $message');
  }
}

// ============================================================================
// PALETA DE COLORES
// ============================================================================
abstract final class HubColors {
  static const Color fondoPrincipal = Color(0xFF040A16);
  static const Color fondoSidebar = Color(0xFF0A121F);
  static const Color panel = Color(0xFF070D19);
  static const Color linea = Color(0xFF2B3342);
  static const Color lineaFooter = Color(0xFF2A2E39);

  static const Color pomelo = Color(0xFFF05A3C);
  static const Color pomeloSuave = Color(0xFFE8909F);
  static const Color amarillo = Color(0xFFF2B531);

  static const Color textoPrincipal = Color(0xFFFFFFFF);
  static const Color textoSecundario = Color(0xFF959BAA);
  static const Color textoAcento = Color(0xFF7C80C6);

  static const List<Color> _degradado = [Color(0xFFF9663A), Color(0xFFEC373E)];

  static const LinearGradient degradado = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: _degradado,
  );
  static const LinearGradient degradadoDiagonal = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: _degradado,
  );
  static const LinearGradient bordeCard = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xEEF2663A), Color(0xC0E0384C)],
  );
}

class AnythingsHubApp extends StatelessWidget {
  const AnythingsHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anythings Hub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: HubColors.fondoPrincipal,
        colorScheme: const ColorScheme(
          brightness: Brightness.dark,
          surface: HubColors.fondoPrincipal,
          onSurface: HubColors.textoPrincipal,
          primary: HubColors.pomelo,
          onPrimary: HubColors.fondoPrincipal,
          secondary: HubColors.panel,
          onSecondary: HubColors.textoPrincipal,
          error: Colors.redAccent,
          onError: Colors.white,
        ),
      ),
      home: const MainLayoutScreen(),
    );
  }
}

// ============================================================================
// MODELOS DE DATOS Y GESTIÓN DE PERMISOS / APPS REALES
// ============================================================================
class HubApp {
  HubApp(
    this.name, {
    required this.background,
    required this.foreground,
    this.icon,
    this.letter,
    this.iconBytes,
    this.packageName,
    this.category = 'other',
    this.usageScore = 0,
    this.isSystemScanned = false,
  });

  final String name;
  final Color background;
  final Color foreground;
  final IconData? icon;
  final String? letter;
  final Uint8List? iconBytes; // Ícono real de la app instalada (PNG)
  final String? packageName;
  final String category; // Id de categoría automática (ver kAutoCategories)
  int usageScore; // Minutos en primer plano dentro de la ventana analizada
  final bool isSystemScanned;
}

class AppGroup {
  AppGroup(this.label, this.apps, {this.isCustom = false, List<String>? packages})
      : packages = packages ?? <String>[];

  final String label;
  final List<HubApp> apps;
  final bool isCustom; // True si fue creado manualmente por el usuario
  final List<String> packages; // Membresía manual (solo grupos personalizados)

  void sortByUsage() {
    apps.sort((a, b) {
      final byUsage = b.usageScore.compareTo(a.usageScore);
      return byUsage != 0
          ? byUsage
          : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  }
}

// ============================================================================
// CATEGORÍAS AUTOMÁTICAS (PREESTABLECIDAS)
// ============================================================================
class AutoCategory {
  const AutoCategory(this.id, this.label);
  final String id;
  final String label;
}

const List<AutoCategory> kAutoCategories = [
  AutoCategory('ai', 'Agentes de IA'),
  AutoCategory('game', 'Gaming Hub'),
  AutoCategory('social', 'Social'),
  AutoCategory('media', 'Multimedia'),
  AutoCategory('productivity', 'Productividad'),
  AutoCategory('maps', 'Mapas y Navegación'),
  AutoCategory('news', 'Noticias'),
  AutoCategory('other', 'Otras apps'),
];

// Android no tiene una categoría "IA", así que se detecta por palabras clave
// en el package o el nombre. Edita esta lista a tu gusto.
const List<String> kAiKeywords = [
  'chatgpt', 'openai', 'claude', 'anthropic', 'gemini', 'copilot',
  'perplexity', 'deepseek', 'grok', 'mistral',
];

// ============================================================================
// PUENTE NATIVO ANDROID (MethodChannel propio, sin dependencias externas)
// ============================================================================
class DeviceAppInfo {
  const DeviceAppInfo({
    required this.packageName,
    required this.name,
    required this.category,
    required this.usageMinutes,
    this.icon,
  });

  final String packageName;
  final String name;
  final String category; // game, social, media, productivity, maps, news, undefined
  final int usageMinutes;
  final Uint8List? icon;
}

class DeviceAppsService {
  static const MethodChannel _ch = MethodChannel('anythings.hub/device_apps');

  static Future<T?> _call<T>(String method, [dynamic args]) async {
    try {
      return await _ch.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null; // Plataforma sin implementación nativa (iOS, web, escritorio)
    } on PlatformException catch (e) {
      SystemLogger.log('Canal nativo "$method" falló: ${e.message}');
      return null;
    }
  }

  static Future<String> selfPackage() async =>
      await _call<String>('selfPackage') ?? '';

  static Future<bool> hasUsageAccess() async =>
      await _call<bool>('hasUsageAccess') ?? false;

  static Future<void> openUsageAccessSettings() async {
    await _call<Object?>('openUsageAccessSettings');
  }

  static Future<bool> launch(String packageName) async =>
      await _call<bool>('launchApp', {'package': packageName}) ?? false;

  static Future<String?> loadState() => _call<String>('loadState');

  static Future<void> saveState(String json) async {
    await _call<Object?>('saveState', {'json': json});
  }

  /// Devuelve null si el escaneo no es posible en esta plataforma.
  static Future<List<DeviceAppInfo>?> listApps({int days = 14}) async {
    final raw = await _call<List<dynamic>>('listApps', {'days': days});
    if (raw == null) return null;
    return raw.whereType<Map>().map((m) {
      return DeviceAppInfo(
        packageName: m['package'] as String,
        name: m['name'] as String,
        category: (m['category'] as String?) ?? 'undefined',
        usageMinutes: ((m['usageMs'] as num?) ?? 0).toInt() ~/ 60000,
        icon: m['icon'] as Uint8List?,
      );
    }).toList();
  }
}

/// Decide a qué categoría automática pertenece una app real.
String classifyApp(DeviceAppInfo app) {
  final haystack = '${app.packageName} ${app.name}'.toLowerCase();
  if (kAiKeywords.any(haystack.contains)) return 'ai';
  final known = kAutoCategories.any((c) => c.id == app.category);
  return known ? app.category : 'other';
}

class RadialAction {
  const RadialAction(this.id, this.label, this.icon);
  final String id;
  final String label;
  final IconData icon;
}

const List<RadialAction> kFabActions = [
  RadialAction('folder', 'Nuevo Grupo', Icons.create_new_folder_outlined),
  RadialAction('add_app', 'Añadir App', Icons.add_to_photos_rounded),
  RadialAction('scan_device', 'Escanear Apps', Icons.radar_rounded),
  RadialAction('settings', 'Ajustes', Icons.settings_outlined),
];

class _CardData {
  const _CardData(this.title, this.subtitle, this.art);
  final String title;
  final String subtitle;
  final Widget art;
}

// ============================================================================
// PANTALLA PRINCIPAL
// ============================================================================
class MainLayoutScreen extends StatefulWidget {
  const MainLayoutScreen({super.key});

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen>
    with WidgetsBindingObserver {
  int _tab = 0;
  bool _deviceScanned = false;
  bool _consent = false; // El usuario aceptó que la app lea las apps instaladas
  bool _scanning = false;
  bool _awaitingUsageAccess = false; // Esperando que vuelva de Ajustes del sistema
  bool _usagePromptDismissed = false; // Rechazó el acceso de uso en esta sesión
  String _selfPackage = ''; // Lo entrega Android: nunca queda hardcodeado

  final Map<String, HubApp> _catalog = {}; // packageName → app real
  List<AppGroup> _appGroups = [];

  static const List<_CardData> _cards = [
    _CardData('Mis Aplicaciones', 'Gestiona, descarga y abre tus apps en un solo lugar', _AppsArt()),
    _CardData('Carpetas del Proyecto', 'Acceso rápido a tus proyectos', _SheetsArt()),
    _CardData('Webs Rápidas', 'Tus sitios favoritos, al instante', _WebArt()),
    _CardData('Favoritos', 'Todo lo que te importa', _FavoritesArt()),
    _CardData('Gestión de Archivos', 'Explora, organiza y accede rápido', _FilesArt()),
    _CardData('Modos de Rendimiento', 'Ajusta el rendimiento de tu dispositivo', _PerformanceArt()),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Al volver desde Ajustes → "Acceso a datos de uso", reescaneamos solos.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingUsageAccess) {
      _awaitingUsageAccess = false;
      _requestDeviceAppsAndScan(userInitiated: false);
    }
  }

  Future<void> _bootstrap() async {
    _selfPackage = await DeviceAppsService.selfPackage();
    await _loadState();
    if (_consent) await _requestDeviceAppsAndScan(userInitiated: false);
  }

  // ---------------------------------------------------------------- Persistencia
  Future<void> _loadState() async {
    final raw = await DeviceAppsService.loadState();
    if (raw == null) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final groups = (data['groups'] as List<dynamic>? ?? []).map((g) {
        final m = g as Map<String, dynamic>;
        return AppGroup(
          m['label'] as String,
          <HubApp>[],
          isCustom: true,
          packages: List<String>.from(m['packages'] as List<dynamic>? ?? []),
        );
      }).toList();
      if (!mounted) return;
      setState(() {
        _consent = data['consent'] == true;
        _appGroups = groups;
      });
    } catch (e) {
      SystemLogger.log('Estado guardado ilegible, se ignora: $e');
    }
  }

  Future<void> _saveState() {
    final json = jsonEncode({
      'consent': _consent,
      'groups': [
        for (final g in _appGroups.where((g) => g.isCustom))
          {'label': g.label, 'packages': g.packages},
      ],
    });
    return DeviceAppsService.saveState(json);
  }

  // ------------------------------------------------------------------- Grupos
  // Única fuente de verdad: catálogo real + membresías manuales → grupos.
  // Una app asignada a un grupo personalizado sale de su categoría automática.
  void _rebuildGroups() {
    final customs = _appGroups.where((g) => g.isCustom).toList();
    final claimed = <String>{for (final g in customs) ...g.packages};

    for (final g in customs) {
      g.apps
        ..clear()
        ..addAll(g.packages.map((p) => _catalog[p]).whereType<HubApp>());
      g.sortByUsage();
    }

    final autoGroups = <AppGroup>[];
    for (final c in kAutoCategories) {
      final apps = _catalog.values
          .where((a) => a.category == c.id && !claimed.contains(a.packageName))
          .toList();
      if (apps.isEmpty) continue;
      autoGroups.add(AppGroup(c.label, apps)..sortByUsage());
    }

    _appGroups = [...autoGroups, ...customs];
  }

  // ------------------------------------------------------------------ Permisos
  Future<bool> _confirmDialog({
    required String title,
    required String body,
    required String confirmLabel,
    String cancelLabel = 'Ahora no',
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HubColors.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(color: HubColors.textoPrincipal)),
        content: Text(
          body,
          style: const TextStyle(color: HubColors.textoSecundario, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelLabel, style: const TextStyle(color: HubColors.textoSecundario)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: HubColors.pomelo),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: HubColors.panel,
        content: Text(message, style: const TextStyle(color: HubColors.textoPrincipal)),
      ),
    );
  }

  // Flujo: 1) consentimiento propio  2) acceso de uso (permiso especial de
  // Android, se concede en Ajustes)  3) lectura de apps  4) clasificación.
  Future<void> _requestDeviceAppsAndScan({bool userInitiated = true}) async {
    if (_scanning) return;
    _scanning = true;
    try {
      if (!_consent) {
        if (!userInitiated) return;
        final accepted = await _confirmDialog(
          title: 'Permiso de Acceso a Apps',
          body: 'Anythings Hub necesita consultar las aplicaciones instaladas en tu dispositivo para clasificarlas por categorías. Todo se procesa en el dispositivo y no se envía a ningún servidor. La aplicación se ignora a sí misma.',
          confirmLabel: 'Permitir',
          cancelLabel: 'Cancelar',
        );
        if (!accepted || !mounted) return;
        _consent = true;
        await _saveState();
      }

      final usageOk = await DeviceAppsService.hasUsageAccess();
      if (!usageOk && userInitiated && !_usagePromptDismissed) {
        final goToSettings = await _confirmDialog(
          title: 'Acceso a datos de uso',
          body: 'Para ordenar tus apps por uso frecuente, Android requiere que actives "Acceso a datos de uso" para Anythings Hub en Ajustes. Te llevaré allí; al volver, el orden se actualiza solo. Sin este permiso se ordenan alfabéticamente.',
          confirmLabel: 'Abrir Ajustes',
        );
        if (!mounted) return;
        if (goToSettings) {
          _awaitingUsageAccess = true;
          await DeviceAppsService.openUsageAccessSettings();
          return;
        }
        _usagePromptDismissed = true;
      }

      final found = await DeviceAppsService.listApps();
      if (!mounted) return;
      if (found == null) {
        if (userInitiated) _toast('El escaneo de apps solo está disponible en Android.');
        return;
      }

      _catalog.clear();
      for (final d in found) {
        if (d.packageName == _selfPackage) continue; // Se ignora a sí misma
        _catalog[d.packageName] = HubApp(
          d.name,
          background: HubColors.panel,
          foreground: HubColors.textoPrincipal,
          letter: d.name.isNotEmpty ? d.name[0].toUpperCase() : '?',
          iconBytes: d.icon,
          packageName: d.packageName,
          category: classifyApp(d),
          usageScore: d.usageMinutes,
          isSystemScanned: true,
        );
      }

      setState(() {
        _rebuildGroups();
        _deviceScanned = true;
      });

      SystemLogger.log('Escaneo completado: ${_catalog.length} apps (propia ignorada: $_selfPackage).');
      _toast(usageOk
          ? 'Apps sincronizadas y ordenadas por uso.'
          : 'Apps sincronizadas (sin acceso de uso: orden alfabético).');
    } finally {
      _scanning = false;
    }
  }

  void _launchApp(HubApp app) {
    final pkg = app.packageName;
    if (pkg != null) DeviceAppsService.launch(pkg);
  }

  void _onFabAction(RadialAction action) {
    SystemLogger.log('FAB → ${action.id}');
    if (action.id == 'folder') {
      _showCreateGroupDialog();
    } else if (action.id == 'add_app') {
      _showAddAppDialog();
    } else if (action.id == 'scan_device') {
      _requestDeviceAppsAndScan();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: HubColors.panel,
          content: Text('${action.label}: acción ejecutada', style: const TextStyle(color: HubColors.textoPrincipal)),
        ),
      );
    }
  }

  void _showCreateGroupDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HubColors.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Crear Grupo Personalizado', style: TextStyle(color: HubColors.textoPrincipal)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: HubColors.textoPrincipal),
          decoration: const InputDecoration(
            hintText: 'Ej. Mis Utilidades',
            hintStyle: TextStyle(color: HubColors.textoSecundario),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: HubColors.linea)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: HubColors.pomelo)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: HubColors.textoSecundario)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: HubColors.pomelo),
            onPressed: () {
              final name = controller.text.trim();
              final duplicated = _appGroups.any((g) => g.label.toLowerCase() == name.toLowerCase());
              if (name.isNotEmpty && !duplicated) {
                setState(() => _appGroups.add(AppGroup(name, <HubApp>[], isCustom: true)));
                _saveState();
                Navigator.pop(ctx);
                SystemLogger.log('Grupo personalizado creado: $name');
              }
            },
            child: const Text('Crear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddAppDialog() {
    final customGroups = _appGroups.where((g) => g.isCustom).toList();
    if (customGroups.isEmpty) {
      _showCreateGroupDialog();
      return;
    }
    if (_catalog.isEmpty) {
      _toast('Primero escanea las apps del dispositivo.');
      _requestDeviceAppsAndScan();
      return;
    }

    var group = customGroups.first;
    final selected = <String>{...group.packages};
    final candidates = _catalog.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: HubColors.panel,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Apps del Grupo', style: TextStyle(color: HubColors.textoPrincipal)),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.sizeOf(context).height * 0.55,
            child: Column(
              children: [
                DropdownButtonFormField<AppGroup>(
                  value: group,
                  dropdownColor: HubColors.panel,
                  items: customGroups
                      .map((g) => DropdownMenuItem(
                            value: g,
                            child: Text(g.label, style: const TextStyle(color: HubColors.textoPrincipal)),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val == null) return;
                    setDialogState(() {
                      group = val;
                      selected
                        ..clear()
                        ..addAll(val.packages);
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: 'Seleccionar Grupo',
                    labelStyle: TextStyle(color: HubColors.textoSecundario),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: HubColors.linea)),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: candidates.length,
                    itemBuilder: (_, i) {
                      final app = candidates[i];
                      final pkg = app.packageName!;
                      return CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        activeColor: HubColors.pomelo,
                        checkColor: HubColors.fondoPrincipal,
                        controlAffinity: ListTileControlAffinity.trailing,
                        value: selected.contains(pkg),
                        onChanged: (v) => setDialogState(() {
                          if (v == true) {
                            selected.add(pkg);
                          } else {
                            selected.remove(pkg);
                          }
                        }),
                        secondary: _AppAvatar(app: app, size: 32),
                        title: Text(
                          app.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: HubColors.textoPrincipal, fontSize: 13),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: HubColors.textoSecundario)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: HubColors.pomelo),
              onPressed: () {
                setState(() {
                  group.packages
                    ..clear()
                    ..addAll(selected);
                  _rebuildGroups(); // Re-ordena por uso y saca las apps de su categoría automática
                });
                _saveState();
                Navigator.pop(ctx);
                SystemLogger.log('Grupo "${group.label}" actualizado: ${selected.length} apps');
              },
              child: const Text('Guardar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    return Scaffold(
      backgroundColor: HubColors.fondoPrincipal,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CollapsibleSidebar(
              screenWidth: screenWidth,
              appGroups: _appGroups,
              onActionSelected: _onFabAction,
              onAppTap: _launchApp,
            ),
            Expanded(
              child: Column(
                children: [
                  Expanded(child: _buildContent()),
                  _BottomNav(
                    selected: _tab,
                    onSelected: (i) {
                      SystemLogger.log('Footer → tab $i');
                      setState(() => _tab = i);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Text(
                  'Anythings Hub',
                  style: TextStyle(
                    color: HubColors.textoPrincipal,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: 'Escanear Dispositivo',
                    onPressed: _requestDeviceAppsAndScan,
                    icon: const Icon(Icons.radar_rounded, color: HubColors.pomelo, size: 26),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Bienvenido de\nnuevo',
            style: TextStyle(
              color: HubColors.textoPrincipal,
              fontSize: 23,
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Sincronización inteligente de apps',
            style: TextStyle(color: HubColors.textoAcento, fontSize: 13),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _cards.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.04,
            ),
            itemBuilder: (context, i) {
              final c = _cards[i];
              return DashboardCard(
                title: c.title,
                subtitle: c.subtitle,
                art: c.art,
                onTap: () {
                  if (i == 0) {
                    _requestDeviceAppsAndScan();
                  } else {
                    SystemLogger.log('Card → ${c.title}');
                  }
                },
              );
            },
          ),
          const SizedBox(height: 18),
          Center(
            child: FractionallySizedBox(
              widthFactor: 0.74,
              child: GradientPillButton(
                label: _deviceScanned ? 'Apps Sincronizadas' : 'Escanear Apps Reales',
                icon: Icons.sync_rounded,
                onPressed: _requestDeviceAppsAndScan,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Center(
            child: Text(
              'Orden automático por frecuencia de uso activo',
              style: TextStyle(color: HubColors.textoSecundario, fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// BOTÓN CON DEGRADADO
// ============================================================================
class GradientPillButton extends StatelessWidget {
  const GradientPillButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(999);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: HubColors.degradado,
        borderRadius: shape,
        boxShadow: [
          BoxShadow(
            color: HubColors.pomelo.withOpacity(0.28),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: shape,
          onTap: onPressed,
          child: SizedBox(
            height: 44,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 19, color: HubColors.fondoPrincipal),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: HubColors.fondoPrincipal,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// CARD CON BORDE DEGRADADO + TEXTO SIN TRUNCAR
// ============================================================================
class DashboardCard extends StatelessWidget {
  const DashboardCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.art,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Widget art;
  final VoidCallback onTap;

  static const double _borderWidth = 1.4;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius12),
        gradient: HubColors.bordeCard,
      ),
      child: Padding(
        padding: const EdgeInsets.all(_borderWidth),
        child: Material(
          color: HubColors.panel,
          borderRadius: BorderRadius.circular(radius12 - _borderWidth),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Center(child: art),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                title,
                                maxLines: 1,
                                style: const TextStyle(
                                  color: HubColors.textoPrincipal,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                  height: 1.15,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: HubColors.textoSecundario,
                                fontSize: 10.5,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.north_east_rounded,
                        size: 14,
                        color: HubColors.textoSecundario.withOpacity(0.8),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SIDEBAR + FAB RADIAL DINÁMICO
// ============================================================================
class CollapsibleSidebar extends StatefulWidget {
  const CollapsibleSidebar({
    super.key,
    required this.screenWidth,
    required this.appGroups,
    required this.onActionSelected,
    required this.onAppTap,
  });

  final double screenWidth;
  final List<AppGroup> appGroups;
  final ValueChanged<RadialAction> onActionSelected;
  final ValueChanged<HubApp> onAppTap;

  @override
  State<CollapsibleSidebar> createState() => _CollapsibleSidebarState();
}

class _CollapsibleSidebarState extends State<CollapsibleSidebar>
    with SingleTickerProviderStateMixin {
  static const double _minWidth = 64;
  static const double _maxWidthFactor = 0.72;

  // --- Sensibilidad del swipe (ajustables) ---
  // Distancia mínima en px antes de que el gesto sea reconocido como drag.
  // El default de Flutter es ~18 px: se siente "duro" y se pierde ese tramo.
  static const double _dragSlop = 4;
  // Velocidad (px/s) a partir de la cual el gesto cuenta como "lanzamiento".
  static const double _flingVelocity = 250;
  // Sin lanzamiento, se abre si pasó este porcentaje del recorrido.
  static const double _openThreshold = 0.35;

  late final AnimationController _controller;
  bool _isOpen = false;

  OverlayEntry? _overlayEntry;
  bool _menuOpen = false;
  Offset _pointer = Offset.zero;
  int? _hoveredIndex;

  double get _maxWidth => widget.screenWidth * _maxWidthFactor;
  double get _travel => _maxWidth - _minWidth;
  double get _currentWidth => _minWidth + _travel * _controller.value;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
  }

  @override
  void dispose() {
    _removeOverlay();
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    _settle(open: !_isOpen);
  }

  /// Anima hasta el estado final con un resorte que hereda la velocidad del dedo.
  void _settle({required bool open, double velocityPxPerSec = 0}) {
    _isOpen = open;
    final spring = SpringDescription.withDampingRatio(
      mass: 1,
      stiffness: 520,
      ratio: 1.0, // amortiguación crítica: sin rebote
    );
    _controller.animateWith(
      SpringSimulation(
        spring,
        _controller.value,
        open ? 1.0 : 0.0,
        velocityPxPerSec / _travel, // px/s -> unidades del controller por segundo
      ),
    );
  }

  void _onDragStart(DragStartDetails d) {
    // Si había una animación en curso, el dedo toma el control al instante.
    _controller.stop();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    final delta = d.primaryDelta;
    if (delta == null) return;
    // Seguimiento 1:1 con el dedo, sin depender de un ancho capturado en build.
    _controller.value = (_controller.value + delta / _travel).clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    final bool open = v.abs() > _flingVelocity
        ? v > 0 // la dirección del lanzamiento manda (también para cerrar)
        : _controller.value > _openThreshold;
    _settle(open: open, velocityPxPerSec: v);
  }

  void _openMenu(Offset globalPos) {
    if (_menuOpen) return;
    _menuOpen = true;
    _pointer = globalPos;
    _hoveredIndex = null;
    _overlayEntry = OverlayEntry(builder: (ctx) => _buildOverlay());
    Overlay.of(context).insert(_overlayEntry!);
    setState(() {});
  }

  void _updatePointer(Offset globalPos) {
    if (!_menuOpen) return;
    _pointer = globalPos;
    _hoveredIndex = _closestActionIndex(globalPos);
    _overlayEntry?.markNeedsBuild();
  }

  void _closeMenu({bool execute = false}) {
    if (!_menuOpen) return;
    final idx = _hoveredIndex;
    _removeOverlay();
    _menuOpen = false;
    _hoveredIndex = null;
    setState(() {});
    if (execute && idx != null) {
      widget.onActionSelected(kFabActions[idx]);
    }
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  int? _closestActionIndex(Offset globalPos) {
    final fabCenter = _fabGlobalCenter();
    if (fabCenter == null) return null;

    double bestDist = double.infinity;
    int? best;
    for (var i = 0; i < kFabActions.length; i++) {
      final pos = _actionPosition(fabCenter, i);
      final d = (pos - globalPos).distance;
      if (d < bestDist && d < 56) {
        bestDist = d;
        best = i;
      }
    }
    return best;
  }

  Offset? _fabGlobalCenter() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final local = Offset(_currentWidth / 2, box.size.height - 28 - 28);
    return box.localToGlobal(local);
  }

  Offset _actionPosition(Offset fabCenter, int index) {
    const baseRadius = 72.0;
    final angle = -math.pi / 2 + (index * 0.55);
    return Offset(
      fabCenter.dx + math.cos(angle) * baseRadius,
      fabCenter.dy + math.sin(angle) * baseRadius,
    );
  }

  Widget _buildOverlay() {
    final fabCenter = _fabGlobalCenter() ?? Offset.zero;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => _closeMenu(),
              behavior: HitTestBehavior.opaque,
              child: const ColoredBox(color: Color(0x66000000)),
            ),
          ),
          ...List.generate(kFabActions.length, (i) {
            final pos = _actionPosition(fabCenter, i);
            final selected = _hoveredIndex == i;
            final action = kFabActions[i];
            return Positioned(
              left: pos.dx - 22,
              top: pos.dy - 22,
              child: AnimatedScale(
                scale: selected ? 1.18 : 1.0,
                duration: const Duration(milliseconds: 120),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? HubColors.pomelo : HubColors.panel,
                    border: Border.all(
                      color: selected
                          ? HubColors.pomelo
                          : HubColors.linea.withOpacity(0.8),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.45),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    action.icon,
                    size: 20,
                    color: selected ? HubColors.fondoPrincipal : HubColors.textoPrincipal,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final w = _currentWidth;
        final progress = _controller.value;

        return RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: <Type, GestureRecognizerFactory>{
            HorizontalDragGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<HorizontalDragGestureRecognizer>(
              () => HorizontalDragGestureRecognizer(),
              (r) => r
                ..gestureSettings = const DeviceGestureSettings(touchSlop: _dragSlop)
                ..dragStartBehavior = DragStartBehavior.down
                ..onStart = _onDragStart
                ..onUpdate = _onDragUpdate
                ..onEnd = _onDragEnd
                ..onCancel = () => _settle(open: _controller.value > _openThreshold),
            ),
          },
          child: Container(
            width: w,
            color: HubColors.fondoSidebar,
            child: Column(
              children: [
                SizedBox(
                  height: 52,
                  child: progress > 0.55
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.grid_view_rounded, color: HubColors.pomelo, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Aplicaciones',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: HubColors.textoPrincipal.withOpacity(progress),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: _toggle,
                                icon: Icon(
                                  Icons.chevron_left_rounded,
                                  color: HubColors.textoSecundario.withOpacity(progress),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Center(
                          child: IconButton(
                            onPressed: _toggle,
                            icon: const Icon(Icons.menu_rounded, color: HubColors.textoSecundario),
                          ),
                        ),
                ),
                Divider(height: 1, color: HubColors.linea.withOpacity(0.6)),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: widget.appGroups.length,
                    itemBuilder: (context, gi) {
                      final group = widget.appGroups[gi];
                      return _SidebarGroupTile(
                        group: group,
                        progress: progress,
                        width: w,
                        onAppTap: widget.onAppTap,
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 18, top: 8),
                  child: _buildFab(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFab() {
    return Listener(
      onPointerDown: (e) {
        _openMenu(e.position);
      },
      onPointerMove: (e) {
        _updatePointer(e.position);
      },
      onPointerUp: (e) {
        _closeMenu(execute: true);
      },
      onPointerCancel: (_) {
        _closeMenu();
      },
      child: SizedBox(
        width: 56,
        height: 56,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: HubColors.degradadoDiagonal,
            boxShadow: [
              BoxShadow(
                color: HubColors.pomelo.withOpacity(0.45),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.add_rounded, color: Colors.white, size: 30),
          ),
        ),
      ),
    );
  }
}

class _SidebarGroupTile extends StatelessWidget {
  const _SidebarGroupTile({
    required this.group,
    required this.progress,
    required this.width,
    required this.onAppTap,
  });

  final AppGroup group;
  final double progress;
  final double width;
  final ValueChanged<HubApp> onAppTap;

  @override
  Widget build(BuildContext context) {
    // Las categorías automáticas vacías no se muestran; las personalizadas sí.
    if (group.apps.isEmpty && !group.isCustom) return const SizedBox.shrink();
    final showLabels = progress > 0.45;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showLabels)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 8, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      group.label,
                      style: TextStyle(
                        color: HubColors.textoSecundario.withOpacity(progress),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  if (group.isCustom)
                    Icon(Icons.edit_outlined, size: 12, color: HubColors.textoSecundario.withOpacity(progress)),
                ],
              ),
            ),
          ...group.apps.map((app) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onAppTap(app),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: showLabels ? 10 : 8,
                  vertical: 3,
                ),
                child: Row(
                  children: [
                    _AppAvatar(app: app, size: showLabels ? 34 : 40),
                    if (showLabels) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          app.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: HubColors.textoPrincipal.withOpacity(progress),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _AppAvatar extends StatelessWidget {
  const _AppAvatar({required this.app, required this.size});

  final HubApp app;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bytes = app.iconBytes;
    if (bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: app.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: app.letter != null
            ? Text(
                app.letter!,
                style: TextStyle(
                  color: app.foreground,
                  fontWeight: FontWeight.w800,
                  fontSize: size * 0.42,
                ),
              )
            : Icon(app.icon, color: app.foreground, size: size * 0.48),
      ),
    );
  }
}

// ============================================================================
// BOTTOM NAV
// ============================================================================
class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.selected,
    required this.onSelected,
  });

  final int selected;
  final ValueChanged<int> onSelected;

  static const _items = [
    (Icons.home_rounded, Icons.home_outlined, 'Inicio'),
    (Icons.grid_view_rounded, Icons.grid_view_outlined, 'Grid'),
    (Icons.search_rounded, Icons.search, 'Buscar'),
    (Icons.person_rounded, Icons.person_outline_rounded, 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: const BoxDecoration(
        color: HubColors.fondoPrincipal,
        border: Border(top: BorderSide(color: HubColors.lineaFooter, width: 0.8)),
      ),
      child: Row(
        children: List.generate(_items.length, (i) {
          final active = selected == i;
          final item = _items[i];
          return Expanded(
            child: InkWell(
              onTap: () => onSelected(i),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    active ? item.$1 : item.$2,
                    size: 24,
                    color: active ? HubColors.pomelo : HubColors.pomeloSuave,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.$3,
                    style: TextStyle(
                      fontSize: 10,
                      color: active ? HubColors.pomelo : HubColors.pomeloSuave,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ============================================================================
// ILUSTRACIONES VECTORIALES DE LAS CARDS
// ============================================================================
class _AppsArt extends StatelessWidget {
  const _AppsArt();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 68,
      child: Stack(
        children: [
          Positioned(left: 0, top: 12, child: _miniIcon(Icons.chat_bubble_outline, const Color(0xFF10A37F))),
          Positioned(left: 28, top: 0, child: _miniIcon(Icons.auto_awesome, const Color(0xFF6C8CFF))),
          Positioned(left: 56, top: 14, child: _miniIcon(Icons.smart_toy_outlined, const Color(0xFFD9774F))),
          Positioned(left: 18, top: 36, child: _miniIcon(Icons.apps, HubColors.pomelo)),
        ],
      ),
    );
  }

  Widget _miniIcon(IconData icon, Color color) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }
}

class _SheetsArt extends StatelessWidget {
  const _SheetsArt();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 64,
      child: Stack(
        children: [
          Positioned(
            left: 8,
            top: 8,
            child: _folder(const Color(0xFFF2B531), 48),
          ),
          Positioned(
            left: 22,
            top: 18,
            child: _folder(const Color(0xFFF05A3C), 44),
          ),
        ],
      ),
    );
  }

  Widget _folder(Color color, double size) {
    return Container(
      width: size,
      height: size * 0.78,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.7), width: 1.4),
      ),
      child: Align(
        alignment: Alignment.topLeft,
        child: Container(
          width: size * 0.42,
          height: 8,
          margin: const EdgeInsets.only(left: 4, top: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.55),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}

class _WebArt extends StatelessWidget {
  const _WebArt();

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.public_rounded, size: 48, color: Color(0xFF5B8DEF));
  }
}

class _FavoritesArt extends StatelessWidget {
  const _FavoritesArt();

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.favorite_rounded, size: 44, color: Color(0xFFE85D75));
  }
}

class _FilesArt extends StatelessWidget {
  const _FilesArt();

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.folder_copy_outlined, size: 46, color: Color(0xFFF2B531));
  }
}

class _PerformanceArt extends StatelessWidget {
  const _PerformanceArt();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 78,
      height: 52,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _chip('CPU', HubColors.pomelo),
          const SizedBox(width: 6),
          _chip('GPU', const Color(0xFF5B8DEF)),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}