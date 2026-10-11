import 'package:flutter/material.dart';

import 'hub_palette.dart';
import 'macro_customization.dart';

const double radius12 = 12.0;

/// Colores activos de Anythings Hub.
///
/// Los valores se leen de la paleta seleccionada en [MacroCustomization].
/// Se mantienen como getters estáticos para no romper el código existente
/// que usa `HubColors.pomelo`, `HubColors.fondoPrincipal`, etc.
abstract final class HubColors {
  static HubPalette get _p => MacroCustomization.instance.palette;

  static Color get fondoPrincipal => _p.fondoPrincipal;
  static Color get fondoSidebar => _p.fondoSidebar;
  static Color get panel => _p.panel;
  static Color get linea => _p.linea;
  static Color get lineaFooter => _p.lineaFooter;

  /// Acento principal (antes fijo como "pomelo").
  static Color get pomelo => _p.accent;
  static Color get pomeloSuave => _p.accentSoft;
  static Color get amarillo => _p.secondary;

  static Color get textoPrincipal => _p.textoPrincipal;
  static Color get textoSecundario => _p.textoSecundario;
  static Color get textoAcento => _p.textoAcento;

  static LinearGradient get degradado => _p.degradado;
  static LinearGradient get degradadoDiagonal => _p.degradadoDiagonal;
  static LinearGradient get bordeCard => _p.bordeCard;
}
