import 'package:flutter/material.dart';

import '../../../core/hub_colors.dart';
import '../../../ui/widgets/gradient_pill_button.dart';
import '../models/app_models.dart';
import '../widgets/hub_panel.dart';
import 'analisis_complementario_screen.dart';
import 'verificacion_firma_screen.dart';

/// Permisos + acciones (firma, análisis, instalar) del review APK.
class ApkRiskActions extends StatelessWidget {
  const ApkRiskActions({
    super.key,
    required this.report,
    this.onInstallOverride,
  });
  final ApkRiskReport report;
  final VoidCallback? onInstallOverride;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Text(
          'PERMISOS SOLICITADOS',
          style: TextStyle(
            color: HubColors.textoSecundario,
            fontSize: 12,
            letterSpacing: 1.0,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        ...report.permissions.map(
          (p) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: HubPanel(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Text(
                p,
                style: TextStyle(
                    color: HubColors.textoPrincipal, fontSize: 13),
              ),
            ),
          ),
        ),
        if (report.permissions.isEmpty)
          Text(
            'Sin permisos listados.',
            style: TextStyle(color: HubColors.textoSecundario, fontSize: 13),
          ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: HubColors.textoAcento,
            side: BorderSide(color: HubColors.linea),
          ),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AnalisisComplementarioScreen(report: report),
              ),
            );
          },
          icon: Icon(Icons.travel_explore, color: HubColors.textoAcento),
          label: Text(
            'Análisis complementario (opcional)',
            style: TextStyle(color: HubColors.textoAcento),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: HubColors.textoAcento,
            side: BorderSide(color: HubColors.linea),
          ),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => VerificacionFirmaScreen(report: report),
              ),
            );
          },
          icon: Icon(Icons.verified_user_outlined,
              color: HubColors.textoAcento),
          label: Text(
            'Verificar firma (oráculo)',
            style: TextStyle(color: HubColors.textoAcento),
          ),
        ),
        const SizedBox(height: 20),
        GradientPillButton(
          label: 'Instalar bajo mi responsabilidad',
          icon: Icons.shield_outlined,
          onPressed: () {
            onInstallOverride?.call();
          },
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancelar',
              style: TextStyle(color: HubColors.textoSecundario)),
        ),
      ],
    );
  }
}
