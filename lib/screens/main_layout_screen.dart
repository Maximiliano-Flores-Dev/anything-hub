import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/hub_colors.dart';
import '../core/macro_customization.dart';
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
import '../modules/apps/ui/apk_incoming_sheet.dart';
import '../modules/favorites/ui/favorites_screen.dart';
import 'file_explorer_screen.dart';
import 'settings_screen.dart';
import '../ui/groups/group_editor_sheet.dart';
import 'web_links_screen.dart';
import 'performance_modes_screen.dart';

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
    with SingleTickerProviderStateMixin {
  static const _prefsKey = 'hub_app_groups_v1';
  static const _prefsLinksKey = 'hub_web_links_v1';

  late final AnimationController _pulse;
  List<HubApp> _apps = [];
  List<AppGroup> _appGroups = [];
  List<WebLinkItem> _webLinks = [];
  bool _loadingApps = true;
  String? _appsError;
  bool _sidebarOpen = false;

  final List<_CardData> _cards = const [
    _CardData('Mis Aplicaciones', 'Gestión y lanzamiento', AppArt()),
    _CardData('Archivos', 'Explorador local', FilesArt()),
    _CardData('Proyectos', 'Workspace local', ProjectsArt()),
    _CardData('Enlaces Web', 'Favoritos y acceso rápido', WebArt()),
    _CardData('Favoritos', 'Apps, webs y archivos', FavoritesArt()),
    _CardData('Modos de Rendimiento', 'Equilibrado · Eco · Focus', PerformanceArt()),
    _CardData('Configuración', 'Ajustes y plugins', SettingsArt()),
  ];

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    MacroCustomization.instance.addListener(_onMacroChanged);
    _bootstrap();
  }

  void _onMacroChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    MacroCustomization.instance.removeListener(_onMacroChanged);
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _loadState();
    await _scanApps();
  }

  Future<void> _loadState() async {
    try {
      final raw = await DeviceAppsService.readPref(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final list = (jsonDecode(raw) as List).cast<Map>();
        _appGroups = list.map((m) {
          final packages = (m['packages'] as List?)?.cast<String>() ?? [];
          final colorRaw = m['colorArgb'];
          return AppGroup(
            m['name'] as String? ?? 'Grupo',
            const [],
            isCustom: m['isCustom'] == true,
            packages: List<String>.from(packages),
            colorArgb: colorRaw is int
                ? colorRaw
                : int.tryParse('${colorRaw ?? ''}'),
          );
        }).toList();
      }
      final linksRaw = await DeviceAppsService.readPref(_prefsLinksKey);
      if (linksRaw != null && linksRaw.isNotEmpty) {
        final list = (jsonDecode(linksRaw) as List).cast<Map>();
        _webLinks = list
            .map((m) => WebLinkItem(
                  title: m['title'] as String? ?? '',
                  url: m['url'] as String? ?? '',
                ))
            .where((e) => e.url.isNotEmpty)
            .toList();
      }
    } catch (e) {
      SystemLogger.log('loadState: $e');
    }
  }

  Future<void> _saveState() async {
    try {
      final groups = _appGroups
          .map((g) => {
                'name': g.name,
                'isCustom': g.isCustom,
                'packages': g.packages,
                if (g.colorArgb != null) 'colorArgb': g.colorArgb,
              })
          .toList();
      await DeviceAppsService.writePref(_prefsKey, jsonEncode(groups));
    } catch (e) {
      SystemLogger.log('saveState: $e');
    }
  }

  Future<void> _scanApps() async {
    setState(() {
      _loadingApps = true;
      _appsError = null;
    });
    try {
      final apps = await DeviceAppsService.getInstalledApps();
      if (!mounted) return;
      setState(() {
        _apps = apps;
        _loadingApps = false;
        _rebuildGroups();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingApps = false;
        _appsError = '$e';
      });
    }
  }

  void _rebuildGroups() {
    final byPkg = {for (final a in _apps) a.packageName: a};
    final autoGroups = <AppGroup>[];
    for (final c in kDefaultCategories) {
      final apps = _apps
          .where((a) => a.category == c.id)
          .toList();
      if (apps.isEmpty) continue;
      autoGroups.add(AppGroup(c.label, apps)..sortByUsage());
    }
    final customs = _appGroups.where((g) => g.isCustom).map((g) {
      final apps = g.packages
          .map((p) => byPkg[p])
          .whereType<HubApp>()
          .toList();
      return AppGroup(
        g.name,
        apps,
        isCustom: true,
        packages: List<String>.from(g.packages),
        colorArgb: g.colorArgb,
      )..sortByUsage();
    }).toList();
    _appGroups = [...customs, ...autoGroups];
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: HubColors.panel,
        content: Text(message, style: TextStyle(color: HubColors.textoPrincipal)),
      ),
    );
  }

  void _openWebLinks() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const WebLinksScreen()),
    );
  }

  void _openFileExplorer() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FileExplorerScreen()),
    );
  }

  Future<void> _openProjects() async {
    final ok = await showAdvisementModal(context);
    if (!ok || !mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProjectsScreen()),
    );
  }

  void _launchApp(HubApp app) {
    DeviceAppsService.launchApp(app.packageName);
  }

  void _onFabAction(RadialAction action) {
    switch (action) {
      case RadialAction.settings:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );
      case RadialAction.newGroup:
        _createGroup();
      case RadialAction.addApp:
        _addAppToGroup();
      case RadialAction.scanDevice:
        _scanApps();
        _toast('Escaneando apps…');
    }
  }

  Future<void> _createGroup() async {
    final result = await showGroupEditorSheet(
      context,
      allApps: _apps,
      initialName: 'Nuevo grupo',
    );
    if (result == null || !mounted) return;
    final group = AppGroup(
      result.name,
      result.selectedApps,
      isCustom: true,
      packages: result.selectedApps.map((a) => a.packageName).toList(),
      colorArgb: result.colorArgb,
    );
    setState(() {
      _appGroups = [group, ..._appGroups];
    });
    await _saveState();
    _toast('Grupo «${group.name}» creado');
  }

  Future<void> _openEditGroup(AppGroup group) async {
    if (!group.isCustom) return;
    final result = await showGroupEditorSheet(
      context,
      allApps: _apps,
      initialName: group.name,
      initialSelected: group.apps,
      initialColorArgb: group.colorArgb,
    );
    if (result == null || !mounted) return;
    if (result.delete) {
      setState(() {
        _appGroups.removeWhere((g) => identical(g, group) || (g.isCustom && g.name == group.name));
      });
      await _saveState();
      _toast('Grupo eliminado');
      return;
    }
    setState(() {
      group.name = result.name;
      group.apps
        ..clear()
        ..addAll(result.selectedApps);
      group.packages
        ..clear()
        ..addAll(result.selectedApps.map((a) => a.packageName));
      group.colorArgb = result.colorArgb;
    });
    await _saveState();
    _toast('Grupo actualizado');
  }

  Future<void> _addAppToGroup() async {
    final customs = _appGroups.where((g) => g.isCustom).toList();
    if (customs.isEmpty) {
      _toast('Primero crea un grupo');
      await _createGroup();
      return;
    }
    final target = await showModalBottomSheet<AppGroup>(
      context: context,
      backgroundColor: HubColors.panel,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Añadir apps a…',
                  style: TextStyle(
                      color: HubColors.textoPrincipal,
                      fontWeight: FontWeight.w700,
                      fontSize: 16)),
            ),
            ...customs.map((g) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color(g.colorArgb ?? 0xFFF05A3C),
                    radius: 10,
                  ),
                  title: Text(g.name,
                      style: TextStyle(color: HubColors.textoPrincipal)),
                  onTap: () => Navigator.pop(ctx, g),
                )),
          ],
        ),
      ),
    );
    if (target == null || !mounted) return;
    await _openEditGroup(target);
  }

  void _onCardTap(String title) {
    switch (title) {
      case 'Mis Aplicaciones':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MisAplicacionesScreen()),
        );
      case 'Archivos':
        _openFileExplorer();
      case 'Proyectos':
        _openProjects();
      case 'Enlaces Web':
        _openWebLinks();
      case 'Favoritos':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FavoritesScreen(webRepo: _webLinks),
          ),
        );
      case 'Modos de Rendimiento':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PerformanceModesScreen()),
        );
      case 'Configuración':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Scaffold(
      backgroundColor: HubColors.fondoPrincipal,
      body: Stack(
        children: [
          SafeArea(child: _buildContent()),
          CollapsibleSidebar(
            screenWidth: width,
            appGroups: _appGroups,
            onActionSelected: _onFabAction,
            onAppTap: _launchApp,
            onEditGroup: _openEditGroup,
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(
            children: [
              Text(
                'Anythings Hub',
                style: TextStyle(
                  color: HubColors.textoPrincipal,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                ),
              ),
              const Spacer(),
              if (_loadingApps)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: HubColors.pomelo,
                  ),
                ),
            ],
          ),
        ),
        if (_appsError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(_appsError!,
                style: TextStyle(color: HubColors.pomelo, fontSize: 12)),
          ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.05,
            ),
            itemCount: _cards.length,
            itemBuilder: (context, i) {
              final c = _cards[i];
              return DashboardCard(
                title: c.title,
                subtitle: c.subtitle,
                art: c.art,
                onTap: () => _onCardTap(c.title),
              );
            },
          ),
        ),
      ],
    );
  }
}
