import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../core/logger.dart';
import '../core/models.dart';

class DeviceAppsService {
  static const MethodChannel _ch = MethodChannel('anythings.hub/device_apps');

  static Future<T?> _call<T>(String method, [dynamic args]) async {
    try {
      return await _ch.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null; // Plataforma sin implementación nativa (iOS, web, escritorio)
    } on PlatformException catch (e) {
      SystemLogger.log('Canal nativo "$method" falló: ${e.message}');
      return null;
    }
  }

  static Future<String> selfPackage() async =>
      await _call<String>('selfPackage') ?? '';

  static Future<bool> hasUsageAccess() async =>
      await _call<bool>('hasUsageAccess') ?? false;

  static Future<void> openUsageAccessSettings() async {
    await _call<Object?>('openUsageAccessSettings');
  }

  static Future<bool> launch(String packageName) async =>
      await _call<bool>('launchApp', {'package': packageName}) ?? false;

  static Future<bool> openAppSettings(String packageName) async =>
      await _call<bool>('openAppSettings', {'package': packageName}) ?? false;

  static Future<bool> requestUninstall(String packageName) async =>
      await _call<bool>('requestUninstall', {'package': packageName}) ?? false;

  static Future<bool> installApkFromCache(String cacheRelativePath) async =>
      await _call<bool>('installApkFromCache', {
            'cacheRelativePath': cacheRelativePath,
          }) ??
          false;

  /// Devuelve el payload del último APK recibido (VIEW/SEND) o null si no hay.
  /// Tras leerlo se limpia en nativo.
  static Future<Map<String, dynamic>?> consumePendingIncomingApk() async {
    final raw = await _call<Map<dynamic, dynamic>>('consumePendingIncomingApk');
    if (raw == null) return null;
    return raw.map((k, v) => MapEntry(k.toString(), v));
  }

  static Future<String?> loadState() => _call<String>('loadState');

  static Future<void> saveState(String json) async {
    await _call<Object?>('saveState', {'json': json});
  }

  /// Devuelve null si el escaneo no es posible en esta plataforma.
  static Future<List<DeviceAppInfo>?> listApps({int days = 14}) async {
    final raw = await _call<List<dynamic>>('listApps', {'days': days});
    if (raw == null) return null;
    return raw.whereType<Map>().map((m) {
      return DeviceAppInfo(
        packageName: m['package'] as String,
        name: m['name'] as String,
        category: (m['category'] as String?) ?? 'undefined',
        usageMinutes: ((m['usageMs'] as num?) ?? 0).toInt() ~/ 60000,
        icon: m['icon'] as Uint8List?,
      );
    }).toList();
  }
}

/// Decide a qué categoría automática pertenece una app real.
String classifyApp(DeviceAppInfo app) {
  final haystack = '${app.packageName} ${app.name}'.toLowerCase();
  if (kAiKeywords.any(haystack.contains)) return 'ai';
  final known = kAutoCategories.any((c) => c.id == app.category);
  return known ? app.category : 'other';
}
