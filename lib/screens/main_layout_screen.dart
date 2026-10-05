import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/hub_colors.dart';
import '../core/logger.dart';
import '../core/models.dart';
import '../modules/projects/services/project_activation_service.dart';
import '../modules/projects/services/project_fs_service.dart';
import '../modules/projects/ui/advisement_modal.dart';
import '../modules/projects/ui/projects_screen.dart';
import '../services/device_apps_service.dart';
import '../ui/sidebar/collapsible_sidebar.dart';
import '../ui/widgets/card_arts.dart';
import '../ui/widgets/dashboard_card.dart';
import '../ui/widgets/gradient_pill_button.dart';
import '../modules/apps/ui/mis_aplicaciones_screen.dart';
import 'file_explorer_screen.dart';
import 'web_links_screen.dart';

class _CardData {
  const _CardData(this.title, this.subtitle, this.art);
  final String title;
  final String subtitle;
  final Widget art;
}

class MainLayoutScreen extends StatefulWidget {
  const MainLayoutScreen({super.key});

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen>
    with WidgetsBindingObserver {
  int _tab = 0;
  bool _deviceScanned = false;
  bool _consent = false;
  bool _scanning = false;
  bool _awaitingUsageAccess = false;
  bool _usagePromptDismissed = false;
  String _selfPackage = '';

  final Map<String, HubApp> _catalog = {};
  List<AppGroup> _appGroups = [];
  final WebLinkRepository _webLinks = WebLinkRepository();

  static const List<_CardData> _cards = [
    _CardData('Mis Aplicaciones', 'Gestiona, descarga y abre tus apps en un solo lugar', AppsArt()),
    _CardData('Carpetas del Proyecto', 'Acceso rápido a tus proyectos', SheetsArt()),
    _CardData('Webs Rápidas', 'Tus sitios favoritos, al instante', WebArt()),
    _CardData('Favoritos', 'Todo lo que te importa', FavoritesArt()),
    _CardData('Gestión de Archivos', 'Explora, organiza y accede rápido', FilesArt()),
    _CardData('Modos de Rendimiento', 'Ajusta el rendimiento de tu dispositivo', PerformanceArt()),
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
        if (d.packageName == _selfPackage) continue;
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

  Future<void> _openProjectsModule() async {
    await ProjectActivationService.incrementAttempts();
    final activated = await ProjectActivationService.isActivated();
    if (activated) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const ProjectsScreen()),
      );
      return;
    }

    final shouldShow = await ProjectActivationService.shouldShowAdvisement();
    if (!shouldShow) {
      SystemLogger.log('Projects module: advisement dismissed permanently');
      return;
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ProjectAdvisementModal(
        onAccepted: () async {
          Navigator.of(ctx).pop();
          try {
            await ProjectFsService.ensureStructure();
          } catch (e) {
            SystemLogger.log('Error creando .anythinghub/: $e');
          }
          if (!mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const ProjectsScreen()),
          );
        },
        onCancelled: () => Navigator.of(ctx).pop(),
      ),
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
                        secondary: AppAvatar(app: app, size: 32),
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
                  _rebuildGroups();
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
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const MisAplicacionesScreen(),
                      ),
                    );
                  } else if (i == 1) {
                    _openProjectsModule();
                  } else if (i == 2) {
                    _openWebLinks();
                  } else if (i == 4) {
                    _openFileExplorer();
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
