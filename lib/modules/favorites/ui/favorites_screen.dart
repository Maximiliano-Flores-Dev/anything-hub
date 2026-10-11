import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/hub_colors.dart';
import '../../../screens/web_links_screen.dart';
import '../../../services/device_apps_service.dart';
import '../../../services/device_files_service.dart';
import '../models/favorite_item.dart';
import '../services/favorites_service.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key, this.webRepo});
  final WebLinkRepository? webRepo;
  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late final FavoritesService _service;
  FavoriteSort _sort = FavoriteSort.alphaAsc;
  List<FavoriteItem> _items = [];
  Map<FavoriteType, List<FavoriteItem>> _grouped = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _service = FavoritesService(webRepo: widget.webRepo);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await _service.loadAll();
    if (!mounted) return;
    setState(() {
      _items = items;
      _grouped = _service.groupAndSort(items, _sort);
      _loading = false;
    });
  }

  void _setSort(FavoriteSort sort) {
    if (sort == _sort) return;
    setState(() {
      _sort = sort;
      _grouped = _service.groupAndSort(_items, _sort);
    });
  }

  Future<void> _onTap(FavoriteItem item) async {
    if (item.type == FavoriteType.app && item.packageName != null) {
      await DeviceAppsService.launch(item.packageName!);
    } else if (item.type == FavoriteType.web && item.url != null) {
      final uri = Uri.tryParse(item.url!);
      if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (item.type == FavoriteType.file && item.path != null) {
      await DeviceFilesService.openFile(item.path!);
    }
  }

  Future<void> _remove(FavoriteItem item) async {
    await _service.remove(item);
    if (!mounted) return;
    setState(() {
      _items.removeWhere((e) => e.metaKey == item.metaKey);
      _grouped = _service.groupAndSort(_items, _sort);
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('«${item.title}» quitado de favoritos'),
      behavior: SnackBarBehavior.floating,
      backgroundColor: HubColors.panel,
    ));
  }

  String _relativeTime(DateTime at) {
    if (at.millisecondsSinceEpoch == 0) return 'Fecha desconocida';
    final d = DateTime.now().difference(at);
    if (d.inMinutes < 1) return 'Hace un momento';
    if (d.inHours < 1) return 'Hace ${d.inMinutes} min';
    if (d.inDays < 1) return 'Hace ${d.inHours} h';
    if (d.inDays == 1) return 'Marcado ayer';
    if (d.inDays < 30) return 'Marcado hace ${d.inDays} días';
    return 'Marcado hace ${(d.inDays / 30).floor()} mes(es)';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HubColors.fondoPrincipal,
      appBar: AppBar(
        backgroundColor: HubColors.fondoPrincipal,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: HubColors.textoPrincipal,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Favoritos', style: TextStyle(color: HubColors.textoPrincipal, fontWeight: FontWeight.w600, fontSize: 20)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: HubColors.textoSecundario),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: Column(children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(children: [
            for (final s in FavoriteSort.values) ...[
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(s.label),
                  selected: _sort == s,
                  onSelected: (_) => _setSort(s),
                  selectedColor: HubColors.pomelo,
                  labelStyle: TextStyle(color: _sort == s ? Colors.white : HubColors.textoSecundario, fontSize: 13),
                  backgroundColor: HubColors.panel,
                  checkmarkColor: Colors.white,
                ),
              ),
            ],
          ]),
        ),
        Expanded(child: _loading
          ? Center(child: CircularProgressIndicator(color: HubColors.pomelo))
          : _items.isEmpty
            ? Center(child: Text('Todavía no tienes favoritos', style: TextStyle(color: HubColors.textoSecundario)))
            : _buildList()),
      ]),
    );
  }

  Widget _buildList() {
    final types = _grouped.keys.toList()..sort((a, b) => a.sectionOrder.compareTo(b.sectionOrder));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: types.length,
      itemBuilder: (_, i) {
        final type = types[i];
        final list = _grouped[type]!;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 4 : 20, bottom: 10),
            child: Text('── ${type.sectionTitle} ──', style: TextStyle(color: HubColors.textoSecundario, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          ...list.map((item) => Card(
            color: HubColors.panel,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: item.iconBytes != null
                ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(item.iconBytes!, width: 40, height: 40, fit: BoxFit.cover))
                : Icon(type == FavoriteType.app ? Icons.android : type == FavoriteType.web ? Icons.public : Icons.folder, color: HubColors.pomelo),
              title: Text(item.title, style: TextStyle(color: HubColors.textoPrincipal, fontWeight: FontWeight.w600)),
              subtitle: Text(_relativeTime(item.favoritedAt), style: TextStyle(color: HubColors.textoSecundario, fontSize: 12)),
              trailing: IconButton(icon: Icon(Icons.star_rounded, color: HubColors.amarillo), onPressed: () => _remove(item)),
              onTap: () => _onTap(item),
            ),
          )),
        ]);
      },
    );
  }
}
