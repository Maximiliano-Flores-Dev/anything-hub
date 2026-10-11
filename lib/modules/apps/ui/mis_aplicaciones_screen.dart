import 'package:flutter/material.dart';

import '../../../core/hub_colors.dart';
import '../../../services/device_apps_service.dart';
import '../models/app_models.dart';
import '../services/apps_local_store.dart';
import '../widgets/app_icon_cell.dart';
import 'app_gestion_screen.dart';
import 'puerto_software_screen.dart';

/// Grilla compacta de apps instaladas.
/// Tap → AppGestionScreen. Sin botones grandes en cada celda.
class MisAplicacionesScreen extends StatefulWidget {
  const MisAplicacionesScreen({super.key});

  @override
  State<MisAplicacionesScreen> createState() => _MisAplicacionesScreenState();
}

class _MisAplicacionesScreenState extends State<MisAplicacionesScreen> {
  final _store = AppsLocalStore();
  final _searchCtrl = TextEditingController();

  List<ManagedApp> _apps = [];
  Set<String> _bookmarks = {};
  bool _loading = true;
  bool _favoritesOnly = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final bookmarks = await _store.loadBookmarks();
    final reviews = await _store.loadReviews();
    final raw = await DeviceAppsService.listApps(days: 14);
    final self = await DeviceAppsService.selfPackage();

    final list = <ManagedApp>[];
    if (raw != null) {
      for (final a in raw) {
        if (a.packageName == self) continue;
        list.add(
          ManagedApp(
            packageName: a.packageName,
            name: a.name,
            category: a.category,
            usageMinutes: a.usageMinutes,
            icon: a.icon,
            isBookmarked: bookmarks.contains(a.packageName),
            localReview: reviews[a.packageName],
          ),
        );
      }
      list.sort((a, b) {
        final u = b.usageMinutes.compareTo(a.usageMinutes);
        if (u != 0) return u;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    }

    if (!mounted) return;
    setState(() {
      _bookmarks = bookmarks;
      _apps = list;
      _loading = false;
    });
  }

  List<ManagedApp> get _filtered {
    var list = _apps;
    if (_favoritesOnly) {
      list = list.where((a) => a.isBookmarked).toList();
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list
          .where(
            (a) =>
                a.name.toLowerCase().contains(q) ||
                a.packageName.toLowerCase().contains(q),
          )
          .toList();
    }
    return list;
  }

  Future<void> _openGestion(ManagedApp app) async {
    final updated = await Navigator.of(context).push<ManagedApp>(
      MaterialPageRoute(builder: (_) => AppGestionScreen(app: app)),
    );
    if (updated != null && mounted) {
      setState(() {
        final i = _apps.indexWhere((a) => a.packageName == updated.packageName);
        if (i >= 0) _apps[i] = updated;
        if (updated.isBookmarked) {
          _bookmarks.add(updated.packageName);
        } else {
          _bookmarks.remove(updated.packageName);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HubColors.fondoPrincipal,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: HubColors.textoPrincipal),
        title: Text(
          'Mis Aplicaciones',
          style: TextStyle(
            color: HubColors.textoPrincipal,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Puerto de Software',
            icon: Icon(Icons.anchor, color: HubColors.textoSecundario),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PuertoSoftwareScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.search, color: HubColors.textoSecundario),
            onPressed: () {
              showSearch(
                context: context,
                delegate: _AppsSearchDelegate(
                  apps: _apps,
                  onSelected: _openGestion,
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                _FilterChip(
                  label: 'Todas',
                  selected: !_favoritesOnly,
                  onTap: () => setState(() => _favoritesOnly = false),
                ),
                SizedBox(width: 8),
                _FilterChip(
                  label: 'Favoritos',
                  selected: _favoritesOnly,
                  onTap: () => setState(() => _favoritesOnly = true),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(color: HubColors.pomelo),
                  )
                : _filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No hay aplicaciones para mostrar',
                          style: TextStyle(color: HubColors.textoSecundario),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.78,
                        ),
                        itemCount: _filtered.length,
                        itemBuilder: (context, i) {
                          final app = _filtered[i];
                          return AppIconCell(
                            name: app.name,
                            category: _labelCategory(app.category),
                            iconBytes: app.icon,
                            bookmarked: app.isBookmarked,
                            onTap: () => _openGestion(app),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  static String _labelCategory(String id) {
    const map = {
      'ai': 'IA',
      'social': 'Redes sociales',
      'productivity': 'Productividad',
      'games': 'Juegos',
      'media': 'Multimedia',
      'maps': 'Navegación',
      'news': 'Noticias',
      'other': 'Otras',
    };
    return map[id] ?? id;
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? HubColors.pomelo.withOpacity(0.18) : HubColors.panel,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? HubColors.pomelo : HubColors.linea,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? HubColors.pomelo : HubColors.textoSecundario,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _AppsSearchDelegate extends SearchDelegate<ManagedApp?> {
  _AppsSearchDelegate({required this.apps, required this.onSelected});

  final List<ManagedApp> apps;
  final ValueChanged<ManagedApp> onSelected;

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      scaffoldBackgroundColor: HubColors.fondoPrincipal,
      appBarTheme: AppBarTheme(
        backgroundColor: HubColors.fondoPrincipal,
        foregroundColor: HubColors.textoPrincipal,
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: HubColors.textoSecundario),
      ),
      textTheme: TextTheme(
        titleLarge: TextStyle(color: HubColors.textoPrincipal),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) => [
        IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _list(context);

  @override
  Widget buildSuggestions(BuildContext context) => _list(context);

  Widget _list(BuildContext context) {
    final q = query.toLowerCase();
    final filtered = apps
        .where(
          (a) =>
              a.name.toLowerCase().contains(q) ||
              a.packageName.toLowerCase().contains(q),
        )
        .toList();
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (_, i) {
        final a = filtered[i];
        return ListTile(
          leading: a.icon != null
              ? Image.memory(a.icon!, width: 40, height: 40)
              : Icon(Icons.android, color: HubColors.textoSecundario),
          title: Text(a.name, style: TextStyle(color: HubColors.textoPrincipal)),
          subtitle: Text(
            a.packageName,
            style: TextStyle(color: HubColors.textoSecundario, fontSize: 12),
          ),
          onTap: () {
            close(context, a);
            onSelected(a);
          },
        );
      },
    );
  }
}
