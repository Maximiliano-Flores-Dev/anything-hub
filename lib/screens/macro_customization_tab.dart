import 'package:flutter/material.dart';

import '../core/hub_colors.dart';
import '../core/hub_palette.dart';
import '../core/macro_customization.dart';

/// Pestaña de Personalización (Macro Customization).
class MacroCustomizationTab extends StatelessWidget {
  const MacroCustomizationTab({super.key});

  @override
  Widget build(BuildContext context) {
    final macro = MacroCustomization.instance;
    return AnimatedBuilder(
      animation: macro,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            _sectionTitle('Paleta de colores'),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cambia toda la interfaz con un toque.',
                    style: TextStyle(color: HubColors.textoSecundario, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final p in HubPalettes.all)
                        _PaletteChip(
                          palette: p,
                          selected: macro.paletteId == p.id,
                          onTap: () => macro.setPalette(p.id),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _sectionTitle('Layout'),
            _card(
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Sidebar de apps',
                      style: TextStyle(color: HubColors.textoPrincipal, fontSize: 14),
                    ),
                    subtitle: Text(
                      'Muestra u oculta la barra lateral de apps',
                      style: TextStyle(color: HubColors.textoSecundario, fontSize: 12),
                    ),
                    value: macro.sidebarEnabled,
                    activeColor: HubColors.pomelo,
                    onChanged: (v) => macro.setSidebarEnabled(v),
                  ),
                  Divider(color: HubColors.linea, height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Modo para zurdos',
                      style: TextStyle(color: HubColors.textoPrincipal, fontSize: 14),
                    ),
                    subtitle: Text(
                      'Espejo funcional: sidebar a la derecha',
                      style: TextStyle(color: HubColors.textoSecundario, fontSize: 12),
                    ),
                    value: macro.leftHandedMode,
                    activeColor: HubColors.pomelo,
                    onChanged: (v) => macro.setLeftHandedMode(v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _sectionTitle('Módulos del dashboard'),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Activa o desactiva las cards del inicio.',
                    style: TextStyle(color: HubColors.textoSecundario, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  for (final id in DashboardCardIds.defaultOrder) ...[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        DashboardCardIds.labels[id] ?? id,
                        style: TextStyle(
                          color: HubColors.textoPrincipal,
                          fontSize: 14,
                        ),
                      ),
                      value: macro.isCardActive(id),
                      activeColor: HubColors.pomelo,
                      onChanged: (v) => macro.toggleCard(id, enable: v),
                    ),
                  ],
                  Divider(color: HubColors.linea, height: 16),
                  Text(
                    'Orden (arrastra para reordenar)',
                    style: TextStyle(color: HubColors.textoSecundario, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    onReorder: (oldIndex, newIndex) {
                      macro.reorderCard(oldIndex, newIndex);
                    },
                    children: [
                      for (final id in macro.activeCardIds)
                        ListTile(
                          key: ValueKey(id),
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.drag_handle_rounded,
                            color: HubColors.textoSecundario,
                          ),
                          title: Text(
                            DashboardCardIds.labels[id] ?? id,
                            style: TextStyle(
                              color: HubColors.textoPrincipal,
                              fontSize: 14,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: TextButton.icon(
                onPressed: () async {
                  await macro.resetToDefaults();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: HubColors.panel,
                        content: Text(
                          'Personalización restaurada',
                          style: TextStyle(color: HubColors.textoPrincipal),
                        ),
                      ),
                    );
                  }
                },
                icon: Icon(Icons.restore_rounded, size: 18, color: HubColors.textoAcento),
                label: Text(
                  'Restaurar valores por defecto',
                  style: TextStyle(color: HubColors.textoAcento),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          t,
          style: TextStyle(
            color: HubColors.textoPrincipal,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      );

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: HubColors.panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: HubColors.linea),
        ),
        child: child,
      );
}

class _PaletteChip extends StatelessWidget {
  const _PaletteChip({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final HubPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 92,
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
        decoration: BoxDecoration(
          color: selected ? HubColors.panel : HubColors.fondoPrincipal,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? HubColors.pomelo : HubColors.linea,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final c in palette.previewSwatches.take(4))
                  Container(
                    width: 14,
                    height: 14,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: c,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: HubColors.linea.withOpacity(0.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              palette.name,
              style: TextStyle(
                color: selected ? HubColors.pomelo : HubColors.textoSecundario,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
