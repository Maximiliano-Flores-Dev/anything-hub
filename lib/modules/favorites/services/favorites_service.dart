import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models.dart';
import '../../../screens/web_links_screen.dart';
import '../../../services/device_apps_service.dart';
import '../../apps/services/apps_local_store.dart';
import '../models/favorite_item.dart';

/// Agrega favoritos de apps, webs y archivos en una colección unificada.
///
/// - Apps: bookmarks de [AppsLocalStore]
/// - Archivos: lista `file_explorer_favorites`
/// - Webs: todos los [WebLinkItem] (Webs Rápidas = favoritos de enlaces)
///
/// Timestamps se guardan en `favorites_meta_v1` para ordenar por fecha.
class FavoritesService {
  FavoritesService({
    AppsLocalStore? appsStore,
    WebLinkRepository? webRepo,
  })  : _appsStore = appsStore ?? AppsLocalStore(),
        _webRepo = webRepo ?? WebLinkRepository();

  final AppsLocalStore _appsStore;
  final WebLinkRepository _webRepo;

  static const _metaKey = 'favorites_meta_v1';
  static const _fileFavKey = 'file_explorer_favorites';

  /// Carga la colección completa (sin ordenar).
  Future<List<FavoriteItem>> loadAll() async {
    final meta = await _loadMeta();
    final items = <FavoriteItem>[];

    // Apps
    final bookmarks = await _appsStore.loadBookmarks();
    if (bookmarks.isNotEmpty) {
      final raw = await DeviceAppsService.listApps(days: 14);
      final self = await DeviceAppsService.selfPackage();
      final byPackage = <String, DeviceAppInfo>{};
      if (raw != null) {
        for (final a in raw) {
          if (a.packageName == self) continue;
          byPackage[a.packageName] = a;
        }
      }

      for (final pkg in bookmarks) {
        final info = byPackage[pkg];
        final at = meta['${FavoriteType.app.name}:$pkg'] ??
            DateTime.fromMillisecondsSinceEpoch(0);
        items.add(FavoriteItem(
          type: FavoriteType.app,
          id: pkg,
          title: info?.name ?? pkg,
          subtitle: null,
          favoritedAt: at,
          iconBytes: info?.icon,
          packageName: pkg,
        ));
      }
    }

    // Webs
    await _webRepo.load();
    for (final link in _webRepo.items) {
      final at = meta['${FavoriteType.web.name}:${link.id}'] ??
          DateTime.fromMillisecondsSinceEpoch(0);
      items.add(FavoriteItem(
        type: FavoriteType.web,
        id: link.id,
        title: link.title,
        subtitle: link.host.isNotEmpty ? link.host : null,
        favoritedAt: at,
        url: link.url,
      ));
    }

    // Archivos
    final prefs = await SharedPreferences.getInstance();
    final filePaths = prefs.getStringList(_fileFavKey) ?? const [];
    for (final path in filePaths) {
      final parts = path.split('/').where((s) => s.isNotEmpty).toList();
      final name = parts.isEmpty ? path : parts.last;
      final at = meta['${FavoriteType.file.name}:$path'] ??
          DateTime.fromMillisecondsSinceEpoch(0);
      items.add(FavoriteItem(
        type: FavoriteType.file,
        id: path,
        title: name,
        subtitle: path,
        favoritedAt: at,
        path: path,
      ));
    }

    return items;
  }

  /// Agrupa por tipo y aplica el orden solicitado dentro de cada sección.
  Map<FavoriteType, List<FavoriteItem>> groupAndSort(
    List<FavoriteItem> items,
    FavoriteSort sort,
  ) {
    final grouped = <FavoriteType, List<FavoriteItem>>{
      for (final t in FavoriteType.values) t: <FavoriteItem>[],
    };

    for (final item in items) {
      grouped[item.type]!.add(item);
    }

    final sectionOrder = List<FavoriteType>.from(FavoriteType.values);

    for (final type in sectionOrder) {
      final list = grouped[type]!;
      switch (sort) {
        case FavoriteSort.alphaAsc:
          list.sort((a, b) =>
              a.title.toLowerCase().compareTo(b.title.toLowerCase()));
          break;
        case FavoriteSort.recent:
          list.sort((a, b) => b.favoritedAt.compareTo(a.favoritedAt));
          break;
        case FavoriteSort.oldest:
          list.sort((a, b) => a.favoritedAt.compareTo(b.favoritedAt));
          break;
        case FavoriteSort.byType:
          list.sort((a, b) =>
              a.title.toLowerCase().compareTo(b.title.toLowerCase()));
          break;
      }
    }

    grouped.removeWhere((_, list) => list.isEmpty);
    return grouped;
  }

  /// Quita un favorito de su store de origen y limpia el meta.
  Future<void> remove(FavoriteItem item) async {
    switch (item.type) {
      case FavoriteType.app:
        await _appsStore.setBookmarked(item.id, false);
        break;
      case FavoriteType.web:
        await _webRepo.load();
        await _webRepo.remove(item.id);
        break;
      case FavoriteType.file:
        final prefs = await SharedPreferences.getInstance();
        final list = prefs.getStringList(_fileFavKey) ?? [];
        list.remove(item.id);
        await prefs.setStringList(_fileFavKey, list);
        break;
    }
    await _removeMeta(item.metaKey);
  }

  /// Registra o actualiza la fecha de favorito (llamar al marcar).
  Future<void> touchMeta(String metaKey, {DateTime? at}) async {
    final meta = await _loadMeta();
    meta[metaKey] = at ?? DateTime.now();
    await _saveMeta(meta);
  }

  Future<Map<String, DateTime>> _loadMeta() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_metaKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) {
        final dt = DateTime.tryParse(v as String);
        return MapEntry(k, dt ?? DateTime.fromMillisecondsSinceEpoch(0));
      });
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveMeta(Map<String, DateTime> meta) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      meta.map((k, v) => MapEntry(k, v.toIso8601String())),
    );
    await prefs.setString(_metaKey, encoded);
  }

  Future<void> _removeMeta(String key) async {
    final meta = await _loadMeta();
    meta.remove(key);
    await _saveMeta(meta);
  }
}
