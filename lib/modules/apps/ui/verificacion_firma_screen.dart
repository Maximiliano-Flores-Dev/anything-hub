import 'package:flutter/material.dart';

import '../../../core/hub_colors.dart';
import '../../../ui/widgets/gradient_pill_button.dart';
import '../models/app_models.dart';
import '../services/signature_oracle_service.dart';
import '../widgets/hub_panel.dart';

/// Oráculo de firmas local + pins offline (TTL) + fail-closed con override.
class VerificacionFirmaScreen extends StatefulWidget {
  const VerificacionFirmaScreen({
    super.key,
    required this.packageName,
    required this.versionLabel,
    this.certSha256,
    this.signingCertSha256 = const [],
    this.installedCertSha256 = const [],
    this.isPackageInstalled = false,
  });

  final String packageName;
  final String versionLabel;
  final String? certSha256;
  final List<String> signingCertSha256;
  final List<String> installedCertSha256;
  final bool isPackageInstalled;

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

    final certs = widget.signingCertSha256.isNotEmpty
        ? widget.signingCertSha256
        : (widget.certSha256 != null && widget.certSha256!.isNotEmpty
            ? [widget.certSha256!]
            : <String>[]);

    final result = await SignatureOracleService.verify(
      packageName: widget.packageName,
      versionLabel: widget.versionLabel,
      apkCertSha256: certs,
      installedCertSha256: widget.installedCertSha256,
      isPackageInstalled: widget.isPackageInstalled,
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
        iconTheme: IconThemeData(color: HubColors.textoPrincipal),
        title: Text(
          'Verificación de firma',
          style: TextStyle(color: HubColors.textoPrincipal, fontWeight: FontWeight.w700),
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: HubColors.pomelo))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Text(
                  'Comprobando la autenticidad de la aplicación',
                  style: TextStyle(color: HubColors.textoSecundario, fontSize: 14),
                ),
                SizedBox(height: 24),
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
                SizedBox(height: 20),
                if (_result != null) ..._statusBlocks(_result!),
                SizedBox(height: 12),
                HubPanel(
                  child: Column(
                    children: [
                      _kv('Paquete', widget.packageName),
                      Divider(color: HubColors.linea),
                      _kv('Versión', widget.versionLabel),
                      Divider(color: HubColors.linea),
                      _kv(
                        'Certificado (SHA-256)',
                        widget.certSha256 ?? '—',
                        mono: true,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12),
                HubPanel(
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline, color: HubColors.textoAcento, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Oráculo local',
                          style: TextStyle(color: HubColors.textoPrincipal, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: HubColors.textoAcento.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _result?.status == SignatureStatus.verified ||
                                  _result?.status == SignatureStatus.cacheHit
                              ? 'OK'
                              : 'FAIL-CLOSED',
                          style: TextStyle(
                            color: _result?.status == SignatureStatus.verified ||
                                    _result?.status == SignatureStatus.cacheHit
                                ? const Color(0xFF3DDC84)
                                : const Color(0xFFE53935),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_result?.status == SignatureStatus.verified ||
                    _result?.status == SignatureStatus.cacheHit) ...[
                  SizedBox(height: 16),
                  GradientPillButton(
                    label: 'Fijar certificado (pin local)',
                    icon: Icons.push_pin_outlined,
                    onPressed: () async {
                      final cert = _result?.certSha256;
                      if (cert == null || cert.isEmpty) return;
                      await SignatureOracleService.pinPackage(
                        widget.packageName,
                        cert,
                      );
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Pin local guardado (TTL 90 días)'),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 12),
                  GradientPillButton(
                    label: 'Continuar',
                    icon: Icons.check,
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ],
                if (_result?.status == SignatureStatus.unverified ||
                    _result?.status == SignatureStatus.error) ...[
                  SizedBox(height: 16),
                  HubPanel(
                    child: Row(
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
                  SizedBox(height: 16),
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
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Certificado coincide con el oráculo',
                      style: TextStyle(color: HubColors.textoPrincipal, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      r.status == SignatureStatus.cacheHit
                          ? 'Verificación exitosa (caché)'
                          : 'Verificación exitosa',
                      style: TextStyle(color: Color(0xFF3DDC84), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (r.status == SignatureStatus.unverified || r.status == SignatureStatus.error) {
      widgets.add(
        HubPanel(
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFE53935)),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Firma no verificada',
                      style: TextStyle(color: HubColors.textoPrincipal, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      r.message ?? 'No se pudo confirmar autenticidad',
                      style: TextStyle(color: Color(0xFFE53935), fontSize: 12),
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
      widgets.add(SizedBox(height: 10));
      widgets.add(
        HubPanel(
          child: Row(
            children: [
              Icon(Icons.wifi_off, color: HubColors.amarillo),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Sin red, usando caché de ${r.cacheAgeDays} días\n${r.message ?? ''}',
                  style: TextStyle(color: HubColors.textoSecundario, fontSize: 13),
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
            child: Text(k, style: TextStyle(color: HubColors.textoSecundario, fontSize: 13)),
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
