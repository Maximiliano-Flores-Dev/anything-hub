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
import 'file_explorer_screen.dart';
import 'settings_screen.dart';
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

  static const Map<String, _CardData> _allCards = {
    DashboardCardIds.apps: _CardData(
      'Mis Aplicaciones',
      'Gestiona, descarga y abre tus apps en un solo lugar',
      AppsArt(),
    ),
    DashboardCardIds.projects: _CardData(
      'Carpetas del Proyecto',
      'Acceso rápido a tus proyectos',
      SheetsArt(),
    ),
    DashboardCardIds.webs: _CardData(
      'Webs Rápidas',
      'Tus sitios favoritos, al instante',
      WebArt(),
    ),
    DashboardCardIds.favorites: _CardData(
      'Favoritos',
      'Todo lo que te importa',
      FavoritesArt(),
    ),
    DashboardCardIds.files: _CardData(
      'Gestión de Archivos',
      'Explora, organiza y accede rápido',
      FilesArt(),
    ),
    DashboardCardIds.performance: _CardData(
      'Modos de Rendimiento',
      'Ajusta el rendimiento de tu dispositivo',
      PerformanceArt(),
    ),
  };

  List<_CardData> get _visibleCards {
    final ids = MacroCustomization.instance.activeCardIds;
    return [
      for (final id in ids)
        if (_allCards.containsKey(id)) _allCards[id]!,
    ];
  }

  List<String> get _visibleCardIds =>
      MacroCustomization.instance.activeCardIds
          .where((id) => _allCards.containsKey(id))
          .toList();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    MacroCustomization.instance.addListener(_onMacroChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    MacroCustomization.instance.removeListener(_onMacroChanged);
    WidgetsBinding.instance.removeObserver(this);
    _webLinks.dispose();
    super.dispose();
  }

  void _onMacroChanged() {
    if (mounted) setState(() {});
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
    final pending = await DeviceAppsService.consumePendingIncomingApk();
    if (pending != null && mounted) {
      final path = pending['cacheRelativePath'] as String?;
      if (path != null && path.isNotEmpty) {
        Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => ApkIncomingSheet(
            fileName: (pending['fileName'] as String?) ?? 'app.apk',
            sizeBytes: (pending['sizeBytes'] as num?)?.toInt() ?? 0,
            cacheRelativePath: path,
            callerPackage: pending['callerPackage'] as String?,
            callerVerified: (pending['callerPackage'] as String?)?.isNotEmpty == true,
          ),
        ));
      }
    }
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
        content: Text(body, style: const TextStyle(color: HubColors.textoSecundario, fontSize: 13)),
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
          body: 'Anythings Hub necesita consultar las aplicaciones instaladas en tu dispositivo para clasificarlas por categorías. Todo se procesa en el dispositivo y no se envía a ningún servidor.',
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
          body: 'Para ordenar tus apps por uso frecuente, activa "Acceso a datos de uso" para Anythings Hub en Ajustes.',
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
      _toast(usageOk ? 'Apps sincronizadas y ordenadas por uso.' : 'Apps sincronizadas (orden alfabético).');
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
      if (!mounted) return;
      final reopen = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: HubColors.panel,
          title: const Text('Módulo de proyectos', style: TextStyle(color: HubColors.textoPrincipal)),
          content: const Text(
            'Habías elegido no volver a mostrar el aviso. ¿Quieres reactivar el módulo de proyectos?',
            style: TextStyle(color: HubColors.textoSecundario),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reactivar')),
          ],
        ),
      );
      if (reopen == true) {
        await ProjectActivationService.clearAdvisementDismissal();
        if (!mounted) return;
        await _openProjectsModule();
      }
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
    if (action.id == 'folder') {
    } else if (action.id == 'scan_device') {
      _requestDeviceAppsAndScan();
    }
  }

  void _onCardTap(String cardId) {
    if (cardId == DashboardCardIds.apps) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const MisAplicacionesScreen()),
      );
    } else if (cardId == DashboardCardIds.projects) {
      _openProjectsModule();
    } else if (cardId == DashboardCardIds.webs) {
      _openWebLinks();
    } else if (cardId == DashboardCardIds.files) {
      _openFileExplorer();
    } else if (cardId == DashboardCardIds.performance) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const PerformanceModesScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final macro = MacroCustomization.instance;
    final sidebar = macro.sidebarEnabled
        ? CollapsibleSidebar(
            screenWidth: screenWidth,
            appGroups: _appGroups,
            onActionSelected: _onFabAction,
            onAppTap: _launchApp,
          )
        : null;

    return Scaffold(
      backgroundColor: HubColors.fondoPrincipal,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (sidebar != null && !macro.leftHandedMode) sidebar,
            Expanded(
              child: Column(
                children: [
                  Expanded(child: _buildContent()),
                  _BottomNav(
                    selected: _tab,
                    onSelected: (i) => setState(() => _tab = i),
                  ),
                ],
              ),
            ),
            if (sidebar != null && macro.leftHandedMode) sidebar,
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_tab == 1) return const MisAplicacionesScreen();
    if (_tab == 2) return const FileExplorerScreen();
    if (_tab == 3) return const SettingsScreen();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text(
            'Bienvenido de\nnuevo',
            style: TextStyle(
              color: HubColors.textoPrincipal,
              fontSize: 23,
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Sincronización inteligente de apps',
            style: TextStyle(color: HubColors.textoAcento, fontSize: 13),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _visibleCards.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.04,
            ),
            itemBuilder: (context, i) {
              final c = _visibleCards[i];
              final cardId = _visibleCardIds[i];
              return DashboardCard(
                title: c.title,
                subtitle: c.subtitle,
                art: c.art,
                onTap: () => _onCardTap(cardId),
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
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.selected, required this.onSelected});
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
      decoration: BoxDecoration(
        color: HubColors.panel,
        border: Border(top: BorderSide(color: HubColors.linea)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_items.length, (i) {
          final (activeIcon, idleIcon, label) = _items[i];
          final isSel = selected == i;
          return InkWell(
            onTap: () => onSelected(i),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(isSel ? activeIcon : idleIcon,
                      color: isSel ? HubColors.pomelo : HubColors.textoSecundario, size: 24),
                  const SizedBox(height: 2),
                  Text(label,
                      style: TextStyle(
                        color: isSel ? HubColors.pomelo : HubColors.textoSecundario,
                        fontSize: 10,
                        fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                      )),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
