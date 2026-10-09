import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'hub_palette.dart';

/// IDs estables de las cards del dashboard (orden por defecto).
abstract final class DashboardCardIds {
  static const String apps = 'apps';
  static const String projects = 'projects';
  static const String webs = 'webs';
  static const String favorites = 'favorites';
  static const String files = 'files';
  static const String performance = 'performance';

  static const List<String> defaultOrder = [
    apps,
    projects,
    webs,
    favorites,
    files,
    performance,
  ];

  static const Map<String, String> labels = {
    apps: 'Mis Aplicaciones',
    projects: 'Carpetas del Proyecto',
    webs: 'Webs Rápidas',
    favorites: 'Favoritos',
    files: 'Gestión de Archivos',
    performance: 'Modos de Rendimiento',
  };
}

/// Estado de personalización macro de la app (persistente).
class MacroCustomization extends ChangeNotifier {
  MacroCustomization._();

  static final MacroCustomization instance = MacroCustomization._();

  static const _prefsKey = 'macro_customization_v1';

  HubPaletteId _paletteId = HubPaletteId.classic;
  bool _sidebarEnabled = true;
  bool _leftHandedMode = false;
  /// Orden de cards visibles. Las que no están aquí están desactivadas.
  List<String> _activeCardIds = List.of(DashboardCardIds.defaultOrder);

  HubPaletteId get paletteId => _paletteId;
  HubPalette get palette => HubPalettes.byId(_paletteId);
  bool get sidebarEnabled => _sidebarEnabled;
  bool get leftHandedMode => _leftHandedMode;
  List<String> get activeCardIds => List.unmodifiable(_activeCardIds);

  bool isCardActive(String id) => _activeCardIds.contains(id);

  /// Carga desde SharedPreferences. Llamar una sola vez al arranque.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _paletteId = HubPalettes.byIdString(data['palette'] as String?).id;
      _sidebarEnabled = data['sidebarEnabled'] as bool? ?? true;
      _leftHandedMode = data['leftHandedMode'] as bool? ?? false;
      final cards = (data['activeCards'] as List<dynamic>?)
          ?.map((e) => e as String)
          .where((id) => DashboardCardIds.labels.containsKey(id))
          .toList();
      if (cards != null && cards.isNotEmpty) {
        _activeCardIds = cards;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('MacroCustomization.load: $e');
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode({
          'palette': _paletteId.name,
          'sidebarEnabled': _sidebarEnabled,
          'leftHandedMode': _leftHandedMode,
          'activeCards': _activeCardIds,
        }),
      );
    } catch (e) {
      debugPrint('MacroCustomization.persist: $e');
    }
  }

  Future<void> setPalette(HubPaletteId id) async {
    if (_paletteId == id) return;
    _paletteId = id;
    notifyListeners();
    await _persist();
  }

  Future<void> setSidebarEnabled(bool value) async {
    if (_sidebarEnabled == value) return;
    _sidebarEnabled = value;
    notifyListeners();
    await _persist();
  }

  Future<void> setLeftHandedMode(bool value) async {
    if (_leftHandedMode == value) return;
    _leftHandedMode = value;
    notifyListeners();
    await _persist();
  }

  Future<void> setActiveCards(List<String> orderedIds) async {
    // Preservar orden del parámetro y filtrar IDs desconocidos.
    final ordered = <String>[];
    for (final id in orderedIds) {
      if (DashboardCardIds.labels.containsKey(id) && !ordered.contains(id)) {
        ordered.add(id);
      }
    }
    if (listEquals(ordered, _activeCardIds)) return;
    _activeCardIds = ordered.isEmpty
        ? [DashboardCardIds.apps] // al menos una card
        : ordered;
    notifyListeners();
    await _persist();
  }

  Future<void> toggleCard(String id, {bool? enable}) async {
    if (!DashboardCardIds.labels.containsKey(id)) return;
    final currently = _activeCardIds.contains(id);
    final want = enable ?? !currently;
    if (want == currently) return;
    final next = List<String>.of(_activeCardIds);
    if (want) {
      next.add(id);
    } else {
      if (next.length <= 1) return; // no dejar dashboard vacío
      next.remove(id);
    }
    await setActiveCards(next);
  }

  Future<void> reorderCard(int oldIndex, int newIndex) async {
    if (oldIndex < 0 ||
        oldIndex >= _activeCardIds.length ||
        newIndex < 0 ||
        newIndex > _activeCardIds.length) {
      return;
    }
    final next = List<String>.of(_activeCardIds);
    final item = next.removeAt(oldIndex);
    final insertAt = newIndex > oldIndex ? newIndex - 1 : newIndex;
    next.insert(insertAt, item);
    await setActiveCards(next);
  }

  Future<void> resetToDefaults() async {
    _paletteId = HubPaletteId.classic;
    _sidebarEnabled = true;
    _leftHandedMode = false;
    _activeCardIds = List.of(DashboardCardIds.defaultOrder);
    notifyListeners();
    await _persist();
  }
}
