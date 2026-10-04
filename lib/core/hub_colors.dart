import 'package:flutter/material.dart';

const double radius12 = 12.0;

/// Paleta oficial de Anythings Hub.
abstract final class HubColors {
  static const Color fondoPrincipal = Color(0xFF040A16);
  static const Color fondoSidebar = Color(0xFF0A121F);
  static const Color panel = Color(0xFF070D19);
  static const Color linea = Color(0xFF2B3342);
  static const Color lineaFooter = Color(0xFF2A2E39);

  static const Color pomelo = Color(0xFFF05A3C);
  static const Color pomeloSuave = Color(0xFFE8909F);
  static const Color amarillo = Color(0xFFF2B531);

  static const Color textoPrincipal = Color(0xFFFFFFFF);
  static const Color textoSecundario = Color(0xFF959BAA);
  static const Color textoAcento = Color(0xFF7C80C6);

  static const List<Color> _degradado = [Color(0xFFF9663A), Color(0xFFEC373E)];

  static const LinearGradient degradado = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: _degradado,
  );
  static const LinearGradient degradadoDiagonal = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: _degradado,
  );
  static const LinearGradient bordeCard = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xEEF2663A), Color(0xC0E0384C)],
  );
}
