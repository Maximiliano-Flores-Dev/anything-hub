import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/hub_colors.dart';
import '../../../services/device_apps_service.dart';
import '../../../ui/widgets/gradient_pill_button.dart';
import '../models/app_models.dart';
import '../services/apps_local_store.dart';
import '../widgets/hub_panel.dart';

/// Pantalla de gestión al tocar un icono en la grilla.
class AppGestionScreen extends StatefulWidget {
  const AppGestionScreen({super.key, required this.app});

  final ManagedApp app;

  @override
  State<AppGestionScreen> createState() => _AppGestionScreenState();
}

class _AppGestionScreenState extends State<AppGestionScreen> {
  final _store = AppsLocalStore();
  final _noteCtrl = TextEditingController();

  late bool _bookmarked;
  double _performance = 5;
  double _privacy = 5;

  static const _channel = MethodChannel('anythings.hub/device_apps');

  @override
  void initState() {
    super.initState();
    _bookmarked = widget.app.isBookmarked;
    final r = widget.app.localReview;
    if (r != null) {
      _performance = r.performance;
      _privacy = r.privacy;
      _noteCtrl.text = r.note;
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleBookmark() async {
    final next = !_bookmarked;
    await _store.setBookmarked(widget.app.packageName, next);
    setState(() => _bookmarked = next);
  }

  Future<void> _saveReview() async {
    final review = LocalAppReview(
      performance: _performance,
      privacy: _privacy,
      note: _noteCtrl.text.trim(),
    );
    await _store.saveReview(widget.app.packageName, review);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Reseña guardada en este dispositivo'),
        backgroundColor: HubColors.panel,
      ),
    );
  }

  Future<void> _launch() async {
    final ok = await DeviceAppsService.launch(widget.app.packageName);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo lanzar la aplicación')),
      );
    }
  }

  Future<void> _openSettings() async {
    try {
      await _channel.invokeMethod('openAppSettings', {
        'package': widget.app.packageName,
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Abre Ajustes del sistema → Apps para configurar'),
        ),
      );
    }
  }

  Future<void> _uninstall() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HubColors.panel,
        title: Text('Desinstalar', style: TextStyle(color: HubColors.textoPrincipal)),
        content: Text(
          '¿Desinstalar ${widget.app.name}? Esta acción usa el desinstalador del sistema.',
          style: TextStyle(color: HubColors.textoSecundario),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Desinstalar', style: TextStyle(color: HubColors.pomelo)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _channel.invokeMethod('requestUninstall', {
        'package': widget.app.packageName,
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo iniciar la desinstalación')),
      );
    }
  }

  void _popWithState() {
    Navigator.of(context).pop(
      widget.app.copyWith(
        isBookmarked: _bookmarked,
        localReview: LocalAppReview(
          performance: _performance,
          privacy: _privacy,
          note: _noteCtrl.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _popWithState();
      },
      child: Scaffold(
        backgroundColor: HubColors.fondoPrincipal,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: HubColors.textoPrincipal),
            onPressed: _popWithState,
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            Center(
              child: widget.app.icon != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.memory(widget.app.icon!, width: 72, height: 72),
                    )
                  : Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: HubColors.panel,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(Icons.android, size: 40, color: HubColors.textoSecundario),
                    ),
            ),
            const SizedBox(height: 14),
            Text(
              widget.app.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: HubColors.textoPrincipal,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.app.packageName,
              textAlign: TextAlign.center,
              style: TextStyle(color: HubColors.textoSecundario, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.circle, size: 8, color: Color(0xFF3DDC84)),
                const SizedBox(width: 6),
                Text('Instalada', style: TextStyle(color: HubColors.textoSecundario, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: GradientPillButton(
                    label: 'Lanzar',
                    icon: Icons.play_arrow_rounded,
                    onPressed: _launch,
                  ),
                ),
                const SizedBox(width: 8),
                _ActionIcon(
                  icon: Icons.settings_outlined,
                  label: 'Ajustes',
                  onTap: _openSettings,
                ),
                const SizedBox(width: 8),
                _ActionIcon(
                  icon: Icons.delete_outline,
                  label: 'Desinstalar',
                  onTap: _uninstall,
                ),
                const SizedBox(width: 8),
                _ActionIcon(
                  icon: _bookmarked ? Icons.star_rounded : Icons.star_outline_rounded,
                  label: 'Guardar',
                  color: _bookmarked ? HubColors.amarillo : HubColors.textoSecundario,
                  onTap: _toggleBookmark,
                ),
              ],
            ),
            const SizedBox(height: 28),
            HubPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.rate_review_outlined, size: 18, color: HubColors.textoSecundario),
                      const SizedBox(width: 8),
                      Text(
                        'Reseña local',
                        style: TextStyle(
                          color: HubColors.textoPrincipal,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tu evaluación privada de esta app',
                    style: TextStyle(color: HubColors.textoSecundario, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  _SliderRow(
                    icon: Icons.speed,
                    label: 'Rendimiento',
                    value: _performance,
                    onChanged: (v) => setState(() => _performance = v),
                  ),
                  const SizedBox(height: 12),
                  _SliderRow(
                    icon: Icons.shield_outlined,
                    label: 'Privacidad',
                    value: _privacy,
                    onChanged: (v) => setState(() => _privacy = v),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _noteCtrl,
                    maxLength: 120,
                    maxLines: 2,
                    style: TextStyle(color: HubColors.textoPrincipal),
                    decoration: InputDecoration(
                      hintText: 'Escribe tu opinión personal…',
                      hintStyle: TextStyle(color: HubColors.textoSecundario),
                      filled: true,
                      fillColor: HubColors.fondoPrincipal,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(radius12),
                        borderSide: BorderSide(color: HubColors.linea),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(radius12),
                        borderSide: BorderSide(color: HubColors.linea),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _saveReview,
                      child: Text('Guardar reseña', style: TextStyle(color: HubColors.pomelo)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Solo en este dispositivo',
                style: TextStyle(color: HubColors.textoSecundario, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HubColors.panel,
      borderRadius: BorderRadius.circular(radius12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius12),
        child: SizedBox(
          width: 64,
          height: 56,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color ?? HubColors.textoSecundario, size: 22),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(color: color ?? HubColors.textoSecundario, fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: HubColors.textoSecundario),
        const SizedBox(width: 8),
        SizedBox(
          width: 88,
          child: Text(label, style: TextStyle(color: HubColors.textoSecundario, fontSize: 13)),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: HubColors.pomelo,
              inactiveTrackColor: HubColors.linea,
              thumbColor: HubColors.textoPrincipal,
              overlayColor: HubColors.pomelo.withOpacity(0.2),
            ),
            child: Slider(
              min: 0,
              max: 10,
              divisions: 20,
              value: value,
              onChanged: onChanged,
            ),
          ),
        ),
        Text(
          value.toStringAsFixed(1),
          style: TextStyle(color: HubColors.textoPrincipal, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
