import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:anything_hub/core/hub_palette.dart';
import 'package:anything_hub/core/macro_customization.dart';
import 'package:anything_hub/core/hub_colors.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await MacroCustomization.instance.resetToDefaults();
  });

  group('HubPalettes', () {
    test('todas las paletas tienen id y nombre únicos', () {
      final ids = HubPalettes.all.map((p) => p.id).toSet();
      final names = HubPalettes.all.map((p) => p.name).toSet();
      expect(ids.length, HubPalettes.all.length);
      expect(names.length, HubPalettes.all.length);
      expect(HubPalettes.all.length, 6);
    });

    test('byId y byIdString resuelven classic por defecto', () {
      expect(HubPalettes.byId(HubPaletteId.classic).name, 'Clásico');
      expect(HubPalettes.byIdString(null).id, HubPaletteId.classic);
      expect(HubPalettes.byIdString('').id, HubPaletteId.classic);
      expect(HubPalettes.byIdString('ocean').id, HubPaletteId.ocean);
      expect(HubPalettes.byIdString('no-existe').id, HubPaletteId.classic);
    });

    test('previewSwatches y degradados no están vacíos', () {
      for (final p in HubPalettes.all) {
        expect(p.previewSwatches.length, greaterThanOrEqualTo(4));
        expect(p.degradado.colors.length, 2);
        expect(p.bordeCard.colors.length, 2);
      }
    });
  });

  group('DashboardCardIds', () {
    test('defaultOrder cubre todos los labels', () {
      for (final id in DashboardCardIds.defaultOrder) {
        expect(DashboardCardIds.labels.containsKey(id), isTrue);
      }
      expect(DashboardCardIds.defaultOrder.length, 6);
    });
  });

  group('MacroCustomization', () {
    test('valores por defecto', () {
      final m = MacroCustomization.instance;
      expect(m.paletteId, HubPaletteId.classic);
      expect(m.sidebarEnabled, isTrue);
      expect(m.leftHandedMode, isFalse);
      expect(m.activeCardIds, DashboardCardIds.defaultOrder);
    });

    test('setPalette cambia y HubColors refleja acento', () async {
      final m = MacroCustomization.instance;
      await m.setPalette(HubPaletteId.ocean);
      expect(m.paletteId, HubPaletteId.ocean);
      expect(m.palette.accent, HubPalettes.ocean.accent);
      expect(HubColors.pomelo, HubPalettes.ocean.accent);
      expect(HubColors.fondoPrincipal, HubPalettes.ocean.fondoPrincipal);
      await m.setPalette(HubPaletteId.classic);
      expect(HubColors.pomelo, HubPalettes.classic.accent);
    });

    test('sidebar y leftHanded toggles', () async {
      final m = MacroCustomization.instance;
      await m.setSidebarEnabled(false);
      expect(m.sidebarEnabled, isFalse);
      await m.setSidebarEnabled(true);
      expect(m.sidebarEnabled, isTrue);
      await m.setLeftHandedMode(true);
      expect(m.leftHandedMode, isTrue);
      await m.setLeftHandedMode(false);
      expect(m.leftHandedMode, isFalse);
    });

    test('toggleCard no deja el dashboard vacío', () async {
      final m = MacroCustomization.instance;
      for (final id in List.of(m.activeCardIds.skip(1))) {
        await m.toggleCard(id, enable: false);
      }
      expect(m.activeCardIds.length, 1);
      final last = m.activeCardIds.first;
      await m.toggleCard(last, enable: false);
      expect(m.activeCardIds, [last]);
    });

    test('reorderCard reordena ids activos', () async {
      final m = MacroCustomization.instance;
      final original = List.of(m.activeCardIds);
      await m.reorderCard(0, 2);
      expect(m.activeCardIds.length, original.length);
      expect(m.activeCardIds[0], original[1]);
      expect(m.activeCardIds[1], original[0]);
    });

    test('persistencia load/save', () async {
      final m = MacroCustomization.instance;
      await m.setPalette(HubPaletteId.violet);
      await m.setSidebarEnabled(false);
      await m.setLeftHandedMode(true);
      await m.setActiveCards([
        DashboardCardIds.apps,
        DashboardCardIds.files,
      ]);
      await m.load();
      expect(m.paletteId, HubPaletteId.violet);
      expect(m.sidebarEnabled, isFalse);
      expect(m.leftHandedMode, isTrue);
      expect(m.activeCardIds, [DashboardCardIds.apps, DashboardCardIds.files]);
    });

    test('resetToDefaults restaura todo', () async {
      final m = MacroCustomization.instance;
      await m.setPalette(HubPaletteId.mono);
      await m.setSidebarEnabled(false);
      await m.setLeftHandedMode(true);
      await m.setActiveCards([DashboardCardIds.webs]);
      await m.resetToDefaults();
      expect(m.paletteId, HubPaletteId.classic);
      expect(m.sidebarEnabled, isTrue);
      expect(m.leftHandedMode, isFalse);
      expect(m.activeCardIds, DashboardCardIds.defaultOrder);
    });

    test('setActiveCards filtra ids desconocidos y evita vacío', () async {
      final m = MacroCustomization.instance;
      await m.setActiveCards(['nope', DashboardCardIds.apps, 'x']);
      expect(m.activeCardIds, [DashboardCardIds.apps]);
      await m.setActiveCards([]);
      expect(m.activeCardIds, isNotEmpty);
    });
  });
}
