import 'package:flutter/material.dart';

import '../../../core/hub_colors.dart';
import '../../../ui/widgets/gradient_pill_button.dart';
import '../models/app_models.dart';
import '../widgets/hub_panel.dart';
import 'analisis_complementario_screen.dart';
import 'verificacion_firma_screen.dart';

/// Puente de soberan\u00eda: risk score + permisos + override del usuario.
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
          style: TextStyle(color: HubColors.textoPrincipal, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(report.fileName, style: TextStyle(color: HubColors.textoPrincipal, fontSize: 14)),
          const SizedBox(height: 2),
          Text(report.packageName, style: TextStyle(color: HubColors.textoSecundario, fontSize: 13)),
          if (advisoryNote != null && advisoryNote!.isNotEmpty) ...[
            const SizedBox(height: 12),
            HubPanel(
              child: Text(
                advisoryNote!,
                style: TextStyle(color: HubColors.textoSecundario, fontSize: 12),
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
                    painter: _GaugePainter(
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
                  'Esta APK tiene un riesgo $_levelLabel seg\u00fan el an\u00e1lisis.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: HubColors.textoSecundario, fontSize: 13),
                ),
              ],
            ),
          ),
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
              padding: const EdgeInsets.only(bottom: 8),
              child: HubPanel(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      p.critical ? Icons.warning_amber_rounded : Icons.info_outline,
                      color: p.critical ? const Color(0xFFE53935) : HubColors.textoSecundario,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            style: TextStyle(
                              color: HubColors.textoPrincipal,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            p.description,
                            style: TextStyle(color: HubColors.textoSecundario, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if (p.critical)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE53935).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'CR\u00cdTICO',
                          style: TextStyle(
                            color: Color(0xFFE53935),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (report.trackingSdks.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'SDKs DE RASTREO DETECTADOS',
              style: TextStyle(
                color: HubColors.textoSecundario,
                fontSize: 12,
                letterSpacing: 1.0,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            HubPanel(
              child: Column(
                children: report.trackingSdks
                    .map(
                      (s) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Icon(Icons.analytics_outlined, size: 18, color: HubColors.textoSecundario),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(s, style: TextStyle(color: HubColors.textoPrincipal, fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AnalisisComplementarioScreen(report: report),
                ),
              );
            },
            icon: Icon(Icons.travel_explore, color: HubColors.textoAcento),
            label: Text(
              'An\u00e1lisis complementario (opcional)',
              style: TextStyle(color: HubColors.textoAcento),
            ),
          ),
          TextButton.icon(
            onPressed: () {
              final primaryCert = report.signingCertSha256.isNotEmpty
                  ? report.signingCertSha256.first
                  : report.sha256;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => VerificacionFirmaScreen(
                    packageName: report.packageName,
                    versionLabel: report.versionLabel,
                    certSha256: primaryCert,
                    signingCertSha256: report.signingCertSha256,
                    installedCertSha256: report.installedCertSha256,
                    isPackageInstalled: report.isPackageInstalled,
                  ),
                ),
              );
            },
            icon: Icon(Icons.verified_user_outlined, color: HubColors.textoAcento),
            label: Text(
              'Verificar firma (or\u00e1culo)',
              style: TextStyle(color: HubColors.textoAcento),
            ),
          ),
          const SizedBox(height: 8),
          HubPanel(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.gavel, color: HubColors.pomelo.withOpacity(0.9), size: 22),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tu soberan\u00eda, tu decisi\u00f3n.',
                        style: TextStyle(
                          color: HubColors.textoPrincipal,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'El sistema no te impide instalar. Si contin\u00faas, es bajo tu responsabilidad.',
                        style: TextStyle(color: HubColors.textoSecundario, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
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
            child: Text('Cancelar', style: TextStyle(color: HubColors.textoSecundario)),
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = 10.0;
    final rect = Rect.fromLTWH(stroke, stroke, size.width - stroke * 2, size.height * 1.6);
    final bg = Paint()
      ..color = HubColors.linea
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    const start = 3.1416;
    const sweep = 3.1416;
    canvas.drawArc(rect, start, sweep, false, bg);
    canvas.drawArc(rect, start, sweep * progress.clamp(0.0, 1.0), false, fg);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.progress != progress || old.color != color;
}
