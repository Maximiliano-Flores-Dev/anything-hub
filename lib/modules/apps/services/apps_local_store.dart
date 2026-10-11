import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_models.dart';

/// Persistencia local de bookmarks y reseñas (SharedPreferences).
/// Puede migrarse a Room/SQLite sin cambiar la API pública.
class AppsLocalStore {
  static const _kBookmarks = 'apps.bookmarks';
  static const _kReviews = 'apps.reviews';

  Future<Set<String>> loadBookmarks() async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(_kBookmarks) ?? const [];
    return list.toSet();
  }

  Future<void> setBookmarked(String packageName, bool value) async {
    final p = await SharedPreferences.getInstance();
    final set = (p.getStringList(_kBookmarks) ?? []).toSet();
    if (value) {
      set.add(packageName);
    } else {
      set.remove(packageName);
    }
    await p.setStringList(_kBookmarks, set.toList());
    // Timestamp para la colección unificada de Favoritos
    await _touchFavoriteMeta(p, 'app:$packageName', value);
  }

  static const _kFavMeta = 'favorites_meta_v1';

  static Future<void> _touchFavoriteMeta(
    SharedPreferences p,
    String key,
    bool add,
  ) async {
    try {
      final raw = p.getString(_kFavMeta);
      final meta = <String, dynamic>{};
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          decoded.forEach((k, v) => meta[k.toString()] = v);
        }
      }
      if (add) {
        meta[key] = DateTime.now().toIso8601String();
      } else {
        meta.remove(key);
      }
      await p.setString(_kFavMeta, jsonEncode(meta));
    } catch (_) {
      // No romper el bookmark si el meta falla
    }
  }

  Future<Map<String, LocalAppReview>> loadReviews() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kReviews);
    if (raw == null || raw.isEmpty) return {};
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map.map(
      (k, v) => MapEntry(k, LocalAppReview.fromJson(v as Map<String, dynamic>)),
    );
  }

  Future<void> saveReview(String packageName, LocalAppReview review) async {
    final p = await SharedPreferences.getInstance();
    final all = await loadReviews();
    all[packageName] = review;
    final encoded = jsonEncode(
      all.map((k, v) => MapEntry(k, v.toJson())),
    );
    await p.setString(_kReviews, encoded);
  }
}
