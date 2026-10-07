import 'package:flutter/services.dart';

import '../core/logger.dart';

/// Modos de rendimiento del núcleo (sin modo juego).
enum PerfMode {
  balanced,
  eco,
  focus,
  performance,
}

extension PerfModeX on PerfMode {
  String get id {
    switch (this) {
      case PerfMode.balanced:
        return 'balanced';
      case PerfMode.eco:
        return 'eco';
      case PerfMode.focus:
        return 'focus';
      case PerfMode.performance:
        return 'performance';
    }
  }

  String get label {
    switch (this) {
      case PerfMode.balanced:
        return 'Equilibrado';
      case PerfMode.eco:
        return 'Eco';
      case PerfMode.focus:
        return 'Focus';
      case PerfMode.performance:
        return 'Rendimiento';
    }
  }

  String get description {
    switch (this) {
      case PerfMode.balanced:
        return 'Sin cambios agresivos. El sistema gestiona procesos con normalidad.';
      case PerfMode.eco:
        return 'Prioriza batería: cierra procesos en segundo plano innecesarios de apps de usuario.';
      case PerfMode.focus:
        return 'Silencia notificaciones de terceros (siguen visibles, sin sonido) y limpia procesos innecesarios para concentrarte en una tarea.';
      case PerfMode.performance:
        return 'Libera memoria cerrando solo procesos en segundo plano innecesarios de apps no críticas.';
    }
  }

  static PerfMode fromId(String? id) {
    switch (id) {
      case 'eco':
        return PerfMode.eco;
      case 'focus':
        return PerfMode.focus;
      case 'performance':
        return PerfMode.performance;
      default:
        return PerfMode.balanced;
    }
  }
}

class MemorySnapshot {
  const MemorySnapshot({
    required this.availMb,
    required this.totalMb,
    required this.lowMemory,
    required this.thresholdMb,
  });

  final int availMb;
  final int totalMb;
  final bool lowMemory;
  final int thresholdMb;

  double get usedRatio {
    if (totalMb <= 0) return 0;
    return ((totalMb - availMb) / totalMb).clamp(0.0, 1.0);
  }

  factory MemorySnapshot.fromMap(Map m) => MemorySnapshot(
        availMb: (m['availMb'] as num?)?.toInt() ?? 0,
        totalMb: (m['totalMb'] as num?)?.toInt() ?? 0,
        lowMemory: m['lowMemory'] == true,
        thresholdMb: (m['thresholdMb'] as num?)?.toInt() ?? 0,
      );
}

class TrimResult {
  const TrimResult({
    required this.attempted,
    required this.killed,
    required this.packages,
    this.note = '',
  });

  final int attempted;
  final int killed;
  final List<String> packages;
  final String note;

  factory TrimResult.fromMap(Map m) => TrimResult(
        attempted: (m['attempted'] as num?)?.toInt() ?? 0,
        killed: (m['killed'] as num?)?.toInt() ?? 0,
        packages: (m['packages'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        note: (m['note'] as String?) ?? '',
      );
}

/// Canal nativo de rendimiento. Best-effort en Android sin root:
/// - Memoria vía ActivityManager
/// - Focus vía política de notificaciones (INTERRUPTION_FILTER)
/// - Limpieza de segundo plano solo de apps de usuario no críticas
class PerformanceService {
  static const _ch = MethodChannel('anythings.hub/performance');

  static Future<T?> _call<T>(String method, [Map<String, dynamic>? args]) async {
    try {
      return await _ch.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      SystemLogger.log('Perf "$method": ${e.message}');
      return null;
    }
  }

  static Future<MemorySnapshot?> memoryInfo() async {
    final raw = await _call<Map>('getMemoryInfo');
    if (raw == null) return null;
    return MemorySnapshot.fromMap(raw);
  }

  static Future<bool> hasNotificationPolicyAccess() async =>
      await _call<bool>('hasNotificationPolicyAccess') ?? false;

  static Future<void> openNotificationPolicySettings() async {
    await _call<Object?>('openNotificationPolicySettings');
  }

  static Future<bool> applyFocusNotifications({required bool enable}) async =>
      await _call<bool>('setFocusNotifications', {'enable': enable}) ?? false;

  /// Cierra procesos en segundo plano *innecesarios* (apps de usuario, no sistema).
  static Future<TrimResult?> trimUnnecessaryBackground({
    required String aggressiveness, // 'eco' | 'performance' | 'focus'
  }) async {
    final raw = await _call<Map>('trimUnnecessaryBackground', {
      'aggressiveness': aggressiveness,
    });
    if (raw == null) return null;
    return TrimResult.fromMap(raw);
  }

  static Future<String?> getActiveMode() async =>
      await _call<String>('getActiveMode');

  static Future<void> setActiveMode(String modeId) async {
    await _call<Object?>('setActiveMode', {'mode': modeId});
  }

  static Future<Map<String, dynamic>?> applyMode(PerfMode mode) async {
    final prev = await getActiveMode();
    if (prev == 'focus' && mode != PerfMode.focus) {
      await applyFocusNotifications(enable: false);
    }

    TrimResult? trim;
    bool? focusOk;

    switch (mode) {
      case PerfMode.balanced:
        break;
      case PerfMode.eco:
        trim = await trimUnnecessaryBackground(aggressiveness: 'eco');
        break;
      case PerfMode.focus:
        focusOk = await applyFocusNotifications(enable: true);
        trim = await trimUnnecessaryBackground(aggressiveness: 'focus');
        break;
      case PerfMode.performance:
        trim = await trimUnnecessaryBackground(aggressiveness: 'performance');
        break;
    }

    await setActiveMode(mode.id);
    return {
      'mode': mode.id,
      'focusNotifications': focusOk,
      'trim': trim == null
          ? null
          : {
              'attempted': trim.attempted,
              'killed': trim.killed,
              'packages': trim.packages,
              'note': trim.note,
            },
    };
  }
}
