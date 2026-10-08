import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_models.dart';

/// Oráculo local de firmas (fail-closed).
///
/// Fuentes de confianza, en orden:
/// 1. Coincidencia con certificados de la misma app **ya instalada** en el dispositivo.
/// 2. Pin local (caché de pins que el usuario o un flujo previo guardó).
/// 3. Sin coincidencia → [SignatureStatus.unverified] o [SignatureStatus.error].
///
/// Nunca afirma "verified" sin evidencia local. No hay telemetría ni oráculo remoto aún.
class SignatureOracleService {
  static const _prefsKey = 'signature_pins_v1';
  static const _maxPins = 200;
  static const _pinTtlDays = 90;

  static Future<SignatureCheckResult> verify({
    required String packageName,
    required String versionLabel,
    required List<String> apkCertSha256,
    List<String> installedCertSha256 = const [],
    bool isPackageInstalled = false,
  }) async {
    final pkg = packageName.trim();
    final certs = apkCertSha256
        .map((c) => c.trim().toLowerCase())
        .where((c) => c.isNotEmpty)
        .toList();

    if (pkg.isEmpty) {
      return SignatureCheckResult(
        status: SignatureStatus.error,
        packageName: pkg,
        versionLabel: versionLabel,
        message: 'Nombre de paquete vacío. Verificación imposible.',
      );
    }

    if (certs.isEmpty) {
      return SignatureCheckResult(
        status: SignatureStatus.error,
        packageName: pkg,
        versionLabel: versionLabel,
        message:
            'Sin certificados de firma en el APK. Tratar como no confiable (fail-closed).',
      );
    }

    final primaryCert = certs.first;

    final installed = installedCertSha256
        .map((c) => c.trim().toLowerCase())
        .where((c) => c.isNotEmpty)
        .toList();
    if (isPackageInstalled && installed.isNotEmpty) {
      final match = certs.any(installed.contains);
      if (match) {
        return SignatureCheckResult(
          status: SignatureStatus.verified,
          packageName: pkg,
          versionLabel: versionLabel,
          certSha256: primaryCert,
          message:
              'Coincide con la firma de la app ya instalada en este dispositivo.',
        );
      }
      return SignatureCheckResult(
        status: SignatureStatus.unverified,
        packageName: pkg,
        versionLabel: versionLabel,
        certSha256: primaryCert,
        message:
            'El APK está firmado con un certificado distinto al de la app instalada. '
            'Posible reempaquetado o clave diferente.',
      );
    }

    final pin = await _findPin(pkg, certs);
    if (pin != null) {
      final age = DateTime.now().difference(pin.pinnedAt).inDays;
      return SignatureCheckResult(
        status: SignatureStatus.cacheHit,
        packageName: pkg,
        versionLabel: versionLabel,
        certSha256: primaryCert,
        cacheAgeDays: age,
        message: 'Coincide con pin local guardado hace $age día(s).',
      );
    }

    return SignatureCheckResult(
      status: SignatureStatus.unverified,
      packageName: pkg,
      versionLabel: versionLabel,
      certSha256: primaryCert,
      message: isPackageInstalled
          ? 'Paquete instalado pero sin firmas legibles. No se puede confirmar.'
          : 'Sin pin local ni app instalada con la que comparar. '
              'Autenticidad no confirmada (fail-closed).',
    );
  }

  static Future<void> pinPackage(String packageName, String certSha256) async {
    final pkg = packageName.trim();
    final cert = certSha256.trim().toLowerCase();
    if (pkg.isEmpty || cert.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final map = await _loadPins(prefs);
    map[pkg] = _PinEntry(certSha256: cert, pinnedAt: DateTime.now());
    if (map.length > _maxPins) {
      final sorted = map.entries.toList()
        ..sort((a, b) => a.value.pinnedAt.compareTo(b.value.pinnedAt));
      for (final e in sorted.take(map.length - _maxPins)) {
        map.remove(e.key);
      }
    }
    await _savePins(prefs, map);
  }

  static Future<void> unpinPackage(String packageName) async {
    final prefs = await SharedPreferences.getInstance();
    final map = await _loadPins(prefs);
    map.remove(packageName.trim());
    await _savePins(prefs, map);
  }

  static Future<_PinEntry?> _findPin(String pkg, List<String> certs) async {
    final prefs = await SharedPreferences.getInstance();
    final map = await _loadPins(prefs);
    final entry = map[pkg];
    if (entry == null) return null;
    final age = DateTime.now().difference(entry.pinnedAt).inDays;
    if (age > _pinTtlDays) {
      map.remove(pkg);
      await _savePins(prefs, map);
      return null;
    }
    if (!certs.contains(entry.certSha256.toLowerCase())) return null;
    return entry;
  }

  static Future<Map<String, _PinEntry>> _loadPins(SharedPreferences prefs) async {
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final out = <String, _PinEntry>{};
      decoded.forEach((k, v) {
        if (v is Map) {
          final cert = v['cert'] as String?;
          final at = v['at'] as String?;
          if (cert != null && at != null) {
            out[k] = _PinEntry(
              certSha256: cert,
              pinnedAt: DateTime.tryParse(at) ?? DateTime.fromMillisecondsSinceEpoch(0),
            );
          }
        }
      });
      return out;
    } catch (_) {
      return {};
    }
  }

  static Future<void> _savePins(
    SharedPreferences prefs,
    Map<String, _PinEntry> map,
  ) async {
    final encoded = <String, dynamic>{};
    map.forEach((k, v) {
      encoded[k] = {
        'cert': v.certSha256,
        'at': v.pinnedAt.toIso8601String(),
      };
    });
    await prefs.setString(_prefsKey, jsonEncode(encoded));
  }
}

class _PinEntry {
  const _PinEntry({required this.certSha256, required this.pinnedAt});
  final String certSha256;
  final DateTime pinnedAt;
}
