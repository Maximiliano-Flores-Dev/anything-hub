import 'package:flutter/material.dart';

import '../../../core/hub_colors.dart';
import '../../../ui/widgets/gradient_pill_button.dart';
import '../../../services/device_apps_service.dart';
import '../models/app_models.dart';
import '../services/apk_risk_scorer.dart';
import '../widgets/hub_panel.dart';
import 'revisar_apk_screen.dart';

/// Bottom sheet / pantalla al recibir un APK vía Compartir o Abrir con.
class ApkIncomingSheet extends StatelessWidget {
  const ApkIncomingSheet({
    super.key,
    required this.fileName,
    required this.sizeBytes,
    required this.cacheRelativePath,
    this.callerPackage,
    this.callerVerified = false,
  });

  final String fileName;
  final int sizeBytes;
  final String cacheRelativePath;
  final String? callerPackage;
  final bool callerVerified;

  String get _sizeLabel {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HubColors.fondoPrincipal,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Anythings Hub',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: HubColors.textoPrincipal,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Todo en un solo lugar',
                textAlign: TextAlign.center,
                style: TextStyle(color: HubColors.textoSecundario, fontSize: 13),
              ),
              SizedBox(height: 28),
              HubPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.download_rounded, color: HubColors.pomelo),
                        SizedBox(width: 10),
                        Text(
                          'APK recibido',
                          style: TextStyle(
                            color: HubColors.textoPrincipal,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Archivo APK entrante compartido con Anythings Hub.',
                      style: TextStyle(color: HubColors.textoSecundario, fontSize: 12),
                    ),
                    SizedBox(height: 16),
                    _row(Icons.insert_drive_file_outlined, 'Nombre del archivo', fileName),
                    SizedBox(height: 10),
                    _row(Icons.sd_storage_outlined, 'Tamaño', _sizeLabel),
                    SizedBox(height: 10),
                    _row(
                      Icons.shield_outlined,
                      'Aplicación que comparte',
                      callerPackage == null || callerPackage!.isEmpty
                          ? 'Desconocido'
                          : '$callerPackage${callerVerified ? ' ✓' : ''}',
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
              Text(
                '¿Qué deseas hacer?',
                style: TextStyle(
                  color: HubColors.textoPrincipal,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Elige cómo quieres manejar este APK.',
                style: TextStyle(color: HubColors.textoSecundario, fontSize: 13),
              ),
              SizedBox(height: 16),
              GradientPillButton(
                label: 'Analizar antes de instalar',
                icon: Icons.search,
                onPressed: () => _analyze(context),
              ),
              SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: HubColors.textoPrincipal,
                  side: BorderSide(color: HubColors.linea),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop({'action': 'save', 'path': cacheRelativePath});
                },
                icon: const Icon(Icons.folder_outlined),
                label: Text('Solo guardar'),
              ),
              const Spacer(),
              Row(
                children: [
                  Icon(Icons.verified_user_outlined, size: 16, color: HubColors.textoSecundario),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Origen verificado con getCallingPackage cuando el sistema lo expone.',
                      style: TextStyle(color: HubColors.textoSecundario, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _analyze(BuildContext context) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: CircularProgressIndicator(color: HubColors.pomelo),
      ),
    );

    Map<String, dynamic>? meta;
    try {
      meta = await DeviceAppsService.inspectApk(cacheRelativePath);
    } catch (_) {
      meta = null;
    }

    if (!context.mounted) return;
    Navigator.of(context).pop();

    final packageName = (meta?['packageName'] as String?)?.trim();
    final appLabel = (meta?['appLabel'] as String?)?.trim();
    final rawPerms = (meta?['permissions'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        <String>[];
    final versionName = (meta?['versionName'] as String?)?.trim() ?? '';
    final versionCode = meta?['versionCode'];
    final versionLabel = [
      if (versionName.isNotEmpty) versionName,
      if (versionCode != null) '($versionCode)',
    ].join(' ').trim();
    final signingCerts = (meta?['signingCertSha256'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        <String>[];
    final installedCerts = (meta?['installedCertSha256'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        <String>[];
    final isInstalled = meta?['isPackageInstalled'] == true;

    final parseFailed = packageName == null || packageName.isEmpty;
    final displayName = (appLabel != null && appLabel.isNotEmpty)
        ? appLabel
        : fileName;
    final displayPackage = parseFailed ? 'com.desconocido.apk' : packageName!;

    final report = ApkRiskScorer.score(
      fileName: displayName,
      packageName: displayPackage,
      rawPermissions: parseFailed
          ? const ['android.permission.PARSE_FAILED']
          : rawPerms,
      detectedPackages: const [],
      sha256: null,
      parseFailed: parseFailed,
      versionLabel: versionLabel.isEmpty ? '—' : versionLabel,
      signingCertSha256: signingCerts,
      installedCertSha256: installedCerts,
      isPackageInstalled: isInstalled,
    );

    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RevisarApkScreen(
          report: report,
          onInstallOverride: () {
            DeviceAppsService.installApkFromCache(cacheRelativePath);
          },
        ),
      ),
    );
  }

  static Widget _row(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: HubColors.textoSecundario),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: HubColors.textoSecundario, fontSize: 12)),
              Text(value, style: TextStyle(color: HubColors.textoPrincipal, fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }
}
