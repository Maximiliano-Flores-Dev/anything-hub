import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:anything_hub/modules/apps/models/app_models.dart';
import 'package:anything_hub/modules/apps/services/signature_oracle_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('SignatureOracleService.verify', () {
    test('fail-closed sin certificados', () async {
      final r = await SignatureOracleService.verify(
        packageName: 'com.example.app',
        versionLabel: '1.0',
        apkCertSha256: const [],
      );
      expect(r.status, SignatureStatus.error);
      expect(r.message, contains('Sin certificados'));
    });

    test('fail-closed sin package name', () async {
      final r = await SignatureOracleService.verify(
        packageName: '  ',
        versionLabel: '1.0',
        apkCertSha256: const ['aabb'],
      );
      expect(r.status, SignatureStatus.error);
    });

    test('verified cuando coincide con instalada', () async {
      final r = await SignatureOracleService.verify(
        packageName: 'com.foo.bar',
        versionLabel: '2.0',
        apkCertSha256: const ['abc123def'],
        installedCertSha256: const ['abc123def'],
        isPackageInstalled: true,
      );
      expect(r.status, SignatureStatus.verified);
      expect(r.certSha256, 'abc123def');
    });

    test('unverified si instalada con otra firma', () async {
      final r = await SignatureOracleService.verify(
        packageName: 'com.foo.bar',
        versionLabel: '2.0',
        apkCertSha256: const ['aaa'],
        installedCertSha256: const ['bbb'],
        isPackageInstalled: true,
      );
      expect(r.status, SignatureStatus.unverified);
      expect(r.message, contains('distinto'));
    });

    test('unverified sin instalada ni pin', () async {
      final r = await SignatureOracleService.verify(
        packageName: 'com.nuevo.app',
        versionLabel: '1.0',
        apkCertSha256: const ['deadbeef'],
      );
      expect(r.status, SignatureStatus.unverified);
      expect(r.message, contains('fail-closed'));
    });

    test('cacheHit tras pin local', () async {
      await SignatureOracleService.pinPackage('com.pinned.app', 'cafebabe');
      final r = await SignatureOracleService.verify(
        packageName: 'com.pinned.app',
        versionLabel: '1.0',
        apkCertSha256: const ['cafebabe'],
      );
      expect(r.status, SignatureStatus.cacheHit);
      expect(r.cacheAgeDays, isNotNull);
    });

    test('pin con cert distinto no hace match', () async {
      await SignatureOracleService.pinPackage('com.pinned.app', 'cafebabe');
      final r = await SignatureOracleService.verify(
        packageName: 'com.pinned.app',
        versionLabel: '1.0',
        apkCertSha256: const ['otro'],
      );
      expect(r.status, SignatureStatus.unverified);
    });
  });
}
