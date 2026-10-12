import 'package:flutter/material.dart';

import '../../../core/hub_colors.dart';
import '../models/app_models.dart';
import '../widgets/hub_panel.dart';
import 'apk_risk_actions.dart';
import 'apk_risk_gauge.dart';

/// Puente de soberanía: risk score + permisos + override del usuario.
class RevisarApkScreen extends StatelessWidget {
  const RevisarApkScreen({
    super.key,
    required this.report,
    this.onInstallOverride,
    this.advisoryNote,
  });

  final ApkRiskReport report;
  final VoidCallback? onInstallOverride;
  final String? advisoryNote;

  Color get _levelColor {
    switch (report.level) {
      case RiskLevel.bajo:
        return const Color(0xFF3DDC84);
      case RiskLevel.moderado:
        return HubColors.amarillo;
      case RiskLevel.alto:
        return const Color(0xFFE53935);
    }
  }

  String get _levelLabel {
    switch (report.level) {
      case RiskLevel.bajo:
        return 'Bajo';
      case RiskLevel.moderado:
        return 'Moderado';
      case RiskLevel.alto:
        return 'Alto';
    }
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
          'Revisar APK',
          style: TextStyle(
              color: HubColors.textoPrincipal, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(report.fileName,
              style: TextStyle(color: HubColors.textoPrincipal, fontSize: 14)),
          const SizedBox(height: 2),
          Text(report.packageName,
              style: TextStyle(color: HubColors.textoSecundario, fontSize: 13)),
          if (advisoryNote != null && advisoryNote!.isNotEmpty) ...[
            const SizedBox(height: 12),
            HubPanel(
              child: Text(
                advisoryNote!,
                style:
                    TextStyle(color: HubColors.textoSecundario, fontSize: 12),
              ),
            ),
          ],
          const SizedBox(height: 24),
          HubPanel(
            child: Column(
              children: [
                Text(
                  'NIVEL DE RIESGO',
                  style: TextStyle(
                    color: HubColors.textoSecundario,
                    fontSize: 12,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 100,
                  child: CustomPaint(
                    painter: ApkRiskGaugePainter(
                      progress: report.score / 100,
                      color: _levelColor,
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${report.score}',
                              style: TextStyle(
                                color: _levelColor,
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              _levelLabel,
                              style: TextStyle(
                                color: _levelColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Esta APK tiene un riesgo $_levelLabel según el análisis.',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: HubColors.textoSecundario, fontSize: 13),
                ),
              ],
            ),
          ),
          ApkRiskActions(
            report: report,
            onInstallOverride: onInstallOverride,
          ),
        ],
      ),
    );
  }
}
