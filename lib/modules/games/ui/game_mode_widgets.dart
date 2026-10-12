import 'package:flutter/material.dart';

import '../../../core/hub_colors.dart';
import '../../../core/models.dart';

class GameMetricChips extends StatelessWidget {
  const GameMetricChips({
    super.key,
    required this.refreshHz,
    required this.fps,
    required this.battery,
    required this.inGame,
  });
  final double refreshHz;
  final double fps;
  final int battery;
  final bool inGame;

  @override
  Widget build(BuildContext context) {
    Widget chip(String t) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: HubColors.fondoPrincipal,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: HubColors.linea),
          ),
          child: Text(t,
              style: TextStyle(color: HubColors.textoPrincipal, fontSize: 12)),
        );
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        chip('Panel ${refreshHz.toStringAsFixed(0)} Hz'),
        chip(fps > 0 ? 'HUD ${fps.toStringAsFixed(0)} FPS' : 'HUD —'),
        chip(battery >= 0 ? 'Batería $battery%' : 'Batería —'),
        chip(inGame ? 'En juego' : 'Sin juego'),
      ],
    );
  }
}

class GameActionButton extends StatelessWidget {
  const GameActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HubColors.panel,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: HubColors.linea),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: HubColors.pomelo),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label,
                    style: TextStyle(
                        color: HubColors.textoPrincipal,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GameLibraryTile extends StatelessWidget {
  const GameLibraryTile({
    super.key,
    required this.game,
    required this.active,
    required this.onProfile,
    required this.onEnter,
  });
  final DeviceAppInfo game;
  final bool active;
  final VoidCallback onProfile;
  final VoidCallback onEnter;

  @override
  Widget build(BuildContext context) {
    final g = game;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HubColors.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HubColors.linea),
      ),
      child: Row(
        children: [
          if (g.icon != null && g.icon!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(g.icon!, width: 40, height: 40),
            )
          else
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: HubColors.pomelo.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(g.name.isNotEmpty ? g.name[0] : '?',
                  style: TextStyle(
                      color: HubColors.pomelo, fontWeight: FontWeight.w800)),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(g.name,
                    style: TextStyle(
                        color: HubColors.textoPrincipal,
                        fontWeight: FontWeight.w600)),
                Text(
                  active
                      ? 'Sesión activa'
                      : '${g.usageMinutes} min · ${g.packageName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: active
                          ? const Color(0xFF3DDC84)
                          : HubColors.textoSecundario,
                      fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onProfile,
            icon: Icon(Icons.tune, color: HubColors.textoAcento, size: 20),
          ),
          IconButton(
            onPressed: onEnter,
            icon: Icon(Icons.sports_esports, color: HubColors.pomelo, size: 22),
          ),
        ],
      ),
    );
  }
}

class GamePanel extends StatelessWidget {
  const GamePanel({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
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
}
