import 'package:flutter_test/flutter_test.dart';

/// Espejo de reglas de PathSecurity.kt (validación de cacheRelativePath y nombres).
/// Si cambias PathSecurity.kt, actualiza estas reglas.
bool isSafeCacheRelative(String relative) {
  final rel = relative.trim();
  if (rel.isEmpty) return false;
  if (rel.contains('\u0000')) return false;
  final normalized = rel.replaceAll('\\', '/');
  if (normalized.startsWith('/') ||
      normalized.startsWith('../') ||
      normalized.contains('/../') ||
      normalized.endsWith('/..') ||
      normalized == '..' ||
      normalized.contains('..')) {
    return false;
  }
  const allowed = ['incoming_apk/', 'puerto_limbo/'];
  if (!allowed.any(normalized.startsWith)) return false;
  final parts = normalized.split('/');
  if (parts.length != 2 || parts[1].isEmpty || parts[1].contains('/')) {
    return false;
  }
  if (!parts[1].toLowerCase().endsWith('.apk')) return false;
  return true;
}

bool isSafeFileName(String name) {
  final n = name.trim();
  if (n.isEmpty) return false;
  if (n.contains('\u0000')) return false;
  if (n.contains('/') || n.contains('\\')) return false;
  if (n == '.' || n == '..' || n.contains('..')) return false;
  if (n.runes.any((r) => r < 32)) return false;
  return true;
}

void main() {
  group('cacheRelativePath rules', () {
    test('acepta prefijos allowlist', () {
      expect(isSafeCacheRelative('incoming_apk/123.apk'), isTrue);
      expect(isSafeCacheRelative('puerto_limbo/456.apk'), isTrue);
    });

    test('rechaza traversal', () {
      expect(isSafeCacheRelative('../incoming_apk/x.apk'), isFalse);
      expect(isSafeCacheRelative('incoming_apk/../etc/passwd'), isFalse);
      expect(isSafeCacheRelative('incoming_apk/../../x.apk'), isFalse);
      expect(isSafeCacheRelative('..'), isFalse);
    });

    test('rechaza prefijos no allowlist', () {
      expect(isSafeCacheRelative('other/x.apk'), isFalse);
      expect(isSafeCacheRelative('x.apk'), isFalse);
    });

    test('solo .apk', () {
      expect(isSafeCacheRelative('incoming_apk/x.txt'), isFalse);
      expect(isSafeCacheRelative('incoming_apk/x.APK'), isTrue);
    });

    test('rechaza vacío y null byte', () {
      expect(isSafeCacheRelative(''), isFalse);
      expect(isSafeCacheRelative('incoming_apk/x\u0000.apk'), isFalse);
    });
  });

  group('file name rules', () {
    test('acepta nombres simples', () {
      expect(isSafeFileName('foto.jpg'), isTrue);
      expect(isSafeFileName('Mi Carpeta'), isTrue);
    });

    test('rechaza separadores y traversal', () {
      expect(isSafeFileName('../etc'), isFalse);
      expect(isSafeFileName('a/b'), isFalse);
      expect(isSafeFileName(r'a\\b'), isFalse);
      expect(isSafeFileName('..'), isFalse);
    });
  });
}
