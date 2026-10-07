import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/hub_colors.dart';
import '../core/logger.dart';
import '../services/device_apps_service.dart';
import '../services/device_files_service.dart';
import '../services/file_preview_service.dart';
import '../ui/widgets/gradient_pill_button.dart';

// NOTE: Full enhanced FileExplorer lives in artifacts; this commit is a marker.
// Replacing with full content in next push if needed.
enum _SortMode { nameAsc, nameDesc, dateNewest, dateOldest, sizeLargest, sizeSmallest }
enum _ViewMode { list, grid }
enum _ClipMode { none, copy, cut }

class _ClipboardItem {
  const _ClipboardItem(this.entries, this.mode);
  final List<FileEntry> entries;
  final _ClipMode mode;
}

class FileExplorerScreen extends StatefulWidget {
  const FileExplorerScreen({super.key});
  @override
  State<FileExplorerScreen> createState() => _FileExplorerScreenState();
}

class _FileExplorerScreenState extends State<FileExplorerScreen> with WidgetsBindingObserver {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, String>> _roots = [];
  String _currentPath = '';
  List<FileEntry> _entries = [];
  List<FileEntry> _filtered = [];
  bool _loading = true;
  bool _hasPermission = false;
  bool _showHidden = false;
  bool _selectionMode = false;
  String _searchQuery = '';
  _SortMode _sort = _SortMode.nameAsc;
  _ViewMode _view = _ViewMode.list;
  FileFilter _filter = FileFilter.all;
  final Set<String> _selected = {};
  _ClipboardItem? _clipboard;
  StorageInfo? _storageInfo;
  final List<String> _favorites = [];
  bool _awaitingPermission = false;
  static const _favKey = 'file_explorer_favorites';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.trim().toLowerCase();
        _applyFilterAndSort();
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingPermission) {
      _awaitingPermission = false;
      _bootstrap();
    }
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    _hasPermission = await DeviceFilesService.hasPermission();
    if (!_hasPermission) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    _roots = await DeviceFilesService.getRoots();
    if (_roots.isNotEmpty) {
      await _navigateTo(_roots.first['path']!);
    } else if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _navigateTo(String path) async {
    setState(() {
      _loading = true;
      _selected.clear();
      _selectionMode = false;
    });
    final list = await DeviceFilesService.listDirectory(path, showHidden: _showHidden);
    final info = await DeviceFilesService.getStorageInfo(path);
    if (!mounted) return;
    if (list == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _currentPath = path;
      _entries = list;
      _storageInfo = info;
      _applyFilterAndSort();
      _loading = false;
    });
  }

  void _applyFilterAndSort() {
    var list = List<FileEntry>.from(_entries);
    if (_searchQuery.isNotEmpty) {
      list = list.where((e) => e.name.toLowerCase().contains(_searchQuery)).toList();
    }
    list = list.where((e) => e.matchesType(_filter)).toList();
    list.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    _filtered = list;
  }

  void _showDetails(FileEntry entry) {
    showDialog(context: context, builder: (_) => _FileDetailsDialog(entry: entry));
  }

  void _showContextMenu(FileEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: HubColors.panel,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline, color: HubColors.textoAcento),
              title: const Text('Detalles', style: TextStyle(color: HubColors.textoPrincipal)),
              onTap: () {
                Navigator.pop(ctx);
                _showDetails(entry);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(FileEntry e) {
    if (e.isDirectory) return Icons.folder_rounded;
    final ext = e.extension.toLowerCase();
    if (const {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'}.contains(ext)) return Icons.image_rounded;
    if (ext == 'apk') return Icons.android_rounded;
    if (const {'txt', 'md', 'json'}.contains(ext)) return Icons.description_rounded;
    return Icons.insert_drive_file_rounded;
  }

  Color _iconColor(FileEntry e) {
    if (e.isDirectory) return HubColors.amarillo;
    final ext = e.extension.toLowerCase();
    if (const {'jpg', 'jpeg', 'png', 'gif', 'webp'}.contains(ext)) return const Color(0xFF5B8DEF);
    if (ext == 'apk') return const Color(0xFF3DDC84);
    return HubColors.textoSecundario;
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasPermission) {
      return Scaffold(
        backgroundColor: HubColors.fondoPrincipal,
        body: Center(
          child: GradientPillButton(
            label: 'Conceder acceso a archivos',
            icon: Icons.folder_open,
            onPressed: () async {
              _awaitingPermission = true;
              await DeviceFilesService.openPermissionSettings();
            },
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: HubColors.fondoPrincipal,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(_currentPath.split('/').last.isEmpty ? 'Archivos' : _currentPath.split('/').last,
            style: const TextStyle(color: HubColors.textoPrincipal, fontSize: 16)),
        iconTheme: const IconThemeData(color: HubColors.textoPrincipal),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _navigateTo(_currentPath),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: HubColors.pomelo))
          : ListView.builder(
              itemCount: _filtered.length,
              itemBuilder: (ctx, i) {
                final e = _filtered[i];
                return ListTile(
                  leading: _FileThumb(
                    entry: e,
                    fallbackIcon: _iconFor(e),
                    fallbackColor: _iconColor(e),
                  ),
                  title: Text(e.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: HubColors.textoPrincipal)),
                  subtitle: Text(
                    e.isDirectory ? '' : e.sizeLabel,
                    style: const TextStyle(color: HubColors.textoSecundario, fontSize: 11),
                  ),
                  trailing: e.isDirectory
                      ? const Icon(Icons.chevron_right, color: HubColors.textoSecundario)
                      : IconButton(
                          icon: const Icon(Icons.more_vert, color: HubColors.textoSecundario, size: 18),
                          onPressed: () => _showContextMenu(e),
                        ),
                  onTap: () {
                    if (e.isDirectory) {
                      _navigateTo(e.path);
                    } else {
                      _showDetails(e);
                    }
                  },
                  onLongPress: () => _showDetails(e),
                );
              },
            ),
    );
  }
}

class _FileThumb extends StatefulWidget {
  const _FileThumb({required this.entry, required this.fallbackIcon, required this.fallbackColor, this.size = 42});
  final FileEntry entry;
  final IconData fallbackIcon;
  final Color fallbackColor;
  final double size;
  @override
  State<_FileThumb> createState() => _FileThumbState();
}

class _FileThumbState extends State<_FileThumb> {
  ImageProvider? _provider;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final e = widget.entry;
    if (e.isDirectory) return;
    final ext = e.extension.toLowerCase();
    if (FilePreviewService.isImage(ext)) {
      final f = File(e.path);
      if (await f.exists() && mounted) setState(() => _provider = FileImage(f));
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
          ? Image(image: _provider!, fit: BoxFit.cover, width: s, height: s,
              errorBuilder: (_, __, ___) => Icon(widget.fallbackIcon, size: s * 0.55, color: widget.fallbackColor))
          : Icon(widget.fallbackIcon, size: s * 0.55, color: widget.fallbackColor),
    );
  }
}

