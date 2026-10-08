import 'package:flutter/material.dart';

import '../core/hub_colors.dart';
import '../modules/plugins/plugin_models.dart';
import '../modules/plugins/plugin_service.dart';
import '../modules/projects/services/project_fs_service.dart';
import '../services/device_apps_service.dart';
import '../services/device_files_service.dart';
import '../services/performance_service.dart';
import '../ui/widgets/gradient_pill_button.dart';

/// Configuraciones + gestión de plugins locales + auditoría de permisos.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<HubPluginEntry> _catalog = [];
  List<HubPluginEntry> _installed = [];
  bool _loadingCatalog = false;
  bool _loadingInstalled = false;
  String? _hubPath;
  String? _error;

  bool _permStorage = false;
  bool _permUsage = false;
  bool _permFocus = false;
  bool _permPostNotif = true;
  bool _loadingPerms = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _bootstrap();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      await ProjectFsService.ensureStructure();
      final root = await ProjectFsService.getRootDirectory();
      if (mounted) setState(() => _hubPath = root.path);
    } catch (_) {}
    await Future.wait([_loadInstalled(), _loadCatalog(), _refreshPermissions()]);
  }

  Future<void> _refreshPermissions() async {
    if (mounted) setState(() => _loadingPerms = true);
    final results = await Future.wait([
      DeviceFilesService.hasPermission(),
      DeviceAppsService.hasUsageAccess(),
      PerformanceService.hasNotificationPolicyAccess(),
      PerformanceService.hasPostNotifications(),
    ]);
    if (!mounted) return;
    setState(() {
      _permStorage = results[0];
      _permUsage = results[1];
      _permFocus = results[2];
      _permPostNotif = results[3];
      _loadingPerms = false;
    });
  }

  Future<void> _loadInstalled() async {
    setState(() => _loadingInstalled = true);
    final list = await PluginService.listInstalled();
    if (!mounted) return;
    setState(() {
      _installed = list;
      _loadingInstalled = false;
    });
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _loadingCatalog = true;
      _error = null;
    });
    final list = await PluginService.fetchCatalog();
    if (!mounted) return;
    setState(() {
      _catalog = list;
      _loadingCatalog = false;
      if (list.isEmpty) {
        _error =
            'No se pudo cargar el catálogo. Revisa la red o la carpeta plugins/ del repositorio.';
      }
    });
  }

  Future<void> _install(HubPluginEntry entry) async {
    final ok = await PluginService.install(entry.manifest);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: HubColors.panel,
        content: Text(
          ok
              ? 'Plugin «${entry.manifest.name}» instalado en .anythinghub/plugins/'
              : 'No se pudo instalar el plugin',
          style: const TextStyle(color: HubColors.textoPrincipal),
        ),
      ),
    );
    await Future.wait([_loadInstalled(), _loadCatalog()]);
  }

  Future<void> _uninstall(HubPluginEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HubColors.panel,
        title: const Text('Desinstalar plugin',
            style: TextStyle(color: HubColors.textoPrincipal)),
        content: Text(
          'Se eliminará «${entry.manifest.name}» de .anythinghub/plugins/. Solo se borran metadatos locales.',
          style: const TextStyle(color: HubColors.textoSecundario),
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
            child: const Text('Desinstalar',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await PluginService.uninstall(entry.manifest.id);
    await Future.wait([_loadInstalled(), _loadCatalog()]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HubColors.fondoPrincipal,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: HubColors.textoPrincipal),
        title: const Text(
          'Configuración',
          style: TextStyle(
              color: HubColors.textoPrincipal, fontWeight: FontWeight.w700),
        ),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: HubColors.pomelo,
          labelColor: HubColors.pomelo,
          unselectedLabelColor: HubColors.textoSecundario,
          tabs: const [
            Tab(text: 'General'),
            Tab(text: 'Plugins'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildGeneral(),
          _buildPlugins(),
        ],
      ),
    );
  }

  Widget _permRow(
    String title,
    String subtitle,
    bool granted,
    VoidCallback onOpen,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          granted ? Icons.check_circle : Icons.cancel_outlined,
          size: 22,
          color: granted ? const Color(0xFF3DDC84) : const Color(0xFFE53935),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: HubColors.textoPrincipal,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(
                      color: HubColors.textoSecundario, fontSize: 12)),
              const SizedBox(height: 2),
              Text(
                granted ? 'Concedido' : 'No concedido — toca para gestionar',
                style: TextStyle(
                  color: granted
                      ? const Color(0xFF3DDC84)
                      : HubColors.pomelo,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Abrir ajustes del sistema',
          onPressed: onOpen,
          icon: const Icon(Icons.open_in_new, size: 18, color: HubColors.textoAcento),
        ),
      ],
    );
  }

  Widget _buildGeneral() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _sectionTitle('Espacio local'),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Raíz .anythinghub',
                style: TextStyle(
                    color: HubColors.textoSecundario, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                _hubPath ?? '…',
                style: const TextStyle(
                    color: HubColors.textoPrincipal, fontSize: 13),
              ),
              const SizedBox(height: 12),
              const Text(
                'Subcarpetas: cache/, config/, logs/, projects/, plugins/',
                style: TextStyle(
                    color: HubColors.textoSecundario, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _sectionTitle('Seguridad'),
        _card(
          child: const Text(
            'Los plugins se instalan solo como metadatos JSON en el dispositivo. '
            'Anythings Hub no ejecuta código remoto ni carga Dex/so dinámicos. '
            'Sin telemetría. Local-first.',
            style: TextStyle(color: HubColors.textoSecundario, fontSize: 13, height: 1.35),
          ),
        ),
        const SizedBox(height: 20),
        _sectionTitle('Permisos del sistema'),
        _card(
          child: _loadingPerms
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: HubColors.pomelo,
                      ),
                    ),
                  ),
                )
              : Column(
                  children: [
                    _permRow(
                      'Almacenamiento (todos los archivos)',
                      'Explorador de archivos',
                      _permStorage,
                      () async {
                        await DeviceFilesService.openPermissionSettings();
                        await Future<void>.delayed(const Duration(seconds: 1));
                        await _refreshPermissions();
                      },
                    ),
                    const Divider(color: HubColors.linea, height: 20),
                    _permRow(
                      'Acceso a datos de uso',
                      'Ordenar apps por uso frecuente',
                      _permUsage,
                      () async {
                        await DeviceAppsService.openUsageAccessSettings();
                        await Future<void>.delayed(const Duration(seconds: 1));
                        await _refreshPermissions();
                      },
                    ),
                    const Divider(color: HubColors.linea, height: 20),
                    _permRow(
                      'No molestar / Focus',
                      'Silenciar notificaciones de terceros',
                      _permFocus,
                      () async {
                        await PerformanceService.openNotificationPolicySettings();
                        await Future<void>.delayed(const Duration(seconds: 1));
                        await _refreshPermissions();
                      },
                    ),
                    const Divider(color: HubColors.linea, height: 20),
                    _permRow(
                      'Notificaciones propias',
                      'Avisos del modo rendimiento (Android 13+)',
                      _permPostNotif,
                      () async {
                        await PerformanceService.requestPostNotifications();
                        await Future<void>.delayed(const Duration(milliseconds: 800));
                        await _refreshPermissions();
                      },
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _refreshPermissions,
                        icon: const Icon(Icons.refresh, size: 18, color: HubColors.textoAcento),
                        label: const Text('Actualizar',
                            style: TextStyle(color: HubColors.textoAcento)),
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 20),
        _sectionTitle('Acerca de'),
        _card(
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Anythings Hub',
                  style: TextStyle(
                      color: HubColors.textoPrincipal,
                      fontWeight: FontWeight.w700)),
              SizedBox(height: 4),
              Text(
                'Hub local para apps, archivos y proyectos. Sin telemetría.',
                style: TextStyle(color: HubColors.textoSecundario, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlugins() {
    return RefreshIndicator(
      color: HubColors.pomelo,
      onRefresh: () async {
        await Future.wait([_loadInstalled(), _loadCatalog()]);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _sectionTitle('Instalados (${_installed.length})'),
          if (_loadingInstalled)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                  child: CircularProgressIndicator(color: HubColors.pomelo)),
            )
          else if (_installed.isEmpty)
            _card(
              child: const Text(
                'Ningún plugin instalado. Explora el catálogo abajo.',
                style:
                    TextStyle(color: HubColors.textoSecundario, fontSize: 13),
              ),
            )
          else
            ..._installed.map((e) => _pluginTile(e, installedView: true)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _sectionTitle('Catálogo (GitHub)')),
              IconButton(
                tooltip: 'Actualizar catálogo',
                onPressed: _loadingCatalog ? null : _loadCatalog,
                icon: const Icon(Icons.refresh_rounded,
                    color: HubColors.pomelo),
              ),
            ],
          ),
          const Text(
            'Fuente: plugins/catalog.json del repositorio oficial. Solo metadatos.',
            style: TextStyle(color: HubColors.textoSecundario, fontSize: 11.5),
          ),
          const SizedBox(height: 8),
          if (_loadingCatalog)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                  child: CircularProgressIndicator(color: HubColors.pomelo)),
            )
          else if (_error != null && _catalog.isEmpty)
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_error!,
                      style: const TextStyle(
                          color: HubColors.textoSecundario, fontSize: 13)),
                  const SizedBox(height: 12),
                  GradientPillButton(
                    label: 'Reintentar',
                    icon: Icons.refresh_rounded,
                    onPressed: _loadCatalog,
                  ),
                ],
              ),
            )
          else
            ..._catalog.map((e) => _pluginTile(e, installedView: false)),
        ],
      ),
    );
  }

  Widget _pluginTile(HubPluginEntry entry, {required bool installedView}) {
    final m = entry.manifest;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: HubColors.pomelo.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.extension_rounded,
                      color: HubColors.pomelo, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.name,
                          style: const TextStyle(
                              color: HubColors.textoPrincipal,
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5)),
                      Text(
                        'v${m.version}${m.author.isNotEmpty ? ' · ${m.author}' : ''}',
                        style: const TextStyle(
                            color: HubColors.textoSecundario, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                if (entry.installed)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3DDC84).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('INSTALADO',
                        style: TextStyle(
                            color: Color(0xFF3DDC84),
                            fontSize: 10,
                            fontWeight: FontWeight.w800)),
                  ),
              ],
            ),
            if (m.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(m.description,
                  style: const TextStyle(
                      color: HubColors.textoSecundario, fontSize: 12.5)),
            ],
            if (m.permissions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Permisos declarados: ${m.permissions.join(', ')}',
                style: const TextStyle(
                    color: HubColors.textoAcento, fontSize: 11),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (!entry.installed)
                  Expanded(
                    child: GradientPillButton(
                      label: 'Instalar',
                      icon: Icons.download_rounded,
                      onPressed: () => _install(entry),
                    ),
                  ),
                if (entry.installed) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                      ),
                      onPressed: () => _uninstall(entry),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Desinstalar'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          t,
          style: const TextStyle(
            color: HubColors.textoPrincipal,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      );

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: HubColors.panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: HubColors.linea),
        ),
        child: child,
      );
}
