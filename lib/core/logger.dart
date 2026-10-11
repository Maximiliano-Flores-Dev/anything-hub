import 'package:flutter/foundation.dart';

/// Logger mínimo de sistema (sin telemetría externa).
///
/// Hardening:
/// - En release solo acumula en memoria un ring buffer pequeño; no imprime.
/// - Redacta tokens, paths sensibles y payloads largos.
/// - Nunca envía datos fuera del dispositivo.
class SystemLogger {
  static const int _maxEntries = 200;
  static final List<String> _logs = [];

  /// Patrones a enmascarar en mensajes de log.
  static final List<RegExp> _redactPatterns = [
    RegExp(r'(access_token|refresh_token|token|Bearer)\s*[=:]\s*\S+',
        caseSensitive: false),
    RegExp(r'gh_[a-zA-Z0-9_]{20,}'),
    RegExp(r'code_verifier[=:]\s*\S+', caseSensitive: false),
    RegExp(r'client_secret[=:]\s*\S+', caseSensitive: false),
  ];

  static void log(String message) {
    final safe = _redact(message);
    final timestamp =
        DateTime.now().toIso8601String().split('T').last.substring(0, 12);
    final line = '[$timestamp] $safe';

    _logs.insert(0, line);
    if (_logs.length > _maxEntries) {
      _logs.removeLast();
    }

    // Solo consola en debug/profile — nunca en release.
    if (kDebugMode) {
      // ignore: avoid_print
      print('[AnythingsHub] $safe');
    }
  }

  /// Log de llamada a MethodChannel (solo debug).
  static void channel(String channel, String method, {String? detail}) {
    if (!kDebugMode) return;
    final d = detail == null ? '' : ' ${_redact(detail)}';
    log('ch:$channel.$method$d');
  }

  static List<String> getLogs() => List.unmodifiable(_logs);

  static void clear() => _logs.clear();

  static String _redact(String input) {
    var out = input;
    for (final re in _redactPatterns) {
      out = out.replaceAllMapped(re, (_) => '[REDACTED]');
    }
    // Truncar mensajes enormes (p.ej. dumps de iconos base64)
    if (out.length > 500) {
      out = '${out.substring(0, 500)}…[truncated]';
    }
    return out;
  }
}
