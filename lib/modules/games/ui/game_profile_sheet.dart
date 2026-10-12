import 'package:flutter/material.dart';

import '../../../core/hub_colors.dart';
import '../../../core/models.dart';
import '../models/game_profile.dart';

Future<GameProfile?> showGameProfileSheet(
  BuildContext context, {
  required GameProfile profile,
  required DeviceAppInfo game,
}) {
  return showModalBottomSheet<GameProfile>(
    context: context,
    isScrollControlled: true,
    backgroundColor: HubColors.panel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _Body(profile: profile, game: game),
  );
}

class _Body extends StatefulWidget {
  const _Body({required this.profile, required this.game});
  final GameProfile profile;
  final DeviceAppInfo game;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  late bool booster;
  late bool focus;
  late bool hud;
  late bool timeout;
  late bool highRefresh;
  late bool blockNotif;
  late int targetFps;

  static const _fpsOptions = [0, 30, 60, 90, 120];

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    booster = p.boosterOnLaunch;
    focus = p.focusOnLaunch;
    hud = p.showHud;
    timeout = p.extendScreenTimeout;
    highRefresh = p.preferHighRefresh;
    blockNotif = p.blockNotifications;
    targetFps = p.targetFps;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: HubColors.linea,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(widget.game.name,
                style: TextStyle(
                    color: HubColors.textoPrincipal,
                    fontWeight: FontWeight.w700,
                    fontSize: 17)),
            Text(widget.game.packageName,
                style: TextStyle(
                    color: HubColors.textoSecundario, fontSize: 11)),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Booster al abrir',
                  style: TextStyle(color: HubColors.textoPrincipal)),
              value: booster,
              activeColor: HubColors.pomelo,
              onChanged: (v) => setState(() => booster = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Focus / silenciar terceros',
                  style: TextStyle(color: HubColors.textoPrincipal)),
              value: focus,
              activeColor: HubColors.pomelo,
              onChanged: (v) => setState(() => focus = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Bloquear molestias',
                  style: TextStyle(color: HubColors.textoPrincipal)),
              value: blockNotif,
              activeColor: HubColors.pomelo,
              onChanged: (v) => setState(() => blockNotif = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('HUD FPS / RAM',
                  style: TextStyle(color: HubColors.textoPrincipal)),
              value: hud,
              activeColor: HubColors.pomelo,
              onChanged: (v) => setState(() => hud = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Pantalla siempre (10 min)',
                  style: TextStyle(color: HubColors.textoPrincipal)),
              value: timeout,
              activeColor: HubColors.pomelo,
              onChanged: (v) => setState(() => timeout = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Preferir alto refresh',
                  style: TextStyle(color: HubColors.textoPrincipal)),
              value: highRefresh,
              activeColor: HubColors.pomelo,
              onChanged: (v) => setState(() => highRefresh = v),
            ),
            const SizedBox(height: 8),
            Text('FPS objetivo (preferencia HUD)',
                style: TextStyle(
                    color: HubColors.textoSecundario, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final f in _fpsOptions)
                  ChoiceChip(
                    label: Text(f == 0 ? 'Auto' : '$f'),
                    selected: targetFps == f,
                    onSelected: (_) => setState(() => targetFps = f),
                    selectedColor: HubColors.pomelo.withOpacity(0.3),
                    labelStyle: TextStyle(color: HubColors.textoPrincipal),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: HubColors.pomelo,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                Navigator.pop(
                  context,
                  widget.profile.copyWith(
                    displayName: widget.game.name,
                    boosterOnLaunch: booster,
                    focusOnLaunch: focus,
                    showHud: hud,
                    extendScreenTimeout: timeout,
                    preferHighRefresh: highRefresh,
                    blockNotifications: blockNotif,
                    targetFps: targetFps,
                  ),
                );
              },
              child: const Text('Guardar perfil',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
