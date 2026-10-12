import 'package:flutter/services.dart';

import '../../../core/logger.dart';

/// Canal nativo de métricas gamer / overlay (anythings.hub/game_mode).
class GameNative {
  static const _ch = MethodChannel('anythings.hub/game_mode');

  static Future<T?> _call<T>(String method, [Map<String, dynamic>? args]) async {
    try {
      return await _ch.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      SystemLogger.log('GameNative.$method: ${e.message}');
      return null;
    } catch (e) {
      SystemLogger.log('GameNative.$method: $e');
      return null;
    }
  }

  static Future<bool> canDrawOverlays() async =>
      await _call<bool>('canDrawOverlays') ?? false;

  static Future<void> requestOverlayPermission() async {
    await _call<void>('requestOverlayPermission');
  }

  static Future<Map<String, dynamic>> displayMetrics() async {
    final m = await _call<Map>('getDisplayMetrics');
    if (m == null) return {};
    return Map<String, dynamic>.from(m);
  }

  static Future<Map<String, dynamic>> batteryStats() async {
    final m = await _call<Map>('getBatteryStats');
    if (m == null) return {};
    return Map<String, dynamic>.from(m);
  }

  static Future<bool> startHud({
    required String packageName,
    required String title,
    int targetFps = 0,
  }) async =>
      await _call<bool>('startHud', {
        'packageName': packageName,
        'title': title,
        'targetFps': targetFps,
      }) ??
      false;

  static Future<void> stopHud() async {
    await _call<void>('stopHud');
  }

  static Future<Map<String, dynamic>> hudSnapshot() async {
    final m = await _call<Map>('getHudSnapshot');
    if (m == null) return {};
    return Map<String, dynamic>.from(m);
  }

  static Future<bool> isHudActive() async =>
      await _call<bool>('isHudActive') ?? false;

  static Future<String?> foregroundPackage() async =>
      await _call<String>('getForegroundPackage');

  static Future<void> setScreenTimeoutSec(int seconds) async {
    await _call<void>('setScreenTimeoutSec', {'seconds': seconds});
  }

  static Future<int?> getScreenTimeoutSec() async =>
      await _call<int>('getScreenTimeoutSec');

  static Future<void> setBrightness({required double level, bool lock = false}) async {
    await _call<void>('setBrightness', {'level': level, 'lock': lock});
  }
}