class _FileDetailsDialog extends StatefulWidget {
  const _FileDetailsDialog({required this.entry});
  final FileEntry entry;
  @override
  State<_FileDetailsDialog> createState() => _FileDetailsDialogState();
}

class _FileDetailsDialogState extends State<_FileDetailsDialog> {
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
      futures.add(FilePreviewService.textPreview(e.path).then((t) => _textPreview = t));
    }
    if (FilePreviewService.isApk(ext)) {
      futures.add(DeviceAppsService.inspectApkPath(e.path).then((m) {
        _apk = m;
        final icon = m?['icon'];
        if (icon is Uint8List && icon.isNotEmpty) {
          FilePreviewService.cacheIconBytes(FilePreviewService.apkCacheKey(e.path, e.size), icon);
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
      title: Text(e.name, style: const TextStyle(color: HubColors.textoPrincipal, fontSize: 16)),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _row('Tipo', e.isDirectory ? 'Carpeta' : (e.extension.isEmpty ? 'Archivo' : e.extension.toUpperCase())),
              _row('Ruta', e.path),
              if (!e.isDirectory) _row('Tamaño', e.sizeLabel),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator(color: HubColors.pomelo, strokeWidth: 2)),
                ),
              if (!_loading && _md5 != null) ...[
                _row('MD5', _md5!, mono: true),
                _row('SHA-1', _sha1 ?? '—', mono: true),
              ],
              if (!_loading && _apk != null) ...[
                const SizedBox(height: 8),
                const Text('APK (solo lectura)', style: TextStyle(color: HubColors.pomelo, fontWeight: FontWeight.w700)),
                _row('Paquete', '${_apk!['packageName'] ?? '—'}'),
                _row('Nombre', '${_apk!['appLabel'] ?? '—'}'),
                _row('Versión', '${_apk!['versionName'] ?? '—'} (${_apk!['versionCode'] ?? '—'})'),
                if (_apk!['permissions'] is List)
                  ...((_apk!['permissions'] as List).take(8).map((p) {
                    final s = p.toString();
                    final short = s.contains('.') ? s.split('.').last : s;
                    return Text('• $short', style: const TextStyle(color: HubColors.textoPrincipal, fontSize: 12));
                  })),
              ],
              if (!_loading && _textPreview != null && _textPreview!.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text('Vista previa (20 líneas)', style: TextStyle(color: HubColors.textoSecundario, fontSize: 11)),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: HubColors.fondoPrincipal,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: HubColors.linea),
                  ),
                  child: Text(_textPreview!,
                      style: const TextStyle(color: HubColors.textoPrincipal, fontSize: 11, fontFamily: 'monospace')),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar', style: TextStyle(color: HubColors.pomelo)),
        ),
      ],
    );
  }

  static Widget _row(String label, String value, {bool mono = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: HubColors.textoSecundario, fontSize: 11)),
          SelectableText(value,
              style: TextStyle(
                  color: HubColors.textoPrincipal,
                  fontSize: mono ? 11 : 13,
                  fontFamily: mono ? 'monospace' : null)),
        ],
      ),
    );
  }
}
