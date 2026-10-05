import '../models/app_models.dart';

/// Matriz de ponderación del Hito 3.
/// Entrada: permisos declarados + SDKs detectados (parser nativo o Dart).
class ApkRiskScorer {
  static const _criticalPermissions = {
    'android.permission.BIND_ACCESSIBILITY_SERVICE',
    'android.permission.ACCESSIBILITY_SERVICE',
    'android.permission.READ_SMS',
    'android.permission.RECEIVE_SMS',
    'android.permission.SEND_SMS',
    'android.permission.READ_CALL_LOG',
    'android.permission.WRITE_CALL_LOG',
    'android.permission.PROCESS_OUTGOING_CALLS',
    'android.permission.RECORD_AUDIO',
    'android.permission.CAMERA',
    'android.permission.READ_CONTACTS',
    'android.permission.WRITE_CONTACTS',
    'android.permission.ACCESS_FINE_LOCATION',
    'android.permission.ACCESS_BACKGROUND_LOCATION',
    'android.permission.REQUEST_INSTALL_PACKAGES',
    'android.permission.SYSTEM_ALERT_WINDOW',
  };

  static const _networkPermissions = {
    'android.permission.INTERNET',
    'android.permission.ACCESS_NETWORK_STATE',
  };

  static const _knownTrackers = {
    'com.google.firebase.analytics',
    'com.facebook.appevents',
    'com.appsflyer',
    'com.adjust.sdk',
    'com.mixpanel',
    'com.amplitude',
    'io.branch',
  };

  /// Calcula score 0–100 a partir de listas ya parseadas del APK.
  static ApkRiskReport score({
    required String fileName,
    required String packageName,
    required List<String> rawPermissions,
    required List<String> detectedPackages,
    String? sha256,
  }) {
    var score = 0;
    final permissions = <ApkPermission>[];

    for (final p in rawPermissions) {
      final critical = _criticalPermissions.contains(p);
      final network = _networkPermissions.contains(p);
      if (critical) score += 18;
      if (network) score += 4;
      permissions.add(
        ApkPermission(
          name: _shortPermissionName(p),
          description: _permissionDescription(p),
          critical: critical,
        ),
      );
    }

    final trackers = detectedPackages
        .where((pkg) => _knownTrackers.any(pkg.contains))
        .toList();
    score += trackers.length * 8;

    score = score.clamp(0, 100);
    return ApkRiskReport(
      score: score,
      level: ApkRiskReport.levelFromScore(score),
      permissions: permissions,
      trackingSdks: trackers,
      fileName: fileName,
      packageName: packageName,
      sha256: sha256,
    );
  }

  static String _shortPermissionName(String full) {
    final i = full.lastIndexOf('.');
    return i >= 0 ? full.substring(i + 1) : full;
  }

  static String _permissionDescription(String full) {
    if (full.contains('ACCESSIBILITY')) {
      return 'Puede controlar su interfaz y observar su contenido.';
    }
    if (full.contains('SMS')) {
      return 'Puede leer y enviar mensajes SMS.';
    }
    if (full.contains('INTERNET')) {
      return 'Puede establecer conexiones y enviar datos.';
    }
    if (full.contains('LOCATION')) {
      return 'Puede acceder a la ubicación del dispositivo.';
    }
    if (full.contains('CAMERA') || full.contains('RECORD_AUDIO')) {
      return 'Puede usar cámara o micrófono.';
    }
    return 'Permiso declarado en el manifiesto.';
  }
}
