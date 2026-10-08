import 'package:flutter_test/flutter_test.dart';
import 'package:anything_hub/services/device_files_service.dart';

void main() {
  group('FileOpGuard', () {
    test('rechaza lotes vacíos', () {
      expect(FileOpGuard.checkBatch(0), isNotNull);
    });

    test('acepta lotes pequeños', () {
      expect(FileOpGuard.checkBatch(1), isNull);
      expect(FileOpGuard.checkBatch(50), isNull);
    });

    test('rechaza más de maxBatchItems', () {
      final msg = FileOpGuard.checkBatch(FileOpGuard.maxBatchItems + 1);
      expect(msg, isNotNull);
      expect(msg, contains('${FileOpGuard.maxBatchItems}'));
    });

    test('acepta exactamente maxBatchItems', () {
      expect(FileOpGuard.checkBatch(FileOpGuard.maxBatchItems), isNull);
    });
  });
}
