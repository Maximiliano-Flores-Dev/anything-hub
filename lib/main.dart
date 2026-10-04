import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final WebLinkRepository _webLinks = WebLinkRepository();

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
    _webLinks.dispose();
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

  void _openWebLinks() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => WebLinksScreen(repository: _webLinks)),
    );
  }

  void _openFileExplorer() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const FileExplorerScreen()),
    );
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
                  } else if (i == 2) {
                    _openWebLinks(); // "Webs Rápidas"
                  } else if (i == 4) {
                    _openFileExplorer(); // "Gestión de Archivos"
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
                        onExpand: () => _settle(open: true),
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
    required this.onExpand,
  });

  final AppGroup group;
  final double progress;
  final double width;
  final ValueChanged<HubApp> onAppTap;
  final VoidCallback onExpand;

  static const int _maxShown = 4;
  // Tamaño fijo de cada logo en la cuadrícula (antes crecía con el sidebar).
  // Es el único valor que hay que tocar para hacerlos más grandes o pequeños.
  static const double _tileSize = 40;
  static const double _gap = 10;

  @override
  Widget build(BuildContext context) {
    // Las categorías automáticas vacías no se muestran; las personalizadas sí.
    if (group.apps.isEmpty && !group.isCustom) return const SizedBox.shrink();

    // group.apps ya llega ordenado por uso (AppGroup.sortByUsage): las cuatro
    // primeras son las más usadas y se recalculan solas en cada escaneo.
    final top = group.apps.take(_maxShown).toList();
    final expanded = progress > 0.5;

    // Fundido cruzado alrededor del punto medio: la pila se desvanece y la
    // cuadrícula aparece, sin saltos mientras el dedo arrastra el sidebar.
    final raw = expanded ? (progress - 0.5) * 2 : 1 - progress * 2;
    final opacity = math.max(0.0, math.min(1.0, raw));

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Opacity(
        opacity: opacity,
        child: expanded ? _buildGrid(context, top) : _buildStack(top),
      ),
    );
  }

  // Encogido: las apps no se pueden elegir una a una, así que tocar la pila
  // expande el sidebar.
  Widget _buildStack(List<HubApp> top) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onExpand,
      child: Center(child: _AppStackIcons(apps: top)),
    );
  }

  // Extendido: cuadrícula 2x2 alineada a la izquierda, con la etiqueta del
  // grupo ocupando todo el ancho. El tamaño del logo es fijo; solo se reduce si
  // el sidebar aún está tan estrecho (a mitad de la animación) que no cabría.
  Widget _buildGrid(BuildContext context, List<HubApp> top) {
    final tile = math.max(28.0, math.min(_tileSize, (width - 28 - _gap) / 2));
    final hidden = group.apps.length - top.length;

    Widget cell(int i) {
      if (i >= top.length) return SizedBox(width: tile, height: tile);
      final app = top[i];
      return Tooltip(
        message: app.name, // sin nombres en pantalla: mantén pulsado para verlo
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onAppTap(app),
          child: _AppAvatar(app: app, size: tile, radius: tile * 0.26),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel(context, hidden),
          if (top.isEmpty)
            const Padding(
              padding: EdgeInsets.only(left: 2, top: 2),
              child: Text(
                'Grupo vacío',
                style: TextStyle(color: HubColors.textoSecundario, fontSize: 12),
              ),
            )
          else ...[
            Row(children: [cell(0), const SizedBox(width: _gap), cell(1)]),
            if (top.length > 2) ...[
              const SizedBox(height: _gap),
              Row(children: [cell(2), const SizedBox(width: _gap), cell(3)]),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildLabel(BuildContext context, int hidden) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: hidden > 0 ? () => _showAll(context) : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 2, 0, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                group.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: HubColors.textoSecundario,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            if (group.isCustom)
              const Icon(Icons.edit_outlined, size: 12, color: HubColors.textoSecundario),
            if (hidden > 0) ...[
              const SizedBox(width: 6),
              Text(
                '+$hidden',
                style: const TextStyle(
                  color: HubColors.textoAcento,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 14, color: HubColors.textoAcento),
            ],
          ],
        ),
      ),
    );
  }

  // El sidebar solo muestra las 4 más usadas; el resto sigue accesible aquí.
  void _showAll(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: HubColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Text(
                  '${group.label} · ${group.apps.length}',
                  style: const TextStyle(
                    color: HubColors.textoPrincipal,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Flexible(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: group.apps.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.78,
                  ),
                  itemBuilder: (_, i) {
                    final app = group.apps[i];
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        Navigator.pop(ctx);
                        onAppTap(app);
                      },
                      child: Column(
                        children: [
                          _AppAvatar(app: app, size: 52, radius: 13),
                          const SizedBox(height: 6),
                          Text(
                            app.name,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: HubColors.textoSecundario,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pila de hasta 4 logos: el más usado al frente (abajo-izquierda) y los
/// demás detrás, asomando hacia arriba y la derecha, cada vez más oscuros.
class _AppStackIcons extends StatelessWidget {
  const _AppStackIcons({required this.apps, this.size = 36});

  final List<HubApp> apps;
  final double size;

  static const double _dx = 4; // cuánto asoma cada capa hacia la derecha
  static const double _dy = 4; // ...y hacia arriba
  static const List<double> _dim = [0, 0.28, 0.5, 0.68];

  @override
  Widget build(BuildContext context) {
    if (apps.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: HubColors.panel,
          borderRadius: BorderRadius.circular(size * 0.26),
          border: Border.all(color: HubColors.linea),
        ),
        child: Icon(Icons.folder_outlined, size: size * 0.5, color: HubColors.textoSecundario),
      );
    }

    final n = math.min(apps.length, _dim.length);
    final radius = size * 0.26;
    return SizedBox(
      width: size + (n - 1) * _dx,
      height: size + (n - 1) * _dy,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Del fondo al frente: la capa 0 (la más usada) se dibuja al final.
          for (var i = n - 1; i >= 0; i--)
            Positioned(
              left: i * _dx,
              top: (n - 1 - i) * _dy,
              child: Stack(
                children: [
                  _AppAvatar(app: apps[i], size: size, radius: radius),
                  if (i > 0)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: HubColors.fondoSidebar.withOpacity(_dim[i]),
                          borderRadius: BorderRadius.circular(radius),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AppAvatar extends StatelessWidget {
  const _AppAvatar({required this.app, required this.size, this.radius = 10});

  final HubApp app;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final bytes = app.iconBytes;
    if (bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
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
        borderRadius: BorderRadius.circular(radius),
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
// WEBS RÁPIDAS: GESTOR DE ENLACES MINIMALISTA
// ============================================================================

/// Una web guardada. [imagePath] es opcional:
///  - null / vacío → avatar automático (favicon de Google, derivado del dominio)
///  - ruta local   → imagen personalizada del dispositivo
///  - URL http(s)  → imagen remota personalizada
class WebLinkItem {
  const WebLinkItem({
    required this.id,
    required this.title,
    required this.url,
    this.imagePath,
  });

  final String id;
  final String title;
  final String url;
  final String? imagePath;

  String get host => Uri.tryParse(url)?.host ?? '';

  /// Endpoint ligero de favicons. sz=128 se reduce en memoria al tamaño del avatar.
  String get faviconUrl => 'https://www.google.com/s2/favicons?domain=$host&sz=128';

  WebLinkItem copyWith({String? title, String? url}) => WebLinkItem(
        id: id,
        title: title ?? this.title,
        url: url ?? this.url,
        imagePath: imagePath,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'url': url,
        if (imagePath != null) 'imagePath': imagePath,
      };

  /// Tolerante a datos corruptos: devuelve null en vez de lanzar.
  static WebLinkItem? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final title = raw['title'];
    final url = raw['url'];
    if (id is! String || title is! String || url is! String) return null;
    final img = raw['imagePath'];
    return WebLinkItem(
      id: id,
      title: title,
      url: url,
      imagePath: img is String ? img : null,
    );
  }

  /// UUID v4 sin dependencias externas.
  static String newId() {
    final r = math.Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0F) | 0x40; // versión 4
    b[8] = (b[8] & 0x3F) | 0x80; // variante RFC 4122
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
        '${h.substring(16, 20)}-${h.substring(20)}';
  }
}

/// Extrae título y URL de lo que el usuario pegue: "[Título](URL)", una URL
/// completa o un dominio suelto.
abstract final class WebLinkParser {
  static final RegExp _markdown = RegExp(r'^\s*\[([^\]]*)\]\(\s*([^)\s]+)\s*\)\s*$');
  static final RegExp _hasScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.\-]*://');

  static ({String? title, String raw}) parse(String input) {
    final m = _markdown.firstMatch(input);
    if (m == null) return (title: null, raw: input.trim());
    final t = m.group(1)!.trim();
    return (title: t.isEmpty ? null : t, raw: m.group(2)!.trim());
  }

  /// Devuelve una URL http(s) válida o null. Solo se aceptan http/https, así
  /// que esquemas como javascript: o file: quedan descartados.
  static String? normalizeUrl(String raw) {
    var s = raw.trim();
    if (s.isEmpty || s.contains(RegExp(r'\s'))) return null;
    if (!_hasScheme.hasMatch(s)) s = 'https://$s';
    final uri = Uri.tryParse(s);
    if (uri == null) return null;
    final okScheme = uri.scheme == 'http' || uri.scheme == 'https';
    final okHost = uri.host == 'localhost' || uri.host.contains('.');
    if (!okScheme || !okHost) return null;
    return uri.toString();
  }

  /// "https://www.youtube.com/..." → "Youtube"
  static String titleFromUrl(String url) {
    var host = Uri.tryParse(url)?.host ?? url;
    if (host.startsWith('www.')) host = host.substring(4);
    final label = host.split('.').first;
    if (label.isEmpty) return host;
    return label[0].toUpperCase() + label.substring(1);
  }
}

/// CRUD + orden persistente. Usa shared_preferences (ya declarado en pubspec)
/// en una clave propia, sin tocar el estado existente de grupos y permisos.
class WebLinkRepository extends ChangeNotifier {
  static const String _key = 'web_links_v1';

  final List<WebLinkItem> _items = [];
  bool _loaded = false;

  List<WebLinkItem> get items => List.unmodifiable(_items);
  bool get loaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        final list = jsonDecode(raw) as List<dynamic>;
        _items
          ..clear()
          ..addAll(list.map(WebLinkItem.tryFromJson).whereType<WebLinkItem>());
      }
    } catch (e) {
      SystemLogger.log('Webs Rápidas ilegibles, se ignoran: $e');
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(_items.map((e) => e.toJson()).toList()));
    } catch (e) {
      SystemLogger.log('No se pudo guardar Webs Rápidas: $e');
    }
  }

  Future<void> add(WebLinkItem item) async {
    _items.add(item);
    notifyListeners();
    await _persist();
  }

  Future<void> update(WebLinkItem item) async {
    final i = _items.indexWhere((e) => e.id == item.id);
    if (i < 0) return;
    _items[i] = item;
    notifyListeners();
    await _persist();
  }

  /// Devuelve la posición que ocupaba, para poder deshacer.
  Future<int> remove(String id) async {
    final i = _items.indexWhere((e) => e.id == id);
    if (i < 0) return -1;
    _items.removeAt(i);
    notifyListeners();
    await _persist();
    return i;
  }

  Future<void> restore(WebLinkItem item, int index) async {
    _items.insert(math.max(0, math.min(index, _items.length)), item);
    notifyListeners();
    await _persist();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1; // convención de ReorderableListView
    if (oldIndex == newIndex) return;
    final item = _items.removeAt(oldIndex);
    _items.insert(newIndex, item);
    notifyListeners();
    await _persist();
  }
}

// ------------------------------------------------------------------ Pantalla
class WebLinksScreen extends StatefulWidget {
  const WebLinksScreen({super.key, required this.repository});

  final WebLinkRepository repository;

  @override
  State<WebLinksScreen> createState() => _WebLinksScreenState();
}

class _WebLinksScreenState extends State<WebLinksScreen> {
  @override
  void initState() {
    super.initState();
    widget.repository.load();
  }

  void _toast(String message, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: HubColors.panel,
          action: action,
          content: Text(message, style: const TextStyle(color: HubColors.textoPrincipal)),
        ),
      );
  }

  // Delegamos al sistema: sin WebView embebido.
  Future<void> _open(WebLinkItem item) async {
    final uri = Uri.tryParse(item.url);
    if (uri == null || !uri.hasScheme) {
      _toast('El enlace de "${item.title}" no es válido.');
      return;
    }
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) _toast('No se pudo abrir "${item.title}".');
    } catch (e) {
      SystemLogger.log('launchUrl falló para ${item.url}: $e');
      if (mounted) _toast('No se pudo abrir "${item.title}".');
    }
  }

  Future<void> _addOrEdit([WebLinkItem? existing]) async {
    final result = await showDialog<_LinkEditorResult>(
      context: context,
      builder: (_) => _LinkEditorDialog(existing: existing),
    );
    if (result == null || !mounted) return;
    final repo = widget.repository;

    if (result.delete && existing != null) {
      final index = await repo.remove(existing.id);
      if (!mounted) return;
      _toast(
        '"${existing.title}" eliminada',
        action: SnackBarAction(
          label: 'Deshacer',
          textColor: HubColors.pomelo,
          onPressed: () => repo.restore(existing, index),
        ),
      );
    } else if (existing == null) {
      await repo.add(WebLinkItem(
        id: WebLinkItem.newId(),
        title: result.title!,
        url: result.url!,
      ));
    } else {
      await repo.update(existing.copyWith(title: result.title, url: result.url));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HubColors.fondoPrincipal,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SizedBox(
                height: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Text(
                      'Webs Rápidas',
                      style: TextStyle(
                        color: HubColors.textoPrincipal,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        tooltip: 'Volver',
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: HubColors.textoSecundario, size: 20),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        tooltip: 'Añadir web',
                        onPressed: () => _addOrEdit(),
                        icon: const Icon(Icons.add_rounded, color: HubColors.pomelo, size: 28),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: HubColors.linea.withOpacity(0.6)),
            Expanded(
              child: ListenableBuilder(
                listenable: widget.repository,
                builder: (context, _) => _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final repo = widget.repository;
    if (!repo.loaded) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2, color: HubColors.pomelo),
        ),
      );
    }

    final items = repo.items;
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.link_rounded, size: 40, color: HubColors.textoSecundario),
              const SizedBox(height: 12),
              const Text(
                'Aún no tienes webs guardadas',
                style: TextStyle(
                  color: HubColors.textoPrincipal,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Pega un enlace o un [Título](URL) y se abrirá en tu navegador.',
                textAlign: TextAlign.center,
                style: TextStyle(color: HubColors.textoSecundario, fontSize: 13),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 200,
                child: GradientPillButton(
                  label: 'Añadir web',
                  icon: Icons.add_rounded,
                  onPressed: () => _addOrEdit(),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            itemCount: items.length,
            onReorder: repo.reorder,
            proxyDecorator: (child, index, animation) => Material(
              color: HubColors.panel,
              elevation: 6,
              shadowColor: Colors.black,
              borderRadius: BorderRadius.circular(12),
              child: child,
            ),
            itemBuilder: (context, i) {
              final item = items[i];
              return _WebLinkTile(
                key: ValueKey(item.id),
                item: item,
                onOpen: () => _open(item),
                onEdit: () => _addOrEdit(item),
              );
            },
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 4, 24, 12),
          child: Text(
            'Toca el título para abrir · el ícono para editar · mantén pulsado para reordenar',
            textAlign: TextAlign.center,
            style: TextStyle(color: HubColors.textoSecundario, fontSize: 11.5),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Fila + avatar
class _WebLinkTile extends StatelessWidget {
  const _WebLinkTile({
    super.key,
    required this.item,
    required this.onOpen,
    required this.onEdit,
  });

  final WebLinkItem item;
  final VoidCallback onOpen;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkResponse(
          onTap: onEdit,
          radius: 26,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 7, 10, 7),
            child: _LinkAvatar(item: item),
          ),
        ),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onOpen,
            splashColor: HubColors.pomelo.withOpacity(0.12),
            highlightColor: HubColors.pomelo.withOpacity(0.06),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 6),
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: HubColors.textoPrincipal,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Avatar circular estricto. Si la imagen falla (sin red, dominio inválido,
/// archivo borrado) cae a una inicial con la paleta de la app.
class _LinkAvatar extends StatelessWidget {
  const _LinkAvatar({required this.item, this.size = 30});

  final WebLinkItem item;
  final double size;

  Widget _letter() {
    final t = item.title.trim();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: HubColors.panel,
        shape: BoxShape.circle,
        border: Border.all(color: HubColors.linea),
      ),
      child: Text(
        t.isEmpty ? '?' : t[0].toUpperCase(),
        style: TextStyle(
          color: HubColors.pomelo,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.45,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fallback = _letter();
    final custom = item.imagePath;
    final isRemoteCustom = custom != null && custom.startsWith('http');
    final isLocal = custom != null && custom.isNotEmpty && !isRemoteCustom;
    // Decodificar a tamaño real del avatar: memoria mínima aunque el origen sea 128 px.
    final px = (size * MediaQuery.devicePixelRatioOf(context)).round();

    Widget image;
    if (isLocal) {
      image = Image.file(
        File(custom!),
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: px,
        errorBuilder: (_, __, ___) => fallback,
      );
    } else if (isRemoteCustom || item.host.isNotEmpty) {
      image = Image.network(
        isRemoteCustom ? custom! : item.faviconUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: px,
        gaplessPlayback: true,
        loadingBuilder: (_, child, progress) => progress == null ? child : fallback,
        errorBuilder: (_, __, ___) => fallback,
      );
    } else {
      image = fallback;
    }

    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(child: image),
    );
  }
}

// ------------------------------------------------------------- Diálogo editor
class _LinkEditorResult {
  const _LinkEditorResult.save(this.title, this.url) : delete = false;
  const _LinkEditorResult.delete()
      : title = null,
        url = null,
        delete = true;

  final String? title;
  final String? url;
  final bool delete;
}

// StatefulWidget propio: los controllers se liberan en su dispose(), después de
// terminar la animación de cierre del diálogo.
class _LinkEditorDialog extends StatefulWidget {
  const _LinkEditorDialog({this.existing});

  final WebLinkItem? existing;

  @override
  State<_LinkEditorDialog> createState() => _LinkEditorDialogState();
}

class _LinkEditorDialogState extends State<_LinkEditorDialog> {
  late final TextEditingController _urlCtl;
  late final TextEditingController _titleCtl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _urlCtl = TextEditingController(text: widget.existing?.url ?? '');
    _titleCtl = TextEditingController(text: widget.existing?.title ?? '');
  }

  @override
  void dispose() {
    _urlCtl.dispose();
    _titleCtl.dispose();
    super.dispose();
  }

  void _submit() {
    final parsed = WebLinkParser.parse(_urlCtl.text);
    final url = WebLinkParser.normalizeUrl(parsed.raw);
    if (url == null) {
      setState(() => _error = 'Enlace no válido. Ejemplo: youtube.com');
      return;
    }
    final typed = _titleCtl.text.trim();
    final title = typed.isNotEmpty
        ? typed
        : (parsed.title ?? WebLinkParser.titleFromUrl(url));
    Navigator.pop(context, _LinkEditorResult.save(title, url));
  }

  InputDecoration _decoration(String label, String hint, {String? helper, String? error}) {
    const line = UnderlineInputBorder(borderSide: BorderSide(color: HubColors.linea));
    const focus = UnderlineInputBorder(borderSide: BorderSide(color: HubColors.pomelo));
    const warn = UnderlineInputBorder(borderSide: BorderSide(color: HubColors.pomeloSuave));
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      helperMaxLines: 2,
      errorText: error,
      labelStyle: const TextStyle(color: HubColors.textoSecundario),
      floatingLabelStyle: const TextStyle(color: HubColors.pomelo),
      hintStyle: TextStyle(color: HubColors.textoSecundario.withOpacity(0.6), fontSize: 13),
      helperStyle: const TextStyle(color: HubColors.textoSecundario, fontSize: 11),
      errorStyle: const TextStyle(color: HubColors.pomeloSuave),
      enabledBorder: line,
      focusedBorder: focus,
      errorBorder: warn,
      focusedErrorBorder: warn,
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return AlertDialog(
      backgroundColor: HubColors.panel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        editing ? 'Editar web' : 'Añadir web',
        style: const TextStyle(color: HubColors.textoPrincipal),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _urlCtl,
            autofocus: !editing,
            keyboardType: TextInputType.url,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.next,
            style: const TextStyle(color: HubColors.textoPrincipal),
            decoration: _decoration(
              'Enlace',
              'youtube.com',
              helper: 'También acepta [Título](https://…)',
              error: _error,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _titleCtl,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            style: const TextStyle(color: HubColors.textoPrincipal),
            decoration: _decoration('Título (opcional)', 'Se toma del enlace si lo dejas vacío'),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        if (editing)
          TextButton(
            onPressed: () => Navigator.pop(context, const _LinkEditorResult.delete()),
            child: const Text('Eliminar', style: TextStyle(color: HubColors.pomeloSuave)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: HubColors.textoSecundario)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: HubColors.pomelo),
          onPressed: _submit,
          child: const Text('Guardar', style: TextStyle(color: Colors.white)),
        ),
      ],
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

// ============================================================================
// SERVICIO DE ARCHIVOS (MethodChannel nativo) — versión completa
// ============================================================================
class FileEntry {
  const FileEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.size,
    required this.modifiedMs,
    this.extension = '',
  });

  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final int modifiedMs;
  final String extension;

  DateTime get modified => DateTime.fromMillisecondsSinceEpoch(modifiedMs);

  String get sizeLabel {
    if (isDirectory) return 'Carpeta';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  static FileEntry fromMap(Map m) => FileEntry(
        name: m['name'] as String,
        path: m['path'] as String,
        isDirectory: m['isDir'] == true,
        size: (m['size'] as num?)?.toInt() ?? 0,
        modifiedMs: (m['modified'] as num?)?.toInt() ?? 0,
        extension: (m['ext'] as String?) ?? '',
      );

  bool matchesType(_FileFilter filter) {
    if (filter == _FileFilter.all) return true;
    if (isDirectory) return filter == _FileFilter.folders;
    final e = extension.toLowerCase();
    switch (filter) {
      case _FileFilter.images:
        return const {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic', 'svg'}
            .contains(e);
      case _FileFilter.videos:
        return const {'mp4', 'mkv', 'avi', 'mov', 'webm', '3gp', 'flv'}.contains(e);
      case _FileFilter.audio:
        return const {'mp3', 'wav', 'flac', 'aac', 'ogg', 'm4a', 'wma'}.contains(e);
      case _FileFilter.documents:
        return const {
          'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'md', 'rtf', 'csv'
        }.contains(e);
      case _FileFilter.archives:
        return const {'zip', 'rar', '7z', 'tar', 'gz', 'bz2'}.contains(e);
      case _FileFilter.apks:
        return e == 'apk';
      case _FileFilter.folders:
        return false;
      case _FileFilter.all:
        return true;
    }
  }
}

class StorageInfo {
  const StorageInfo({required this.totalBytes, required this.freeBytes});
  final int totalBytes;
  final int freeBytes;
  int get usedBytes => totalBytes - freeBytes;
  double get usedRatio => totalBytes == 0 ? 0 : usedBytes / totalBytes;

  String get totalLabel => _fmt(totalBytes);
  String get freeLabel => _fmt(freeBytes);
  String get usedLabel => _fmt(usedBytes);

  static String _fmt(int b) {
    if (b < 1024 * 1024 * 1024) return '${(b / (1024 * 1024)).toStringAsFixed(0)} MB';
    return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

class DeviceFilesService {
  static const MethodChannel _ch = MethodChannel('anythings.hub/device_files');

  static Future<T?> _call<T>(String method, [dynamic args]) async {
    try {
      return await _ch.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      SystemLogger.log('Canal archivos "$method" falló: ${e.message}');
      return null;
    }
  }

  static Future<bool> hasPermission() async =>
      await _call<bool>('hasStoragePermission') ?? false;

  static Future<void> openPermissionSettings() async {
    await _call<Object?>('openStoragePermissionSettings');
  }

  static Future<List<Map<String, String>>> getRoots() async {
    final raw = await _call<List<dynamic>>('getRoots');
    if (raw == null) return [];
    return raw.whereType<Map>().map((m) => {
          'label': m['label'] as String? ?? '',
          'path': m['path'] as String? ?? '',
        }).toList();
  }

  static Future<StorageInfo?> getStorageInfo(String path) async {
    final raw = await _call<Map>('getStorageInfo', {'path': path});
    if (raw == null) return null;
    return StorageInfo(
      totalBytes: (raw['total'] as num?)?.toInt() ?? 0,
      freeBytes: (raw['free'] as num?)?.toInt() ?? 0,
    );
  }

  static Future<List<FileEntry>?> listDirectory(
    String path, {
    bool showHidden = false,
  }) async {
    final raw = await _call<List<dynamic>>('listDirectory', {
      'path': path,
      'showHidden': showHidden,
    });
    if (raw == null) return null;
    return raw.whereType<Map>().map(FileEntry.fromMap).toList();
  }

  static Future<bool> createDirectory(String path) async =>
      await _call<bool>('createDirectory', {'path': path}) ?? false;

  static Future<bool> createFile(String path) async =>
      await _call<bool>('createFile', {'path': path}) ?? false;

  static Future<bool> deleteEntry(String path) async =>
      await _call<bool>('delete', {'path': path}) ?? false;

  static Future<bool> renameEntry(String path, String newName) async =>
      await _call<bool>('rename', {'path': path, 'newName': newName}) ?? false;

  static Future<bool> copyEntry(String src, String dest) async =>
      await _call<bool>('copy', {'src': src, 'dest': dest}) ?? false;

  static Future<bool> moveEntry(String src, String dest) async =>
      await _call<bool>('move', {'src': src, 'dest': dest}) ?? false;

  static Future<bool> openFile(String path) async =>
      await _call<bool>('openFile', {'path': path}) ?? false;

  static Future<bool> shareFile(String path) async =>
      await _call<bool>('shareFile', {'path': path}) ?? false;
}

// ============================================================================
// EXPLORADOR DE ARCHIVOS COMPLETO
// ============================================================================
enum _SortMode { nameAsc, nameDesc, dateNewest, dateOldest, sizeLargest, sizeSmallest }
enum _ViewMode { list, grid }
enum _FileFilter { all, folders, images, videos, audio, documents, archives, apks }
enum _ClipMode { none, copy, cut }

class _ClipboardItem {
  const _ClipboardItem(this.entries, this.mode);
  final List<FileEntry> entries;
  final _ClipMode mode;
}

class FileExplorerScreen extends StatefulWidget {
  const FileExplorerScreen({super.key});

  @override
  State<FileExplorerScreen> createState() => _FileExplorerScreenState();
}

class _FileExplorerScreenState extends State<FileExplorerScreen>
    with WidgetsBindingObserver {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  List<Map<String, String>> _roots = [];
  String _currentPath = '';
  List<FileEntry> _entries = [];
  List<FileEntry> _filtered = [];
  bool _loading = true;
  bool _hasPermission = false;
  bool _searching = false;
  bool _showHidden = false;
  bool _selectionMode = false;
  String _searchQuery = '';
  _SortMode _sort = _SortMode.nameAsc;
  _ViewMode _view = _ViewMode.list;
  _FileFilter _filter = _FileFilter.all;
  final Set<String> _selected = {};
  _ClipboardItem? _clipboard;
  StorageInfo? _storageInfo;
  final List<String> _favorites = []; // paths
  bool _awaitingPermission = false;

  static const _favKey = 'file_explorer_favorites';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadFavorites();
    _bootstrap();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingPermission) {
      _awaitingPermission = false;
      _bootstrap();
    }
  }

  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_favKey) ?? [];
      if (mounted) setState(() => _favorites.addAll(list));
    } catch (_) {}
  }

  Future<void> _saveFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_favKey, _favorites);
    } catch (_) {}
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    _hasPermission = await DeviceFilesService.hasPermission();
    if (!_hasPermission) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    _roots = await DeviceFilesService.getRoots();
    if (_roots.isNotEmpty) {
      await _navigateTo(_roots.first['path']!);
    } else if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _requestPermission() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HubColors.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Acceso a archivos',
            style: TextStyle(color: HubColors.textoPrincipal)),
        content: const Text(
          'Para explorar y gestionar archivos del dispositivo, Anythings Hub necesita el permiso de "Acceso a todos los archivos". Te llevaré a Ajustes; actívalo y vuelve aquí.',
          style: TextStyle(color: HubColors.textoSecundario, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: HubColors.textoSecundario)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: HubColors.pomelo),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Abrir Ajustes',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (go == true) {
      _awaitingPermission = true;
      await DeviceFilesService.openPermissionSettings();
    }
  }

  Future<void> _navigateTo(String path) async {
    setState(() {
      _loading = true;
      _selected.clear();
      _selectionMode = false;
      _searchQuery = '';
      _searchCtrl.clear();
      _searching = false;
    });
    final list = await DeviceFilesService.listDirectory(
      path,
      showHidden: _showHidden,
    );
    final info = await DeviceFilesService.getStorageInfo(path);
    if (!mounted) return;
    if (list == null) {
      _toast('No se pudo leer la carpeta');
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _currentPath = path;
      _entries = list;
      _storageInfo = info;
      _applyFilterAndSort();
      _loading = false;
    });
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchCtrl.text.trim().toLowerCase();
      _applyFilterAndSort();
    });
  }

  void _applyFilterAndSort() {
    var list = List<FileEntry>.from(_entries);
    if (_searchQuery.isNotEmpty) {
      list = list
          .where((e) => e.name.toLowerCase().contains(_searchQuery))
          .toList();
    }
    list = list.where((e) => e.matchesType(_filter)).toList();
    list.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      switch (_sort) {
        case _SortMode.nameAsc:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case _SortMode.nameDesc:
          return b.name.toLowerCase().compareTo(a.name.toLowerCase());
        case _SortMode.dateNewest:
          return b.modifiedMs.compareTo(a.modifiedMs);
        case _SortMode.dateOldest:
          return a.modifiedMs.compareTo(b.modifiedMs);
        case _SortMode.sizeLargest:
          return b.size.compareTo(a.size);
        case _SortMode.sizeSmallest:
          return a.size.compareTo(b.size);
      }
    });
    _filtered = list;
  }

  List<String> get _breadcrumbs {
    if (_currentPath.isEmpty) return [];
    final parts = _currentPath.split('/').where((p) => p.isNotEmpty).toList();
    final crumbs = <String>[];
    var acc = '';
    for (final p in parts) {
      acc += '/$p';
      crumbs.add(acc);
    }
    return crumbs;
  }

  bool get _isFavorite => _favorites.contains(_currentPath);

  void _toast(String msg, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: HubColors.panel,
          action: action,
          content: Text(msg,
              style: const TextStyle(color: HubColors.textoPrincipal)),
        ),
      );
  }

  // ─── Acciones de creación ───────────────────────────────────────────────
  Future<void> _createFolder() async {
    final name = await _promptName('Nueva carpeta', 'Nombre de la carpeta');
    if (name == null || name.isEmpty) return;
    final full = '$_currentPath/$name';
    final ok = await DeviceFilesService.createDirectory(full);
    if (ok) {
      _toast('Carpeta creada');
      await _navigateTo(_currentPath);
    } else {
      _toast('No se pudo crear la carpeta');
    }
  }

  Future<void> _createFile() async {
    final name = await _promptName('Nuevo archivo', 'nombre.txt');
    if (name == null || name.isEmpty) return;
    final full = '$_currentPath/$name';
    final ok = await DeviceFilesService.createFile(full);
    if (ok) {
      _toast('Archivo creado');
      await _navigateTo(_currentPath);
    } else {
      _toast('No se pudo crear el archivo');
    }
  }

  Future<String?> _promptName(String title, String hint, {String initial = ''}) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HubColors.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(color: HubColors.textoPrincipal)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: HubColors.textoPrincipal),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: HubColors.textoSecundario),
            enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: HubColors.linea)),
            focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: HubColors.pomelo)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar',
                style: TextStyle(color: HubColors.textoSecundario)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: HubColors.pomelo),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Aceptar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ─── Renombrar / Eliminar ───────────────────────────────────────────────
  Future<void> _rename(FileEntry entry) async {
    final newName =
        await _promptName('Renombrar', entry.name, initial: entry.name);
    if (newName == null || newName.isEmpty || newName == entry.name) return;
    final ok = await DeviceFilesService.renameEntry(entry.path, newName);
    if (ok) {
      _toast('Renombrado');
      await _navigateTo(_currentPath);
    } else {
      _toast('No se pudo renombrar');
    }
  }

  Future<void> _deleteEntries(List<FileEntry> entries) async {
    if (entries.isEmpty) return;
    final label = entries.length == 1
        ? '"${entries.first.name}"'
        : '${entries.length} elementos';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HubColors.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Eliminar $label?',
            style: const TextStyle(color: HubColors.textoPrincipal)),
        content: Text(
          entries.any((e) => e.isDirectory)
              ? 'Se eliminarán carpetas y todo su contenido. Esta acción no se puede deshacer.'
              : 'Esta acción no se puede deshacer.',
          style: const TextStyle(color: HubColors.textoSecundario, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: HubColors.textoSecundario)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    var failed = 0;
    for (final e in entries) {
      final success = await DeviceFilesService.deleteEntry(e.path);
      if (!success) failed++;
    }
    if (failed == 0) {
      _toast('Eliminado');
    } else {
      _toast('$failed elemento(s) no se pudieron eliminar');
    }
    setState(() {
      _selected.clear();
      _selectionMode = false;
    });
    await _navigateTo(_currentPath);
  }

  // ─── Portapapeles ───────────────────────────────────────────────────────
  void _copySelected({required bool cut}) {
    final items = _entries.where((e) => _selected.contains(e.path)).toList();
    if (items.isEmpty) return;
    setState(() {
      _clipboard = _ClipboardItem(items, cut ? _ClipMode.cut : _ClipMode.copy);
      _selectionMode = false;
      _selected.clear();
    });
    _toast(cut
        ? '${items.length} recortado(s)'
        : '${items.length} copiado(s)');
  }

  Future<void> _paste() async {
    final clip = _clipboard;
    if (clip == null || clip.entries.isEmpty) return;
    setState(() => _loading = true);
    var failed = 0;
    for (final e in clip.entries) {
      final dest = '$_currentPath/${e.name}';
      final ok = clip.mode == _ClipMode.cut
          ? await DeviceFilesService.moveEntry(e.path, dest)
          : await DeviceFilesService.copyEntry(e.path, dest);
      if (!ok) failed++;
    }
    if (clip.mode == _ClipMode.cut) {
      setState(() => _clipboard = null);
    }
    if (failed == 0) {
      _toast(clip.mode == _ClipMode.cut ? 'Movido' : 'Copiado');
    } else {
      _toast('$failed operación(es) fallaron');
    }
    await _navigateTo(_currentPath);
  }

  // ─── Favoritos ──────────────────────────────────────────────────────────
  void _toggleFavorite() {
    setState(() {
      if (_isFavorite) {
        _favorites.remove(_currentPath);
        _toast('Eliminado de favoritos');
      } else {
        _favorites.add(_currentPath);
        _toast('Añadido a favoritos');
      }
    });
    _saveFavorites();
  }

  void _showFavorites() {
    if (_favorites.isEmpty) {
      _toast('No tienes carpetas favoritas');
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: HubColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: HubColors.linea,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Favoritos',
                  style: TextStyle(
                      color: HubColors.textoPrincipal,
                      fontWeight: FontWeight.w600,
                      fontSize: 16)),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _favorites.length,
                itemBuilder: (_, i) {
                  final path = _favorites[i];
                  final name = path.split('/').last;
                  return ListTile(
                    leading: const Icon(Icons.folder_special_rounded,
                        color: HubColors.amarillo),
                    title: Text(name,
                        style: const TextStyle(color: HubColors.textoPrincipal)),
                    subtitle: Text(path,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: HubColors.textoSecundario, fontSize: 11)),
                    trailing: IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: HubColors.textoSecundario, size: 18),
                      onPressed: () {
                        setState(() => _favorites.remove(path));
                        _saveFavorites();
                        Navigator.pop(ctx);
                        _showFavorites();
                      },
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _navigateTo(path);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ─── Ir a ruta ──────────────────────────────────────────────────────────
  Future<void> _goToPath() async {
    final path = await _promptName('Ir a ruta', '/storage/emulated/0',
        initial: _currentPath);
    if (path == null || path.isEmpty) return;
    await _navigateTo(path);
  }

  // ─── Menú contextual ────────────────────────────────────────────────────
  void _showContextMenu(FileEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: HubColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: HubColors.linea,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: HubColors.textoPrincipal,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (!entry.isDirectory)
                _sheetTile(Icons.open_in_new_rounded, 'Abrir', HubColors.pomelo,
                    () async {
                  Navigator.pop(ctx);
                  final ok = await DeviceFilesService.openFile(entry.path);
                  if (!ok && mounted) _toast('No se pudo abrir el archivo');
                }),
              if (!entry.isDirectory)
                _sheetTile(Icons.share_rounded, 'Compartir', HubColors.textoAcento,
                    () async {
                  Navigator.pop(ctx);
                  final ok = await DeviceFilesService.shareFile(entry.path);
                  if (!ok && mounted) _toast('No se pudo compartir');
                }),
              _sheetTile(Icons.drive_file_rename_outline_rounded, 'Renombrar',
                  HubColors.amarillo, () {
                Navigator.pop(ctx);
                _rename(entry);
              }),
              _sheetTile(Icons.content_copy_rounded, 'Copiar',
                  HubColors.textoSecundario, () {
                Navigator.pop(ctx);
                setState(() {
                  _selected
                    ..clear()
                    ..add(entry.path);
                  _copySelected(cut: false);
                });
              }),
              _sheetTile(Icons.content_cut_rounded, 'Cortar',
                  HubColors.textoSecundario, () {
                Navigator.pop(ctx);
                setState(() {
                  _selected
                    ..clear()
                    ..add(entry.path);
                  _copySelected(cut: true);
                });
              }),
              _sheetTile(Icons.delete_outline_rounded, 'Eliminar', Colors.redAccent,
                  () {
                Navigator.pop(ctx);
                _deleteEntries([entry]);
              }),
              _sheetTile(Icons.info_outline_rounded, 'Detalles',
                  HubColors.textoAcento, () {
                Navigator.pop(ctx);
                _showDetails(entry);
              }),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetTile(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: const TextStyle(color: HubColors.textoPrincipal)),
      onTap: onTap,
    );
  }

  void _showDetails(FileEntry entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HubColors.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(entry.name,
            style: const TextStyle(
                color: HubColors.textoPrincipal, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow(
                'Tipo',
                entry.isDirectory
                    ? 'Carpeta'
                    : (entry.extension.isEmpty
                        ? 'Archivo'
                        : entry.extension.toUpperCase())),
            _detailRow('Ruta', entry.path),
            if (!entry.isDirectory) _detailRow('Tamaño', entry.sizeLabel),
            _detailRow('Modificado', _formatDate(entry.modified)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Cerrar', style: TextStyle(color: HubColors.pomelo)),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(color: HubColors.textoSecundario, fontSize: 11)),
          const SizedBox(height: 2),
          Text(value,
              style:
                  const TextStyle(color: HubColors.textoPrincipal, fontSize: 13)),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  IconData _iconFor(FileEntry e) {
    if (e.isDirectory) return Icons.folder_rounded;
    final ext = e.extension.toLowerCase();
    if (const {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic', 'svg'}
        .contains(ext)) {
      return Icons.image_rounded;
    }
    if (const {'mp4', 'mkv', 'avi', 'mov', 'webm', '3gp'}.contains(ext)) {
      return Icons.movie_rounded;
    }
    if (const {'mp3', 'wav', 'flac', 'aac', 'ogg', 'm4a'}.contains(ext)) {
      return Icons.audiotrack_rounded;
    }
    if (ext == 'pdf') return Icons.picture_as_pdf_rounded;
    if (const {'doc', 'docx', 'txt', 'md', 'rtf'}.contains(ext)) {
      return Icons.description_rounded;
    }
    if (const {'xls', 'xlsx', 'csv'}.contains(ext)) {
      return Icons.table_chart_rounded;
    }
    if (const {'zip', 'rar', '7z', 'tar', 'gz'}.contains(ext)) {
      return Icons.folder_zip_rounded;
    }
    if (ext == 'apk') return Icons.android_rounded;
    return Icons.insert_drive_file_rounded;
  }

  Color _iconColor(FileEntry e) {
    if (e.isDirectory) return HubColors.amarillo;
    final ext = e.extension.toLowerCase();
    if (const {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic'}
        .contains(ext)) {
      return const Color(0xFF5B8DEF);
    }
    if (const {'mp4', 'mkv', 'avi', 'mov', 'webm'}.contains(ext)) {
      return const Color(0xFFE85D75);
    }
    if (const {'mp3', 'wav', 'flac', 'aac', 'ogg', 'm4a'}.contains(ext)) {
      return const Color(0xFF7C80C6);
    }
    if (ext == 'pdf') return Colors.redAccent;
    if (const {'zip', 'rar', '7z', 'tar', 'gz'}.contains(ext)) {
      return HubColors.pomelo;
    }
    if (ext == 'apk') return const Color(0xFF3DDC84);
    return HubColors.textoSecundario;
  }

  // ─── Menú + (crear) ─────────────────────────────────────────────────────
  void _showCreateMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: HubColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: HubColors.linea,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            _sheetTile(Icons.create_new_folder_rounded, 'Nueva carpeta',
                HubColors.amarillo, () {
              Navigator.pop(ctx);
              _createFolder();
            }),
            _sheetTile(Icons.note_add_rounded, 'Nuevo archivo de texto',
                HubColors.pomelo, () {
              Navigator.pop(ctx);
              _createFile();
            }),
            if (_clipboard != null)
              _sheetTile(Icons.paste_rounded, 'Pegar aquí', HubColors.textoAcento,
                  () {
                Navigator.pop(ctx);
                _paste();
              }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ─── Barra de selección ─────────────────────────────────────────────────
  Widget _buildSelectionBar() {
    return Container(
      color: HubColors.fondoSidebar,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Cancelar',
            onPressed: () => setState(() {
              _selectionMode = false;
              _selected.clear();
            }),
            icon: const Icon(Icons.close_rounded,
                color: HubColors.textoSecundario),
          ),
          Expanded(
            child: Text(
              '${_selected.length} seleccionado(s)',
              style: const TextStyle(
                  color: HubColors.textoPrincipal, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            tooltip: 'Seleccionar todo',
            onPressed: () => setState(() {
              if (_selected.length == _filtered.length) {
                _selected.clear();
              } else {
                _selected
                  ..clear()
                  ..addAll(_filtered.map((e) => e.path));
              }
            }),
            icon: Icon(
              _selected.length == _filtered.length
                  ? Icons.deselect_rounded
                  : Icons.select_all_rounded,
              color: HubColors.textoSecundario,
            ),
          ),
          IconButton(
            tooltip: 'Copiar',
            onPressed: () => _copySelected(cut: false),
            icon: const Icon(Icons.content_copy_rounded,
                color: HubColors.textoSecundario),
          ),
          IconButton(
            tooltip: 'Cortar',
            onPressed: () => _copySelected(cut: true),
            icon: const Icon(Icons.content_cut_rounded,
                color: HubColors.textoSecundario),
          ),
          IconButton(
            tooltip: 'Eliminar',
            onPressed: () {
              final items =
                  _entries.where((e) => _selected.contains(e.path)).toList();
              _deleteEntries(items);
            },
            icon: const Icon(Icons.delete_outline_rounded,
                color: Colors.redAccent),
          ),
        ],
      ),
    );
  }

  // ─── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HubColors.fondoPrincipal,
      body: SafeArea(
        child: Column(
          children: [
            if (_selectionMode) _buildSelectionBar() else _buildHeader(),
            if (_currentPath.isNotEmpty && !_searching && !_selectionMode)
              _buildBreadcrumbs(),
            if (_storageInfo != null && !_searching && !_selectionMode)
              _buildStorageBar(),
            if (!_selectionMode) _buildFilterChips(),
            Divider(height: 1, color: HubColors.linea.withOpacity(0.6)),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      floatingActionButton: _hasPermission && !_loading && !_selectionMode
          ? FloatingActionButton(
              onPressed: _showCreateMenu,
              backgroundColor: HubColors.pomelo,
              child: const Icon(Icons.add_rounded, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: SizedBox(
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: 'Volver',
                onPressed: () {
                  if (_searching) {
                    setState(() {
                      _searching = false;
                      _searchCtrl.clear();
                      _searchQuery = '';
                      _applyFilterAndSort();
                    });
                  } else if (_breadcrumbs.length > 1) {
                    _navigateTo(_breadcrumbs[_breadcrumbs.length - 2]);
                  } else {
                    Navigator.of(context).maybePop();
                  }
                },
                icon: Icon(
                  _searching
                      ? Icons.close_rounded
                      : Icons.arrow_back_ios_new_rounded,
                  color: HubColors.textoSecundario,
                  size: 20,
                ),
              ),
            ),
            if (!_searching)
              const Text(
                'Explorador',
                style: TextStyle(
                  color: HubColors.textoPrincipal,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(left: 48, right: 8),
                child: TextField(
                  controller: _searchCtrl,
                  focusNode: _searchFocus,
                  autofocus: true,
                  style: const TextStyle(
                      color: HubColors.textoPrincipal, fontSize: 16),
                  decoration: const InputDecoration(
                    hintText: 'Buscar archivos...',
                    hintStyle: TextStyle(color: HubColors.textoSecundario),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            if (!_searching)
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Buscar',
                      onPressed: () {
                        setState(() => _searching = true);
                        _searchFocus.requestFocus();
                      },
                      icon: const Icon(Icons.search_rounded,
                          color: HubColors.pomelo, size: 22),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Más opciones',
                      icon: const Icon(Icons.more_vert_rounded,
                          color: HubColors.textoSecundario, size: 22),
                      color: HubColors.panel,
                      onSelected: (v) {
                        switch (v) {
                          case 'sort':
                            _showSortMenu();
                            break;
                          case 'view':
                            setState(() => _view = _view == _ViewMode.list
                                ? _ViewMode.grid
                                : _ViewMode.list);
                            break;
                          case 'hidden':
                            setState(() => _showHidden = !_showHidden);
                            _navigateTo(_currentPath);
                            break;
                          case 'fav':
                            _toggleFavorite();
                            break;
                          case 'favs':
                            _showFavorites();
                            break;
                          case 'goto':
                            _goToPath();
                            break;
                          case 'refresh':
                            _navigateTo(_currentPath);
                            break;
                          case 'select':
                            setState(() => _selectionMode = true);
                            break;
                          case 'paste':
                            _paste();
                            break;
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'sort',
                          child: _menuRow(Icons.sort_rounded, 'Ordenar'),
                        ),
                        PopupMenuItem(
                          value: 'view',
                          child: _menuRow(
                            _view == _ViewMode.list
                                ? Icons.grid_view_rounded
                                : Icons.view_list_rounded,
                            _view == _ViewMode.list
                                ? 'Vista cuadrícula'
                                : 'Vista lista',
                          ),
                        ),
                        PopupMenuItem(
                          value: 'select',
                          child: _menuRow(
                              Icons.checklist_rounded, 'Seleccionar'),
                        ),
                        if (_clipboard != null)
                          PopupMenuItem(
                            value: 'paste',
                            child: _menuRow(Icons.paste_rounded, 'Pegar aquí'),
                          ),
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'hidden',
                          child: _menuRow(
                            _showHidden
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            _showHidden
                                ? 'Ocultar ocultos'
                                : 'Mostrar ocultos',
                          ),
                        ),
                        PopupMenuItem(
                          value: 'fav',
                          child: _menuRow(
                            _isFavorite
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            _isFavorite
                                ? 'Quitar de favoritos'
                                : 'Añadir a favoritos',
                          ),
                        ),
                        PopupMenuItem(
                          value: 'favs',
                          child: _menuRow(
                              Icons.folder_special_rounded, 'Ver favoritos'),
                        ),
                        PopupMenuItem(
                          value: 'goto',
                          child: _menuRow(
                              Icons.drive_file_move_rounded, 'Ir a ruta…'),
                        ),
                        PopupMenuItem(
                          value: 'refresh',
                          child: _menuRow(Icons.refresh_rounded, 'Actualizar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _menuRow(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 20, color: HubColors.textoSecundario),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: HubColors.textoPrincipal)),
      ],
    );
  }

  void _showSortMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: HubColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: HubColors.linea,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Ordenar por',
                  style: TextStyle(
                      color: HubColors.textoPrincipal,
                      fontWeight: FontWeight.w600)),
            ),
            for (final e in [
              (_SortMode.nameAsc, 'Nombre A-Z'),
              (_SortMode.nameDesc, 'Nombre Z-A'),
              (_SortMode.dateNewest, 'Más reciente'),
              (_SortMode.dateOldest, 'Más antiguo'),
              (_SortMode.sizeLargest, 'Más grande'),
              (_SortMode.sizeSmallest, 'Más pequeño'),
            ])
              ListTile(
                title: Text(e.$2,
                    style: TextStyle(
                      color: _sort == e.$1
                          ? HubColors.pomelo
                          : HubColors.textoPrincipal,
                      fontWeight:
                          _sort == e.$1 ? FontWeight.w600 : FontWeight.normal,
                    )),
                trailing: _sort == e.$1
                    ? const Icon(Icons.check_rounded, color: HubColors.pomelo)
                    : null,
                onTap: () {
                  setState(() {
                    _sort = e.$1;
                    _applyFilterAndSort();
                  });
                  Navigator.pop(ctx);
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildBreadcrumbs() {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          GestureDetector(
            onTap: () {
              if (_roots.isNotEmpty) _navigateTo(_roots.first['path']!);
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Icon(Icons.home_rounded, size: 18, color: HubColors.pomelo),
            ),
          ),
          for (var i = 0; i < _breadcrumbs.length; i++) ...[
            const Icon(Icons.chevron_right_rounded,
                size: 16, color: HubColors.textoSecundario),
            GestureDetector(
              onTap: () => _navigateTo(_breadcrumbs[i]),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Text(
                  _breadcrumbs[i].split('/').last,
                  style: TextStyle(
                    color: i == _breadcrumbs.length - 1
                        ? HubColors.textoPrincipal
                        : HubColors.textoSecundario,
                    fontSize: 13,
                    fontWeight: i == _breadcrumbs.length - 1
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStorageBar() {
    final info = _storageInfo!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: info.usedRatio.clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: HubColors.linea.withOpacity(0.4),
              valueColor: AlwaysStoppedAnimation(
                info.usedRatio > 0.9 ? Colors.redAccent : HubColors.pomelo,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${info.usedLabel} usados de ${info.totalLabel} · ${info.freeLabel} libres',
            style: const TextStyle(
                color: HubColors.textoSecundario, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    const chips = [
      (_FileFilter.all, 'Todo'),
      (_FileFilter.folders, 'Carpetas'),
      (_FileFilter.images, 'Imágenes'),
      (_FileFilter.videos, 'Vídeos'),
      (_FileFilter.audio, 'Audio'),
      (_FileFilter.documents, 'Docs'),
      (_FileFilter.archives, 'Zips'),
      (_FileFilter.apks, 'APKs'),
    ];
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (final c in chips)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: Text(c.$2, style: const TextStyle(fontSize: 12)),
                selected: _filter == c.$1,
                onSelected: (_) => setState(() {
                  _filter = c.$1;
                  _applyFilterAndSort();
                }),
                selectedColor: HubColors.pomelo.withOpacity(0.25),
                checkmarkColor: HubColors.pomelo,
                labelStyle: TextStyle(
                  color: _filter == c.$1
                      ? HubColors.pomelo
                      : HubColors.textoSecundario,
                  fontWeight:
                      _filter == c.$1 ? FontWeight.w600 : FontWeight.normal,
                ),
                backgroundColor: HubColors.panel,
                side: BorderSide(
                  color: _filter == c.$1
                      ? HubColors.pomelo.withOpacity(0.6)
                      : HubColors.linea.withOpacity(0.5),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (!_hasPermission) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.folder_off_rounded,
                  size: 48, color: HubColors.textoSecundario),
              const SizedBox(height: 16),
              const Text(
                'Se necesita permiso de almacenamiento',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: HubColors.textoPrincipal,
                    fontSize: 16,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Concede acceso a todos los archivos para explorar, crear carpetas y gestionar tus documentos.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: HubColors.textoSecundario, fontSize: 13),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 220,
                child: GradientPillButton(
                  label: 'Conceder permiso',
                  icon: Icons.lock_open_rounded,
                  onPressed: _requestPermission,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _bootstrap,
                child: const Text('Ya lo activé, reintentar',
                    style: TextStyle(color: HubColors.textoAcento)),
              ),
            ],
          ),
        ),
      );
    }

    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
              strokeWidth: 2.2, color: HubColors.pomelo),
        ),
      );
    }

    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _searchQuery.isNotEmpty || _filter != _FileFilter.all
                  ? Icons.search_off_rounded
                  : Icons.folder_open_rounded,
              size: 44,
              color: HubColors.textoSecundario,
            ),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Sin resultados para "$_searchQuery"'
                  : (_filter != _FileFilter.all
                      ? 'Nada en este filtro'
                      : 'Carpeta vacía'),
              style: const TextStyle(
                  color: HubColors.textoPrincipal,
                  fontSize: 15,
                  fontWeight: FontWeight.w600),
            ),
            if (_searchQuery.isEmpty && _filter == _FileFilter.all) ...[
              const SizedBox(height: 6),
              const Text(
                'Toca + para crear una carpeta o archivo',
                style:
                    TextStyle(color: HubColors.textoSecundario, fontSize: 13),
              ),
            ],
          ],
        ),
      );
    }

    if (_view == _ViewMode.grid) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 80),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.85,
        ),
        itemCount: _filtered.length,
        itemBuilder: (ctx, i) {
          final e = _filtered[i];
          final selected = _selected.contains(e.path);
          return GestureDetector(
            onTap: () {
              if (_selectionMode) {
                setState(() {
                  if (selected) {
                    _selected.remove(e.path);
                    if (_selected.isEmpty) _selectionMode = false;
                  } else {
                    _selected.add(e.path);
                  }
                });
              } else if (e.isDirectory) {
                _navigateTo(e.path);
              } else {
                DeviceFilesService.openFile(e.path);
              }
            },
            onLongPress: () {
              if (!_selectionMode) {
                setState(() {
                  _selectionMode = true;
                  _selected.add(e.path);
                });
              } else {
                _showContextMenu(e);
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: selected
                    ? HubColors.pomelo.withOpacity(0.15)
                    : HubColors.panel,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? HubColors.pomelo.withOpacity(0.7)
                      : HubColors.linea.withOpacity(0.5),
                ),
              ),
              child: Stack(
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_iconFor(e), size: 36, color: _iconColor(e)),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          e.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: HubColors.textoPrincipal, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  if (selected)
                    const Positioned(
                      top: 6,
                      right: 6,
                      child: Icon(Icons.check_circle_rounded,
                          color: HubColors.pomelo, size: 20),
                    ),
                ],
              ),
            ),
          );
        },
      );
    }

    // List view
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 80),
      itemCount: _filtered.length,
      itemBuilder: (ctx, i) {
        final e = _filtered[i];
        final selected = _selected.contains(e.path);
        return Material(
          color: selected
              ? HubColors.pomelo.withOpacity(0.08)
              : Colors.transparent,
          child: InkWell(
            onTap: () {
              if (_selectionMode) {
                setState(() {
                  if (selected) {
                    _selected.remove(e.path);
                    if (_selected.isEmpty) _selectionMode = false;
                  } else {
                    _selected.add(e.path);
                  }
                });
              } else if (e.isDirectory) {
                _navigateTo(e.path);
              } else {
                DeviceFilesService.openFile(e.path);
              }
            },
            onLongPress: () {
              if (!_selectionMode) {
                setState(() {
                  _selectionMode = true;
                  _selected.add(e.path);
                });
              } else {
                _showContextMenu(e);
              }
            },
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  if (_selectionMode) ...[
                    Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      color: selected
                          ? HubColors.pomelo
                          : HubColors.textoSecundario,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                  ],
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _iconColor(e).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child:
                        Icon(_iconFor(e), size: 24, color: _iconColor(e)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: HubColors.textoPrincipal,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          e.isDirectory
                              ? _formatDate(e.modified)
                              : '${e.sizeLabel}  ·  ${_formatDate(e.modified)}',
                          style: const TextStyle(
                              color: HubColors.textoSecundario,
                              fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  if (!_selectionMode && e.isDirectory)
                    const Icon(Icons.chevron_right_rounded,
                        color: HubColors.textoSecundario, size: 20),
                  if (!_selectionMode && !e.isDirectory)
                    IconButton(
                      icon: const Icon(Icons.more_vert_rounded,
                          color: HubColors.textoSecundario, size: 18),
                      onPressed: () => _showContextMenu(e),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
