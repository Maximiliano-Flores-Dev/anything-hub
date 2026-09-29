import 'package:flutter/foundation.dart';

class SystemLogger {
  static final List<String> _logs = [];

  static void log(String event) {
    final timestamp = DateTime.now().toIso8601String().split('T').last.substring(0, 8);
    final formattedLog = "[$timestamp] $event";
    _logs.insert(0, formattedLog); // Añadir al inicio para ver lo más reciente arriba
    if (kDebugMode) {
      print(formattedLog);
    }
  }

  static List<String> getLogs() {
    return _logs;
  }
}
