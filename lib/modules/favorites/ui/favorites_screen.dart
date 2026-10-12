import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/hub_colors.dart';
import '../../../screens/file_explorer_screen.dart';
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
  FavoriteType? _typeFilter;
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
      _grouped = _service.groupAndSort(items, _sort, typeFilter: _typeFilter);
      _loading = false;
    });
  }

  void _applyView() {
    setState(() {
      _grouped = _service.groupAndSort(_items, _sort, typeFilter: _typeFilter);
    });
  }

  void _setSort(FavoriteSort sort) {
    if (sort == _sort) return;
    _sort = sort;
    _applyView();
  }

  void _setTypeFilter(FavoriteType? type) {
    if (type == _typeFilter) return;
    _typeFilter = type;
    _applyView();
  }

  Future<void> _onTap(FavoriteItem item) async {
    switch (item.type) {
      case FavoriteType.app:
        if (item.packageName != null) {
          await DeviceAppsService.launch(item.packageName!);
        }
        break;
      case FavoriteType.web:
        if (item.url != null) {
          final uri = Uri.tryParse(item.url!);
          if (uri != null) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
        break;
      case FavoriteType.file:
        await _openFileOrFolder(item);
        break;
    }
  }

  Future<void> _openFileOrFolder(FavoriteItem item) async {
    final path = item.path;
    if (path == null || path.isEmpty) return;

    if (item.isDirectory) {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => FileExplorerScreen(initialPath: path),
        ),
      );
      return;
    }

    final ok = await DeviceFilesService.openFile(path);
    if (!ok && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => FileExplorerScreen(initialPath: path),
        ),
      );
    }
  }

  Future<void> _remove(FavoriteItem item) async {
    await _service.remove(item);
    if (!mounted) return;
    setState(() {
      _items.removeWhere((e) => e.metaKey == item.metaKey);
      _grouped = _service.groupAndSort(_items, _sort, typeFilter: _typeFilter);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('«${item.title}» quitado de favoritos'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: HubColors.panel,
      ),
    );
  }

  String _relativeTime(DateTime at) {
    final d = DateTime.now().difference(at);
    if (d.inMinutes < 1) return 'Hace un momento';
    if (d.inHours < 1) return 'Hace ${d.inMinutes} min';
    if (d.inDays < 1) return 'Hace ${d.inHours} h';
    if (d.inDays == 1) return 'Marcado ayer';
    if (d.inDays < 30) return 'Marcado hace ${d.inDays} días';
    final months = (d.inDays / 30).floor();
    if (months < 12) {
      return 'Marcado hace $months mes${months > 1 ? 'es' : ''}';
    }
    final years = (d.inDays / 365).floor();
    return 'Marcado hace $years año${years > 1 ? 's' : ''}';
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
        title: Text(
          'Favoritos',
          style: TextStyle(
            color: HubColors.textoPrincipal,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: HubColors.textoSecundario),
            tooltip: 'Actualizar',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSortChips(),
          _buildTypeFilterChips(),
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(color: HubColors.pomelo))
                : _items.isEmpty
                    ? _buildEmpty()
                    : _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSortChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          for (final sort in FavoriteSort.values) ...[
            _Chip(
                label: sort.label,
                selected: _sort == sort,
                onTap: () => _setSort(sort)),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildTypeFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          _Chip(
              label: 'Todos',
              selected: _typeFilter == null,
              onTap: () => _setTypeFilter(null)),
          const SizedBox(width: 8),
          for (final t in FavoriteType.values) ...[
            _Chip(
                label: t.sectionTitle,
                selected: _typeFilter == t,
                onTap: () => _setTypeFilter(t)),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_outline_rounded,
                size: 64, color: HubColors.textoSecundario.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              'Todavía no tienes favoritos',
              style: TextStyle(
                  color: HubColors.textoPrincipal,
                  fontSize: 18,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Marca apps, webs o carpetas con la estrella\ny aparecerán aquí.',
              style: TextStyle(color: HubColors.textoSecundario, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_grouped.isEmpty) {
      return Center(
          child: Text('Nada en este filtro',
              style: TextStyle(color: HubColors.textoSecundario)));
    }
    final types = _grouped.keys.toList()
      ..sort((a, b) => a.sectionOrder.compareTo(b.sectionOrder));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: types.length,
      itemBuilder: (context, sectionIndex) {
        final type = types[sectionIndex];
        final list = _grouped[type]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding:
                  EdgeInsets.only(top: sectionIndex == 0 ? 4 : 20, bottom: 10),
              child: Text(
                '── ${type.sectionTitle} ──',
                style: TextStyle(
                    color: HubColors.textoSecundario,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5),
              ),
            ),
            ...list.map((item) => _FavoriteTile(
                  item: item,
                  relativeTime: _relativeTime(item.favoritedAt),
                  onTap: () => _onTap(item),
                  onRemove: () => _remove(item),
                )),
          ],
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? HubColors.pomelo : HubColors.panel,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: selected
                ? null
                : Border.all(color: HubColors.linea.withOpacity(0.6)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : HubColors.textoSecundario,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FavoriteTile extends StatelessWidget {
  const _FavoriteTile({
    required this.item,
    required this.relativeTime,
    required this.onTap,
    required this.onRemove,
  });

  final FavoriteItem item;
  final String relativeTime;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  Color get _badgeColor {
    switch (item.type) {
      case FavoriteType.app:
        return HubColors.pomelo;
      case FavoriteType.web:
        return const Color(0xFF3B82F6);
      case FavoriteType.file:
        return const Color(0xFF8B5CF6);
    }
  }

  Widget _buildLeading() {
    if (item.type == FavoriteType.app && item.iconBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(
          item.iconBytes!,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallbackIcon(),
        ),
      );
    }
    return _fallbackIcon();
  }

  Widget _fallbackIcon() {
    final IconData icon;
    final Color bg;
    switch (item.type) {
      case FavoriteType.app:
        icon = Icons.android_rounded;
        bg = HubColors.pomelo.withOpacity(0.2);
        break;
      case FavoriteType.web:
        icon = Icons.public_rounded;
        bg = const Color(0xFF3B82F6).withOpacity(0.2);
        break;
      case FavoriteType.file:
        icon = item.isDirectory
            ? Icons.folder_rounded
            : Icons.insert_drive_file_rounded;
        bg = const Color(0xFF8B5CF6).withOpacity(0.2);
        break;
    }
    return Container(
      width: 40,
      height: 40,
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, size: 22, color: _badgeColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: HubColors.panel,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: HubColors.linea.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                _buildLeading(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.title,
                              style: TextStyle(
                                  color: HubColors.textoPrincipal,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _badgeColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.type.label,
                              style: TextStyle(
                                  color: _badgeColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        relativeTime,
                        style: TextStyle(
                            color: HubColors.textoSecundario, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.star_rounded,
                      color: HubColors.amarillo, size: 22),
                  tooltip: 'Quitar de favoritos',
                  onPressed: onRemove,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
