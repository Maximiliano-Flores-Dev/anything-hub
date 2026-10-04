import 'project_activation_service.dart';
import 'project_fs_service.dart';

/// Verificaciones de aislamiento (Hito 4).
/// Módulo desactivado = cero rastro de `.anythinghub/` y cero trabajo en background.
class IsolationService {
  /// True si el módulo está desactivado y no existe ninguna huella en disco.
  static Future<bool> isFullyIsolated() async {
    final activated = await ProjectActivationService.isActivated();
    if (activated) return false;
    final hasTrace = await ProjectFsService.hasAnyTrace();
    return !hasTrace;
  }

  /// Garantiza aislamiento: si no está activado y hay rastro, lo borra.
  static Future<void> enforceIsolationIfInactive() async {
    final activated = await ProjectActivationService.isActivated();
    if (activated) return;
    if (await ProjectFsService.hasAnyTrace()) {
      await ProjectFsService.uninstallModule();
    }
  }

  /// Informe legible para UI / logs.
  static Future<Map<String, dynamic>> statusReport() async {
    final activated = await ProjectActivationService.isActivated();
    final hasTrace = await ProjectFsService.hasAnyTrace();
    final attempts = await ProjectActivationService.getAttempts();
    return {
      'activated': activated,
      'has_disk_trace': hasTrace,
      'fully_isolated': !activated && !hasTrace,
      'activation_attempts': attempts,
    };
  }
}
