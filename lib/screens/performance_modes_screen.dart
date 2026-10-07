import 'package:flutter/material.dart';

import '../core/hub_colors.dart';
import '../modules/plugins/plugin_service.dart';
import '../services/performance_service.dart';
import '../ui/widgets/gradient_pill_button.dart';

class PerformanceModesScreen extends StatefulWidget {
  const PerformanceModesScreen({super.key});

  @override
  State<PerformanceModesScreen> createState() => _PerformanceModesScreenState();
}

class _PerformanceModesScreenState extends State<PerformanceModesScreen> {
  PerfMode _mode = PerfMode.balanced;
  MemorySnapshot? _mem;
  bool _loading = true;
  bool _applying = false;
  bool _policyAccess = false;
  bool _gamePluginInstalled = false;
  String? _lastNote;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await PerformanceService.ensureNotificationChannel();
    final post = await PerformanceService.hasPostNotifications();
    if (!post) {
      await PerformanceService.requestPostNotifications();
    }
    final mem = await PerformanceService.memoryInfo();
    final active = await PerformanceService.getActiveMode();
    final policy = await PerformanceService.hasNotificationPolicyAccess();
    final game = await PluginService.isInstalled('perf-game-overlay-fps');
    if (!mounted) return;
    setState(() {
      _mem = mem;
      _mode = PerfModeX.fromId(active);
      _policyAccess = policy;
      _gamePluginInstalled = game;
      _loading = false;
    });
  }

  Future<void> _apply(PerfMode mode) async {
    if (_applying) return;
    if (mode == PerfMode.focus && !_policyAccess) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: HubColors.panel,
          title: const Text('Acceso a No molestar (Focus)',
              style: TextStyle(color: HubColors.textoPrincipal)),
          content: const Text(
            'Focus no usa el permiso normal de notificaciones.\n\n'
            'En Ajustes busca la lista "Acceso a No molestar" o "Acceso a la política de notificaciones" '
            'y activa el interruptor de Anythings Hub.\n\n'
            'No abras "Notificaciones de la app": ahí Android dice que la app no las solicita.',
            style: TextStyle(color: HubColors.textoSecundario, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Ahora no', style: TextStyle(color: HubColors.textoSecundario)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Abrir Ajustes', style: TextStyle(color: HubColors.pomelo)),
            ),
          ],
        ),
      );
      if (go == true) await PerformanceService.openNotificationPolicySettings();
      return;
    }

    setState(() => _applying = true);
    final result = await PerformanceService.applyMode(mode);
    final mem = await PerformanceService.memoryInfo();
    if (!mounted) return;

    String note = 'Modo ${mode.label} activo';
    final trim = result?['trim'] as Map?;
    if (trim != null) {
      final killed = trim['killed'] as int? ?? 0;
      final attempted = trim['attempted'] as int? ?? 0;
      note = 'Modo ${mode.label}: $killed/$attempted procesos en segundo plano innecesarios tratados.';
    }
    if (mode == PerfMode.focus && result?['focusNotifications'] == true) {
      note += ' Notificaciones de terceros silenciadas (visibles sin sonido).';
    }

    setState(() {
      _mode = mode;
      _mem = mem;
      _lastNote = note;
      _applying = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: HubColors.panel,
      content: Text(note, style: const TextStyle(color: HubColors.textoPrincipal)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HubColors.fondoPrincipal,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Modos de rendimiento',
            style: TextStyle(color: HubColors.textoPrincipal, fontSize: 17)),
        iconTheme: const IconThemeData(color: HubColors.textoPrincipal),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loading ? null : _refresh),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: HubColors.pomelo))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _memoryCard(),
                const SizedBox(height: 16),
                const Text('Elige un modo',
                    style: TextStyle(color: HubColors.textoPrincipal, fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 4),
                const Text(
                  'Solo se cierran procesos en segundo plano innecesarios de apps de usuario. Nunca apps del sistema ni el proceso en primer plano.',
                  style: TextStyle(color: HubColors.textoSecundario, fontSize: 12, height: 1.35),
                ),
                const SizedBox(height: 12),
                for (final m in PerfMode.values) ...[
                  _modeTile(m),
                  const SizedBox(height: 10),
                ],
                if (_gamePluginInstalled) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: HubColors.panel,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: HubColors.linea),
                    ),
                    child: const Row(children: [
                      Icon(Icons.extension_rounded, color: Color(0xFF5B8DEF), size: 22),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Plugin Overlay FPS / Juegos instalado. El modo juego y el overlay solo se activan desde el plugin (no forman parte del nucleo).',
                          style: TextStyle(color: HubColors.textoSecundario, fontSize: 12),
                        ),
                      ),
                    ]),
                  ),
                ],
                if (_lastNote != null) ...[
                  const SizedBox(height: 16),
                  Text(_lastNote!, style: const TextStyle(color: HubColors.textoAcento, fontSize: 12)),
                ],
                if (!_policyAccess) ...[
                  const SizedBox(height: 20),
                  GradientPillButton(
                    label: 'Abrir acceso a No molestar (Focus)',
                    icon: Icons.notifications_off_outlined,
                    onPressed: () => PerformanceService.openNotificationPolicySettings(),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _memoryCard() {
    final m = _mem;
    final ratio = m?.usedRatio ?? 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HubColors.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HubColors.linea),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.memory_rounded, color: HubColors.pomelo, size: 20),
            const SizedBox(width: 8),
            const Text('Memoria', style: TextStyle(color: HubColors.textoPrincipal, fontWeight: FontWeight.w700)),
            const Spacer(),
            if (m != null)
              Text('${m.availMb} MB libres / ${m.totalMb} MB',
                  style: const TextStyle(color: HubColors.textoSecundario, fontSize: 11)),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: HubColors.fondoPrincipal,
              color: ratio > 0.85 ? Colors.redAccent : ratio > 0.7 ? HubColors.amarillo : HubColors.pomelo,
            ),
          ),
          if (m?.lowMemory == true) ...[
            const SizedBox(height: 8),
            const Text('El sistema reporta memoria baja',
                style: TextStyle(color: Colors.redAccent, fontSize: 11)),
          ],
        ],
      ),
    );
  }

  Widget _modeTile(PerfMode m) {
    final selected = _mode == m;
    final icon = switch (m) {
      PerfMode.balanced => Icons.balance_rounded,
      PerfMode.eco => Icons.eco_rounded,
      PerfMode.focus => Icons.center_focus_strong_rounded,
      PerfMode.performance => Icons.speed_rounded,
    };
    final color = switch (m) {
      PerfMode.balanced => HubColors.textoAcento,
      PerfMode.eco => const Color(0xFF3DDC84),
      PerfMode.focus => const Color(0xFF5B8DEF),
      PerfMode.performance => HubColors.pomelo,
    };

    return Material(
      color: HubColors.panel,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _applying ? null : () => _apply(m),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? color : HubColors.linea, width: selected ? 1.6 : 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(m.label,
                          style: const TextStyle(
                              color: HubColors.textoPrincipal, fontWeight: FontWeight.w700, fontSize: 14.5)),
                      if (selected) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('Activo',
                              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 4),
                    Text(m.description,
                        style: const TextStyle(color: HubColors.textoSecundario, fontSize: 12, height: 1.35)),
                  ],
                ),
              ),
              if (_applying && selected)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: HubColors.pomelo),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
