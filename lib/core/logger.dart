/// Logger mínimo de sistema (sin telemetría externa).
class SystemLogger {
  static void log(String message) {
    // ignore: avoid_print
    print('[AnythingsHub] $message');
  }
}
