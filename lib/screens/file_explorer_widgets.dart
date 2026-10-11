import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/hub_colors.dart';
import '../services/device_files_service.dart';
import '../services/device_apps_service.dart';
import '../services/file_preview_service.dart';

class FileThumb extends StatefulWidget {
  const FileThumb({
    required this.entry,
    required this.fallbackIcon,
    required this.fallbackColor,
    this.size = 42,
  });

  final FileEntry entry;
  final IconData fallbackIcon;
  final Color fallbackColor;
  final double size;

  @override
  State<FileThumb> createState() => _FileThumbState();
}

class _FileThumbState extends State<FileThumb> {
  ImageProvider? _provider;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant FileThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.path != widget.entry.path) {
      _provider = null;
      _load();
    }
  }

  Future<void> _load() async {
    final e = widget.entry;
    if (e.isDirectory) return;
    final ext = e.extension.toLowerCase();
    if (FilePreviewService.isImage(ext)) {
      final f = File(e.path);
      if (await f.exists() && mounted) {
        setState(() => _provider = FileImage(f));
      }
      return;
    }
    if (FilePreviewService.isApk(ext)) {
      final key = FilePreviewService.apkCacheKey(e.path, e.size);
      final cached = await FilePreviewService.cachedIcon(key);
      if (cached != null && mounted) {
        setState(() => _provider = FileImage(cached));
        return;
      }
      final meta = await DeviceAppsService.inspectApkPath(e.path);
      final icon = meta?['icon'];
      if (icon is Uint8List && icon.isNotEmpty) {
        await FilePreviewService.cacheIconBytes(key, icon);
        if (mounted) setState(() => _provider = MemoryImage(icon));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        color: widget.fallbackColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: _provider != null
          ? Image(
              image: _provider!,
              fit: BoxFit.cover,
              width: s,
              height: s,
              errorBuilder: (_, __, ___) => Icon(widget.fallbackIcon,
                  size: s * 0.55, color: widget.fallbackColor),
            )
          : Icon(widget.fallbackIcon,
              size: s * 0.55, color: widget.fallbackColor),
    );
  }
}

class FileDetailsDialog extends StatefulWidget {
  const FileDetailsDialog({required this.entry});
  final FileEntry entry;

  @override
  State<FileDetailsDialog> createState() => _FileDetailsDialogState();
}

class _FileDetailsDialogState extends State<FileDetailsDialog> {
  bool _loading = true;
  String? _md5;
  String? _sha1;
  String? _textPreview;
  Map<String, dynamic>? _apk;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final e = widget.entry;
    if (e.isDirectory) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final ext = e.extension.toLowerCase();
    final futures = <Future>[
      FilePreviewService.hashes(e.path).then((h) {
        if (h != null) {
          _md5 = h.md5hex;
          _sha1 = h.sha1hex;
        }
      }),
    ];
    if (FilePreviewService.isText(ext)) {
      futures.add(
          FilePreviewService.textPreview(e.path).then((t) => _textPreview = t));
    }
    if (FilePreviewService.isApk(ext)) {
      futures.add(DeviceAppsService.inspectApkPath(e.path).then((m) {
        _apk = m;
        final icon = m?['icon'];
        if (icon is Uint8List && icon.isNotEmpty) {
          FilePreviewService.cacheIconBytes(
              FilePreviewService.apkCacheKey(e.path, e.size), icon);
        }
      }));
    }
    await Future.wait(futures);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    return AlertDialog(
      backgroundColor: HubColors.panel,
      title: Text(e.name,
          style: TextStyle(color: HubColors.textoPrincipal, fontSize: 16)),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _row(
                  'Tipo',
                  e.isDirectory
                      ? 'Carpeta'
                      : (e.extension.isEmpty
                          ? 'Archivo'
                          : e.extension.toUpperCase())),
              _row('Ruta', e.path),
              if (!e.isDirectory) _row('Tamaño', e.sizeLabel),
              if (e.modifiedMs > 0) _row('Modificado', _fmt(e.modified)),
              if (_loading)
                Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(
                      child: CircularProgressIndicator(
                          color: HubColors.pomelo, strokeWidth: 2)),
                ),
              if (!_loading && _md5 != null) ...[
                _row('MD5', _md5!, mono: true),
                _row('SHA-1', _sha1 ?? '—', mono: true),
              ],
              if (!_loading && _apk != null) ...[
                SizedBox(height: 8),
                Text('APK (solo lectura)',
                    style: TextStyle(
                        color: HubColors.pomelo, fontWeight: FontWeight.w700)),
                _row('Paquete', '${_apk!['packageName'] ?? '—'}'),
                _row('Nombre', '${_apk!['appLabel'] ?? '—'}'),
                _row('Versión',
                    '${_apk!['versionName'] ?? '—'} (${_apk!['versionCode'] ?? '—'})'),
                if (_apk!['permissions'] is List)
                  ...((_apk!['permissions'] as List).take(8).map((p) {
                    final s = p.toString();
                    final short = s.contains('.') ? s.split('.').last : s;
                    return Text('• $short',
                        style: TextStyle(
                            color: HubColors.textoPrincipal, fontSize: 12));
                  })),
              ],
              if (!_loading &&
                  _textPreview != null &&
                  _textPreview!.isNotEmpty) ...[
                SizedBox(height: 10),
                Text('Vista previa (20 líneas)',
                    style: TextStyle(
                        color: HubColors.textoSecundario,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: HubColors.fondoPrincipal,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: HubColors.linea),
                  ),
                  child: Text(
                    _textPreview!,
                    style: TextStyle(
                      color: HubColors.textoPrincipal,
                      fontSize: 11,
                      fontFamily: 'monospace',
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cerrar',
              style: TextStyle(color: HubColors.pomelo)),
        ),
      ],
    );
  }

  static String _fmt(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  static Widget _row(String label, String value, {bool mono = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: HubColors.textoSecundario, fontSize: 11)),
          SizedBox(height: 2),
          SelectableText(
            value,
            style: TextStyle(
              color: HubColors.textoPrincipal,
              fontSize: mono ? 11 : 13,
              fontFamily: mono ? 'monospace' : null,
            ),
          ),
        ],
      ),
    );
  }
}
