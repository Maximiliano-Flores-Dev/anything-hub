import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models.dart';
import '../../../services/device_apps_service.dart';
import '../../../services/performance_service.dart';
import '../models/game_profile.dart';
import 'game_native.dart';

/// Orquesta modo gamer: detección, booster, HUD, perfiles.
class GameModeService {
  GameModeService._();
  static final GameModeService instance = GameModeService._();

  static const _prefsKey = 'hub_game_profiles_v1';
  static const _prefsGlobal = 'hub_game_global_v1';
  static const _prefsSessions = 'hub_game_sessions_v1';

  final Map<String, GameProfile> _profiles = {};
  bool autoDetect = true;
  bool globalHud = true;
  bool globalBooster = true;
  String? _activeGame;
  GameSessionStats? _session;
  Timer? _poll;
  final _listeners = <void Function()>[];

  String? get activeGame => _activeGame;
  GameSessionStats? get session => _session;
  Map<String, GameProfile> get profiles => Map.unmodifiable(_profiles);

  void addListener(void Function() fn) => _listeners.add(fn);
  void removeListener(void Function() fn) => _listeners.remove(fn);
  void _notify() {
    for (final fn in List.of(_listeners)) {
      fn();
    }
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    _profiles.clear();
    if (raw != null && raw.isNotEmpty) {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      map.forEach((k, v) {
        if (v is Map) {
          _profiles[k] =
              GameProfile.fromJson(Map<String, dynamic>.from(v));
        }
      });
    }
    final g = prefs.getString(_prefsGlobal);
    if (g != null) {
      final m = jsonDecode(g) as Map<String, dynamic>;
      autoDetect = m['autoDetect'] != false;
      globalHud = m['globalHud'] != false;
      globalBooster = m['globalBooster'] != false;
    }
    _notify();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(_profiles.map((k, v) => MapEntry(k, v.toJson()))),
    );
    await prefs.setString(
      _prefsGlobal,
      jsonEncode({
        'autoDetect': autoDetect,
        'globalHud': globalHud,
        'globalBooster': globalBooster,
      }),
    );
  }

  GameProfile profileFor(String packageName, {String name = ''}) {
    return _profiles[packageName] ??
        GameProfile(packageName: packageName, displayName: name);
  }

  Future<void> saveProfile(GameProfile p) async {
    _profiles[p.packageName] = p;
    await _persist();
    _notify();
  }

  Future<void> setGlobal({
    bool? autoDetect,
    bool? globalHud,
    bool? globalBooster,
  }) async {
    if (autoDetect != null) this.autoDetect = autoDetect;
    if (globalHud != null) this.globalHud = globalHud;
    if (globalBooster != null) this.globalBooster = globalBooster;
    await _persist();
    _notify();
  }

  /// Solo apps con categoría estricta `game`.
  Future<List<DeviceAppInfo>> listGames() async {
    final all = await DeviceAppsService.listApps(days: 30) ?? [];
    final self = await DeviceAppsService.selfPackage();
    return all
        .where((a) => a.category == 'game' && a.packageName != self)
        .toList()
      ..sort((a, b) => b.usageMinutes.compareTo(a.usageMinutes));
  }

  Future<void> startWatching() async {
    await load();
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _tick());
  }

  void stopWatching() {
    _poll?.cancel();
    _poll = null;
  }

  Future<void> _tick() async {
    if (!autoDetect) return;
    final fg = await GameNative.foregroundPackage();
    if (fg == null || fg.isEmpty) return;
    final games = await listGames();
    final isGame = games.any((g) => g.packageName == fg);
    if (isGame && fg != _activeGame) {
      final info = games.firstWhere((g) => g.packageName == fg);
      await enterGame(info);
    } else if (!isGame && _activeGame != null) {
      await exitGame();
    }
  }

  Future<void> enterGame(DeviceAppInfo game) async {
    final p = profileFor(game.packageName, name: game.name);
    _activeGame = game.packageName;
    _session = GameSessionStats(
      packageName: game.packageName,
      startedAt: DateTime.now(),
    );

    if (p.boosterOnLaunch && globalBooster) {
      await PerformanceService.applyMode(PerfMode.performance);
    }
    if (p.focusOnLaunch || p.blockNotifications) {
      await PerformanceService.applyFocusNotifications(enable: true);
    }
    if (p.extendScreenTimeout) {
      await GameNative.setScreenTimeoutSec(600);
    }
    if (p.showHud && globalHud) {
      final ok = await GameNative.canDrawOverlays();
      if (!ok) {
        await GameNative.requestOverlayPermission();
      } else {
        await GameNative.startHud(
          packageName: game.packageName,
          title: game.name,
          targetFps: p.targetFps,
        );
      }
    }
    _notify();
  }

  Future<void> exitGame() async {
    await GameNative.stopHud();
    await PerformanceService.applyFocusNotifications(enable: false);
    await PerformanceService.applyMode(PerfMode.balanced);
    if (_session != null) {
      final snap = await GameNative.hudSnapshot();
      _session = GameSessionStats(
        packageName: _session!.packageName,
        startedAt: _session!.startedAt,
        endedAt: DateTime.now(),
        peakFps: (snap['peakFps'] as num?)?.toDouble() ?? 0,
        avgFps: (snap['avgFps'] as num?)?.toDouble() ?? 0,
        minRamMb: (snap['minRamMb'] as num?)?.toInt() ?? 0,
      );
      await _saveSession(_session!);
    }
    _activeGame = null;
    _notify();
  }

  Future<void> _saveSession(GameSessionStats s) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsSessions);
    final list = <Map<String, dynamic>>[];
    if (raw != null) {
      final d = jsonDecode(raw);
      if (d is List) {
        for (final e in d) {
          if (e is Map) list.add(Map<String, dynamic>.from(e));
        }
      }
    }
    list.insert(0, {
      'packageName': s.packageName,
      'startedAt': s.startedAt.toIso8601String(),
      'endedAt': s.endedAt?.toIso8601String(),
      'peakFps': s.peakFps,
      'avgFps': s.avgFps,
      'minRamMb': s.minRamMb,
      'durationSec': s.duration.inSeconds,
    });
    await prefs.setString(
        _prefsSessions, jsonEncode(list.take(40).toList()));
  }

  Future<void> boostNow() async {
    await PerformanceService.applyMode(PerfMode.performance);
    await PerformanceService.trimUnnecessaryBackground(
        aggressiveness: 'performance');
  }

  Future<void> optimizeNonGames() async {
    await PerformanceService.trimUnnecessaryBackground(
        aggressiveness: 'performance');
  }
}
