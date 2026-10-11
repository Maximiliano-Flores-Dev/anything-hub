import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/hub_colors.dart';
import '../../../services/device_apps_service.dart';
import '../services/apk_risk_scorer.dart';
import '../services/puerto_pipe_service.dart';
import 'revisar_apk_screen.dart';

class PuertoLimboScreen extends StatefulWidget {
  const PuertoLimboScreen({
    super.key,
    required this.name,
    required this.apkUrl,
    required this.gray,
  });

  final String name;
  final String apkUrl;
  final bool gray;

  @override
  State<PuertoLimboScreen> createState() => _PuertoLimboScreenState();
}

class _PuertoLimboScreenState extends State<PuertoLimboScreen> {
  String _phase = 'Conectando el tubo\u2026';
  int _bytes = 0;
  int _total = 0;
  String? _error;
  bool _done = false;
  StreamSubscription<Map<String, dynamic>>? _sub;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _run() async {
    _sub = PuertoPipeService.download(widget.apkUrl).listen((event) async {
      final phase = event['phase'] as String? ?? '';
      if (phase == 'downloading') {
        if (!mounted) return;
        setState(() {
          _phase = 'Pasando bytes al limbo\u2026';
          _bytes = (event['bytes'] as num?)?.toInt() ?? 0;
          _total = (event['total'] as num?)?.toInt() ?? 0;
        });
        return;
      }
      if (phase == 'complete') {
        await _sub?.cancel();
        await _afterDownload(event);
      }
    }, onError: (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    });
  }

  Future<void> _afterDownload(Map<String, dynamic> event) async {
    if (!mounted) return;
    setState(() => _phase = 'Leyendo manifiesto\u2026');
    final relative = event['cacheRelativePath'] as String? ?? '';
    final sha = event['sha256'] as String? ?? '';
    final meta = await DeviceAppsService.inspectApk(relative);
    final packageName = (meta?['packageName'] as String?)?.trim();
    final parseFailed = packageName == null || packageName.isEmpty;
    final perms = (meta?['permissions'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];
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
    final report = ApkRiskScorer.score(
      fileName: widget.name,
      packageName: parseFailed ? 'com.desconocido.apk' : (packageName ?? 'com.desconocido.apk'),
      rawPermissions: parseFailed ? const ['android.permission.PARSE_FAILED'] : perms,
      detectedPackages: const [],
      sha256: sha,
      parseFailed: parseFailed,
      versionLabel: versionLabel.isEmpty ? '\u2014' : versionLabel,
      signingCertSha256: signingCerts,
      installedCertSha256: installedCerts,
      isPackageInstalled: isInstalled,
    );

    Map<String, dynamic>? vt;
    final key = await PuertoPipeService.virusTotalKey();
    if (key != null && sha.isNotEmpty) {
      if (mounted) setState(() => _phase = 'Consultando VirusTotal por hash\u2026');
      vt = await PuertoPipeService.virusTotalLookup(sha256: sha, apiKey: key);
    }

    if (!mounted) return;
    setState(() => _done = true);
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RevisarApkScreen(
          report: report,
          advisoryNote: _note(sha, vt, widget.gray),
          onInstallOverride: () {
            DeviceAppsService.installApkFromCache(relative);
          },
        ),
      ),
    );
  }

  String _note(String sha, Map<String, dynamic>? vt, bool gray) {
    final buf = StringBuffer()
      ..writeln('Limbo: el APK est\u00e1 en cach\u00e9, todav\u00eda no instalado.')
      ..writeln('SHA-256: $sha');
    if (gray) {
      buf.writeln('Origen en zona gris. Esto es una recomendaci\u00f3n, no un permiso.');
    }
    if (vt == null) {
      buf.writeln('VirusTotal: sin clave. El escaneo local de permisos s\u00ed se hizo.');
    } else if (vt['found'] == true) {
      buf.writeln(
        'VirusTotal: maliciosos ${vt['malicious']}, sospechosos ${vt['suspicious']}, '
        'inofensivos ${vt['harmless']}.',
      );
    } else {
      buf.writeln('VirusTotal: ${vt['note']}');
    }
    buf.writeln('T\u00fa decides si instalas.');
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _total > 0 ? _bytes / _total : null;
    return Scaffold(
      backgroundColor: HubColors.fondoPrincipal,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(widget.name, style: TextStyle(color: HubColors.textoPrincipal)),
        iconTheme: IconThemeData(color: HubColors.textoPrincipal),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_error ?? _phase, style: TextStyle(color: HubColors.textoPrincipal)),
            SizedBox(height: 16),
            LinearProgressIndicator(
              value: _done ? 1 : progress,
              color: HubColors.pomelo,
              backgroundColor: HubColors.linea,
            ),
            SizedBox(height: 8),
            Text(
              _total > 0 ? '$_bytes / $_total bytes' : '$_bytes bytes',
              style: TextStyle(color: HubColors.textoSecundario, fontSize: 12),
            ),
            const Spacer(),
            Text(
              'El archivo no se instala solo. Primero queda en limbo y se analiza.',
              style: TextStyle(color: HubColors.textoSecundario, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
