import 'package:flutter/material.dart';

import '../../../core/hub_colors.dart';
import '../../../ui/widgets/gradient_pill_button.dart';
import '../models/app_models.dart';
import '../widgets/hub_panel.dart';

/// Oráculo de firmas + soporte offline (TTL) + fail-closed con override.
class VerificacionFirmaScreen extends StatefulWidget {
  const VerificacionFirmaScreen({
    super.key,
    required this.packageName,
    required this.versionLabel,
    this.certSha256,
  });

  final String packageName;
  final String versionLabel;
  final String? certSha256;

  @override
  State<VerificacionFirmaScreen> createState() => _VerificacionFirmaScreenState();
}

class _VerificacionFirmaScreenState extends State<VerificacionFirmaScreen> {
  bool _loading = true;
  SignatureCheckResult? _result;

  @override
  void initState() {
    super.initState();
    _runCheck();
  }

  Future<void> _runCheck() async {
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));

    final result = SignatureCheckResult(
      status: SignatureStatus.cacheHit,
      packageName: widget.packageName,
      versionLabel: widget.versionLabel,
      certSha256: widget.certSha256,
      cacheAgeDays: 5,
      message: 'Verificación con datos almacenados',
    );

    if (!mounted) return;
    setState(() {
      _result = result;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HubColors.fondoPrincipal,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: HubColors.textoPrincipal),
        title: const Text(
          'Verificación de firma',
          style: TextStyle(color: HubColors.textoPrincipal, fontWeight: FontWeight.w700),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: HubColors.pomelo))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                const Text(
                  'Comprobando la autenticidad de la aplicación',
                  style: TextStyle(color: HubColors.textoSecundario, fontSize: 14),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Icon(
                    Icons.verified_user,
                    size: 64,
                    color: _result?.status == SignatureStatus.unverified ||
                            _result?.status == SignatureStatus.error
                        ? const Color(0xFFE53935)
                        : const Color(0xFF3DDC84),
                  ),
                ),
                const SizedBox(height: 20),
                if (_result != null) ..._statusBlocks(_result!),
                const SizedBox(height: 12),
                HubPanel(
                  child: Column(
                    children: [
                      _kv('Paquete', widget.packageName),
                      const Divider(color: HubColors.linea),
                      _kv('Versión', widget.versionLabel),
                      const Divider(color: HubColors.linea),
                      _kv(
                        'Certificado (SHA-256)',
                        widget.certSha256 ?? '—',
                        mono: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                HubPanel(
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline, color: HubColors.textoAcento, size: 20),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Certificate Pinning',
                          style: TextStyle(color: HubColors.textoPrincipal, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: HubColors.textoAcento.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'FIJADO',
                          style: TextStyle(
                            color: HubColors.textoAcento,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_result?.status == SignatureStatus.unverified ||
                    _result?.status == SignatureStatus.error) ...[
                  const SizedBox(height: 16),
                  HubPanel(
                    child: const Row(
                      children: [
                        Icon(Icons.cancel_outlined, color: Color(0xFFE53935)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'No se pudo verificar. Puedes forzar bajo tu responsabilidad.',
                            style: TextStyle(color: HubColors.textoSecundario, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  GradientPillButton(
                    label: 'Continuar sin verificación',
                    icon: Icons.shield_outlined,
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ],
              ],
            ),
    );
  }

  List<Widget> _statusBlocks(SignatureCheckResult r) {
    final widgets = <Widget>[];
    if (r.status == SignatureStatus.verified || r.status == SignatureStatus.cacheHit) {
      widgets.add(
        HubPanel(
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF3DDC84)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Certificado coincide con el oráculo',
                      style: TextStyle(color: HubColors.textoPrincipal, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      r.status == SignatureStatus.cacheHit
                          ? 'Verificación exitosa (caché)'
                          : 'Verificación exitosa',
                      style: const TextStyle(color: Color(0xFF3DDC84), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (r.status == SignatureStatus.cacheHit && r.cacheAgeDays != null) {
      widgets.add(const SizedBox(height: 10));
      widgets.add(
        HubPanel(
          child: Row(
            children: [
              const Icon(Icons.wifi_off, color: HubColors.amarillo),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Sin red, usando caché de ${r.cacheAgeDays} días\n${r.message ?? ''}',
                  style: const TextStyle(color: HubColors.textoSecundario, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return widgets;
  }

  static Widget _kv(String k, String v, {bool mono = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(k, style: const TextStyle(color: HubColors.textoSecundario, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              v,
              style: TextStyle(
                color: HubColors.textoPrincipal,
                fontSize: mono ? 11 : 13,
                fontFamily: mono ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
