import 'package:flutter/material.dart';

import '../../../core/hub_colors.dart';
import '../../../core/models.dart';
import '../../../services/performance_service.dart';
import '../services/game_mode_service.dart';
import '../services/game_native.dart';
import 'game_mode_widgets.dart';
import 'game_profile_sheet.dart';

class GameModeScreen extends StatefulWidget {
  const GameModeScreen({super.key});

  @override
  State<GameModeScreen> createState() => _GameModeScreenState();
}

class _GameModeScreenState extends State<GameModeScreen> {
  final _svc = GameModeService.instance;
  List<DeviceAppInfo> _games = [];
  bool _loading = true;
  bool _overlayOk = false;
  Map<String, dynamic> _display = {};
  Map<String, dynamic> _battery = {};
  Map<String, dynamic> _hud = {};

  @override
  void initState() {
    super.initState();
    _svc.addListener(_onSvc);
    _bootstrap();
  }

  @override
  void dispose() {
    _svc.removeListener(_onSvc);
    super.dispose();
  }

  void _onSvc() {
    if (mounted) setState(() {});
  }

  Future<void> _bootstrap() async {
    await _svc.load();
    await _svc.startWatching();
    await _reload();
  }

  Future<void> _reload() async {
    final games = await _svc.listGames();
    final overlay = await GameNative.canDrawOverlays();
    final display = await GameNative.displayMetrics();
    final battery = await GameNative.batteryStats();
    final hud = await GameNative.hudSnapshot();
    if (!mounted) return;
    setState(() {
      _games = games;
      _overlayOk = overlay;
      _display = display;
      _battery = battery;
      _hud = hud;
      _loading = false;
    });
  }

  Future<void> _openProfile(DeviceAppInfo g) async {
    final p = _svc.profileFor(g.packageName, name: g.name);
    final updated = await showGameProfileSheet(context, profile: p, game: g);
    if (updated != null) await _svc.saveProfile(updated);
  }

  @override
  Widget build(BuildContext context) {
    final refresh = (_display['refreshRate'] as num?)?.toDouble() ?? 60.0;
    final fps = (_hud['fps'] as num?)?.toDouble() ?? 0.0;
    final bat = (_battery['level'] as num?)?.toInt() ?? -1;

    return Scaffold(
      backgroundColor: HubColors.fondoPrincipal,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: HubColors.textoPrincipal),
        title: Text('Modo Juegos',
            style: TextStyle(
                color: HubColors.textoPrincipal, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: Icon(Icons.refresh, color: HubColors.pomelo),
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: HubColors.pomelo))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                GamePanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Estado en vivo',
                          style: TextStyle(
                              color: HubColors.textoPrincipal,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      GameMetricChips(
                        refreshHz: refresh,
                        fps: fps,
                        battery: bat,
                        inGame: _svc.activeGame != null,
                      ),
                      if (_svc.session != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Sesión: ${_svc.session!.duration.inMinutes} min',
                          style: TextStyle(
                              color: HubColors.textoSecundario, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                GamePanel(
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Auto-detectar juegos',
                            style: TextStyle(color: HubColors.textoPrincipal)),
                        subtitle: Text(
                          'Categoría game → booster + HUD',
                          style: TextStyle(
                              color: HubColors.textoSecundario, fontSize: 12),
                        ),
                        value: _svc.autoDetect,
                        activeColor: HubColors.pomelo,
                        onChanged: (v) => _svc.setGlobal(autoDetect: v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('HUD flotante',
                            style: TextStyle(color: HubColors.textoPrincipal)),
                        value: _svc.globalHud,
                        activeColor: HubColors.pomelo,
                        onChanged: (v) => _svc.setGlobal(globalHud: v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Booster al lanzar',
                            style: TextStyle(color: HubColors.textoPrincipal)),
                        value: _svc.globalBooster,
                        activeColor: HubColors.pomelo,
                        onChanged: (v) => _svc.setGlobal(globalBooster: v),
                      ),
                      if (!_overlayOk)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.layers_outlined,
                              color: HubColors.pomelo),
                          title: Text('Permiso superposición',
                              style:
                                  TextStyle(color: HubColors.textoPrincipal)),
                          trailing: TextButton(
                            onPressed: () async {
                              await GameNative.requestOverlayPermission();
                              await _reload();
                            },
                            child: Text('Conceder',
                                style: TextStyle(color: HubColors.pomelo)),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                      child: GameActionButton(
                          label: 'Boost ahora',
                          icon: Icons.rocket_launch_outlined,
                          onTap: () => _svc.boostNow())),
                  const SizedBox(width: 10),
                  Expanded(
                      child: GameActionButton(
                          label: 'Limpiar fondo',
                          icon: Icons.cleaning_services_outlined,
                          onTap: () => _svc.optimizeNonGames())),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                      child: GameActionButton(
                          label: 'Modo Focus',
                          icon: Icons.do_not_disturb_on_outlined,
                          onTap: () =>
                              PerformanceService.applyMode(PerfMode.focus))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: GameActionButton(
                          label: 'Parar HUD',
                          icon: Icons.stop_circle_outlined,
                          onTap: () async {
                            await _svc.exitGame();
                            await GameNative.stopHud();
                            await _reload();
                          })),
                ]),
                const SizedBox(height: 20),
                Text('Biblioteca (${_games.length})',
                    style: TextStyle(
                        color: HubColors.textoPrincipal,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
                const SizedBox(height: 6),
                Text('Solo apps con categoría juego del sistema.',
                    style: TextStyle(
                        color: HubColors.textoSecundario, fontSize: 12)),
                const SizedBox(height: 10),
                if (_games.isEmpty)
                  GamePanel(
                    child: Text(
                      'Sin juegos detectados. Concede uso y abre un juego.',
                      style: TextStyle(
                          color: HubColors.textoSecundario, fontSize: 13),
                    ),
                  )
                else
                  ..._games.map((g) => GameLibraryTile(
                        game: g,
                        active: _svc.activeGame == g.packageName,
                        onProfile: () => _openProfile(g),
                        onEnter: () async {
                          await _svc.enterGame(g);
                          await _reload();
                        },
                      )),
              ],
            ),
    );
  }
}
