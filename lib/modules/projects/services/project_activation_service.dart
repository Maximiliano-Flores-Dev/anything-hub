import 'package:shared_preferences/shared_preferences.dart';

/// Gestiona el estado de activación del módulo de proyectos.
/// Nunca crea `.anythinghub/` hasta que el usuario acepte explícitamente.
class ProjectActivationService {
  static const _keyActivated = 'projects_module_activated';
  static const _keyFirstTime = 'projects_module_first_time';
  static const _keyDontShowAgain = 'projects_module_dont_show_again';
  static const _keyActivationAttempts = 'projects_module_attempts';

  static Future<bool> isActivated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyActivated) ?? false;
  }

  static Future<bool> isFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyFirstTime) ?? true;
  }

  static Future<bool> shouldShowAdvisement() async {
    final prefs = await SharedPreferences.getInstance();
    final dontShow = prefs.getBool(_keyDontShowAgain) ?? false;
    if (dontShow) return false;
    return !(prefs.getBool(_keyActivated) ?? false);
  }

  static Future<int> getAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyActivationAttempts) ?? 0;
  }

  static Future<void> incrementAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_keyActivationAttempts) ?? 0;
    await prefs.setInt(_keyActivationAttempts, current + 1);
  }

  static Future<void> setDontShowAgain(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDontShowAgain, value);
  }

  static Future<void> activate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyActivated, true);
    await prefs.setBool(_keyFirstTime, false);
  }

  static Future<void> deactivate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyActivated, false);
  }

  /// Permite reactivar el aviso tras "No volver a mostrar".
  static Future<void> clearAdvisementDismissal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDontShowAgain, false);
  }
}
