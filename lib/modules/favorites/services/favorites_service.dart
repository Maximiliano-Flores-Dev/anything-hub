import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models.dart';
import '../../../screens/web_links_screen.dart';
import '../../../services/device_apps_service.dart';
import '../../apps/services/apps_local_store.dart';
import '../models/favorite_item.dart';

/// Colección unificada de favoritos.
///
/// - Apps: bookmarks de [AppsLocalStore]
/// - Archivos: `file_explorer_favorites`
/// - Webs: ids en `web_link_favorites` (estrella propia, no todas las webs)
///
/// Timestamps en `favorites_meta_v1`. Favoritos sin fecha reciben
/// [DateTime.now] la primera vez que se cargan (migración 1.4).
class FavoritesService {
  FavoritesService({
    AppsLocalStore? appsStore,
    WebLinkRepository? webRepo,
  })  : _appsStore = appsStore ?? AppsLocalStore(),
        _webRepo = webRepo ?? WebLinkRepository();

  final AppsLocalStore _appsStore;
  final WebLinkRepository _webRepo;

  static const metaKey = 'favorites_meta_v1';
  static const fileFavKey = 'file_explorer_favorites';
  static const webFavKey = 'web_link_favorites';

  /// Carga favoritos y, si hay alguno sin fecha, le asigna ahora y persiste.
  Future<List<FavoriteItem>> loadAll() async {
    final meta = await _loadMeta();
    final items = <FavoriteItem>[];
    final now = DateTime.now();
    var metaDirty = false;

    DateTime resolveDate(String key) {
      final existing = meta[key];
      if (existing != null && existing.millisecondsSinceEpoch > 0) {
        return existing;
      }
      meta[key] = now;
      metaDirty = true;
      return now;
    }

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
        final key = '${FavoriteType.app.name}:$pkg';
        items.add(FavoriteItem(
          type: FavoriteType.app,
          id: pkg,
          title: info?.name ?? pkg,
          favoritedAt: resolveDate(key),
          iconBytes: info?.icon,
          packageName: pkg,
        ));
      }
    }

    // Webs (solo las marcadas con estrella)
    await _webRepo.load();
    final webFavs = await loadWebFavorites();
    final linksById = {for (final l in _webRepo.items) l.id: l};
    for (final id in webFavs) {
      final link = linksById[id];
      if (link == null) continue;
      final key = '${FavoriteType.web.name}:$id';
      items.add(FavoriteItem(
        type: FavoriteType.web,
        id: id,
        title: link.title,
        subtitle: link.host.isNotEmpty ? link.host : null,
        favoritedAt: resolveDate(key),
        url: link.url,
      ));
    }

    // Archivos
    final prefs = await SharedPreferences.getInstance();
    final filePaths = prefs.getStringList(fileFavKey) ?? const [];
    for (final path in filePaths) {
      final parts = path.split('/').where((s) => s.isNotEmpty).toList();
      final name = parts.isEmpty ? path : parts.last;
      final key = '${FavoriteType.file.name}:$path';
      final looksDir = !name.contains('.') || path.endsWith('/');
      items.add(FavoriteItem(
        type: FavoriteType.file,
        id: path,
        title: name,
        subtitle: path,
        favoritedAt: resolveDate(key),
        path: path,
        isDirectory: looksDir,
      ));
    }

    if (metaDirty) {
      await _saveMeta(meta);
    }
    return items;
  }

  /// Agrupa por tipo, aplica orden y filtro opcional de tipo.
  Map<FavoriteType, List<FavoriteItem>> groupAndSort(
    List<FavoriteItem> items,
    FavoriteSort sort, {
    FavoriteType? typeFilter,
  }) {
    final filtered = typeFilter == null
        ? items
        : items.where((e) => e.type == typeFilter).toList();

    final grouped = <FavoriteType, List<FavoriteItem>>{
      for (final t in FavoriteType.values) t: <FavoriteItem>[],
    };
    for (final item in filtered) {
      grouped[item.type]!.add(item);
    }

    for (final type in FavoriteType.values) {
      final list = grouped[type]!;
      switch (sort) {
        case FavoriteSort.alphaAsc:
          list.sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
          );
          break;
        case FavoriteSort.recent:
          list.sort((a, b) => b.favoritedAt.compareTo(a.favoritedAt));
          break;
        case FavoriteSort.oldest:
          list.sort((a, b) => a.favoritedAt.compareTo(b.favoritedAt));
          break;
      }
    }

    grouped.removeWhere((_, list) => list.isEmpty);
    return grouped;
  }

  Future<void> remove(FavoriteItem item) async {
    switch (item.type) {
      case FavoriteType.app:
        await _appsStore.setBookmarked(item.id, false);
        break;
      case FavoriteType.web:
        await setWebFavorite(item.id, false);
        break;
      case FavoriteType.file:
        final prefs = await SharedPreferences.getInstance();
        final list = prefs.getStringList(fileFavKey) ?? [];
        list.remove(item.id);
        await prefs.setStringList(fileFavKey, list);
        break;
    }
    await _removeMeta(item.metaKey);
  }

  Future<Set<String>> loadWebFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(webFavKey) ?? const [];
    return list.toSet();
  }

  Future<void> setWebFavorite(String webId, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final set = (prefs.getStringList(webFavKey) ?? []).toSet();
    if (value) {
      set.add(webId);
    } else {
      set.remove(webId);
    }
    await prefs.setStringList(webFavKey, set.toList());
    await touchMeta('${FavoriteType.web.name}:$webId', add: value);
  }

  Future<bool> isWebFavorite(String webId) async {
    final set = await loadWebFavorites();
    return set.contains(webId);
  }

  Future<void> touchMeta(String key, {required bool add, DateTime? at}) async {
    final meta = await _loadMeta();
    if (add) {
      meta[key] = at ?? DateTime.now();
    } else {
      meta.remove(key);
    }
    await _saveMeta(meta);
  }

  Future<Map<String, DateTime>> _loadMeta() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(metaKey);
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
    await prefs.setString(metaKey, encoded);
  }

  Future<void> _removeMeta(String key) async {
    final meta = await _loadMeta();
    meta.remove(key);
    await _saveMeta(meta);
  }
}
