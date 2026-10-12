import 'package:flutter/material.dart';
import '../../../core/hub_colors.dart';
import 'game_mode_screen.dart';

/// Botón reutilizable para abrir el centro gamer desde cualquier pantalla.
class GameModeEntryButton extends StatelessWidget {
  const GameModeEntryButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      backgroundColor: HubColors.pomelo,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.sports_esports),
      label: const Text('Modo Juegos'),
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const GameModeScreen()),
        );
      },
    );
  }

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GameModeScreen()),
    );
  }
}
