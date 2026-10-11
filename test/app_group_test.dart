import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anything_hub/core/models.dart';

void main() {
  group('AppGroup', () {
    test('custom group holds packages and color', () {
      final g = AppGroup(
        'Dev',
        [],
        isCustom: true,
        packages: ['com.a', 'com.b'],
        colorArgb: kGroupColorOptions.first,
      );
      expect(g.isCustom, isTrue);
      expect(g.packages, ['com.a', 'com.b']);
      expect(g.colorArgb, kGroupColorOptions.first);
      expect(g.color, isNotNull);
    });

    test('sortByUsage ordena por score y nombre', () {
      final a = HubApp('Zebra', background: const Color(0xFF000000), foreground: const Color(0xFFFFFFFF), usageScore: 1);
      final b = HubApp('Alpha', background: const Color(0xFF000000), foreground: const Color(0xFFFFFFFF), usageScore: 5);
      final c = HubApp('Beta', background: const Color(0xFF000000), foreground: const Color(0xFFFFFFFF), usageScore: 5);
      final g = AppGroup('G', [a, b, c]);
      g.sortByUsage();
      expect(g.apps.map((e) => e.name).toList(), ['Alpha', 'Beta', 'Zebra']);
    });

    test('label y colorArgb son mutables para edición', () {
      final g = AppGroup('Old', [], isCustom: true, colorArgb: 0xFFF05A3C);
      g.label = 'New';
      g.colorArgb = 0xFF5B8DEF;
      expect(g.label, 'New');
      expect(g.colorArgb, 0xFF5B8DEF);
    });

    test('kGroupColorOptions tiene 8 colores', () {
      expect(kGroupColorOptions.length, 8);
    });
  });
}
