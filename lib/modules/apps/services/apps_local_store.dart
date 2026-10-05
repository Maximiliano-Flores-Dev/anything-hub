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
