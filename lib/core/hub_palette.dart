import 'package:flutter/material.dart';

/// Identificador de una paleta predefinida.
enum HubPaletteId {
  classic, // pomelo oficial
  ocean,
  forest,
  violet,
  sunset,
  mono,
}

/// Paleta completa de colores de la app.
class HubPalette {
  const HubPalette({
    required this.id,
    required this.name,
    required this.fondoPrincipal,
    required this.fondoSidebar,
    required this.panel,
    required this.linea,
    required this.lineaFooter,
    required this.accent,
    required this.accentSoft,
    required this.secondary,
    required this.textoPrincipal,
    required this.textoSecundario,
    required this.textoAcento,
    required this.degradadoColors,
  });

  final HubPaletteId id;
  final String name;
  final Color fondoPrincipal;
  final Color fondoSidebar;
  final Color panel;
  final Color linea;
  final Color lineaFooter;
  final Color accent;
  final Color accentSoft;
  final Color secondary;
  final Color textoPrincipal;
  final Color textoSecundario;
  final Color textoAcento;
  final List<Color> degradadoColors;

  LinearGradient get degradado => LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: degradadoColors,
      );

  LinearGradient get degradadoDiagonal => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: degradadoColors,
      );

  LinearGradient get bordeCard => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          degradadoColors.first.withOpacity(0.93),
          degradadoColors.last.withOpacity(0.75),
        ],
      );

  List<Color> get previewSwatches => [
        fondoPrincipal,
        panel,
        accent,
        secondary,
        textoAcento,
      ];
}

abstract final class HubPalettes {
  static const HubPalette classic = HubPalette(
    id: HubPaletteId.classic,
    name: 'Clásico',
    fondoPrincipal: Color(0xFF040A16),
    fondoSidebar: Color(0xFF0A121F),
    panel: Color(0xFF070D19),
    linea: Color(0xFF2B3342),
    lineaFooter: Color(0xFF2A2E39),
    accent: Color(0xFFF05A3C),
    accentSoft: Color(0xFFE8909F),
    secondary: Color(0xFFF2B531),
    textoPrincipal: Color(0xFFFFFFFF),
    textoSecundario: Color(0xFF959BAA),
    textoAcento: Color(0xFF7C80C6),
    degradadoColors: [Color(0xFFF9663A), Color(0xFFEC373E)],
  );

  static const HubPalette ocean = HubPalette(
    id: HubPaletteId.ocean,
    name: 'Océano',
    fondoPrincipal: Color(0xFF03141F),
    fondoSidebar: Color(0xFF0A1C2A),
    panel: Color(0xFF071A28),
    linea: Color(0xFF1E3A4A),
    lineaFooter: Color(0xFF1A3340),
    accent: Color(0xFF2EC4B6),
    accentSoft: Color(0xFF7EDDD4),
    secondary: Color(0xFF4CC9F0),
    textoPrincipal: Color(0xFFFFFFFF),
    textoSecundario: Color(0xFF8BA8B8),
    textoAcento: Color(0xFF5E9FBF),
    degradadoColors: [Color(0xFF2EC4B6), Color(0xFF3A86FF)],
  );

  static const HubPalette forest = HubPalette(
    id: HubPaletteId.forest,
    name: 'Bosque',
    fondoPrincipal: Color(0xFF06140C),
    fondoSidebar: Color(0xFF0C1E14),
    panel: Color(0xFF0A1A12),
    linea: Color(0xFF234030),
    lineaFooter: Color(0xFF1E382A),
    accent: Color(0xFF52B788),
    accentSoft: Color(0xFF95D5B2),
    secondary: Color(0xFFB7E4C7),
    textoPrincipal: Color(0xFFFFFFFF),
    textoSecundario: Color(0xFF8FA89A),
    textoAcento: Color(0xFF74C69D),
    degradadoColors: [Color(0xFF52B788), Color(0xFF2D6A4F)],
  );

  static const HubPalette violet = HubPalette(
    id: HubPaletteId.violet,
    name: 'Violeta',
    fondoPrincipal: Color(0xFF0C0618),
    fondoSidebar: Color(0xFF140C24),
    panel: Color(0xFF100A1E),
    linea: Color(0xFF2E2248),
    lineaFooter: Color(0xFF2A1E40),
    accent: Color(0xFF9B5DE5),
    accentSoft: Color(0xFFC77DFF),
    secondary: Color(0xFFF15BB5),
    textoPrincipal: Color(0xFFFFFFFF),
    textoSecundario: Color(0xFFA89BBF),
    textoAcento: Color(0xFFB388EB),
    degradadoColors: [Color(0xFF9B5DE5), Color(0xFFF15BB5)],
  );

  static const HubPalette sunset = HubPalette(
    id: HubPaletteId.sunset,
    name: 'Atardecer',
    fondoPrincipal: Color(0xFF140A08),
    fondoSidebar: Color(0xFF1E100C),
    panel: Color(0xFF1A0E0A),
    linea: Color(0xFF3A2820),
    lineaFooter: Color(0xFF34241C),
    accent: Color(0xFFFF6B35),
    accentSoft: Color(0xFFFF9E6D),
    secondary: Color(0xFFFFBE0B),
    textoPrincipal: Color(0xFFFFFFFF),
    textoSecundario: Color(0xFFB8A090),
    textoAcento: Color(0xFFE07A5F),
    degradadoColors: [Color(0xFFFF6B35), Color(0xFFF72585)],
  );

  static const HubPalette mono = HubPalette(
    id: HubPaletteId.mono,
    name: 'Mono',
    fondoPrincipal: Color(0xFF0A0A0A),
    fondoSidebar: Color(0xFF121212),
    panel: Color(0xFF101010),
    linea: Color(0xFF2A2A2A),
    lineaFooter: Color(0xFF252525),
    accent: Color(0xFFE0E0E0),
    accentSoft: Color(0xFFB0B0B0),
    secondary: Color(0xFF909090),
    textoPrincipal: Color(0xFFFFFFFF),
    textoSecundario: Color(0xFF888888),
    textoAcento: Color(0xFFAAAAAA),
    degradadoColors: [Color(0xFFE0E0E0), Color(0xFF606060)],
  );

  static const List<HubPalette> all = [
    classic,
    ocean,
    forest,
    violet,
    sunset,
    mono,
  ];

  static HubPalette byId(HubPaletteId id) {
    return all.firstWhere((p) => p.id == id, orElse: () => classic);
  }

  static HubPalette byIdString(String? raw) {
    if (raw == null || raw.isEmpty) return classic;
    final id = HubPaletteId.values.where((e) => e.name == raw).firstOrNull;
    return id != null ? byId(id) : classic;
  }
}
