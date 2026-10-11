import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/hub_colors.dart';
import '../core/logger.dart';
import '../services/device_files_service.dart';
import '../services/device_apps_service.dart';
import '../services/file_preview_service.dart';
import '../ui/widgets/gradient_pill_button.dart';
import 'file_explorer_widgets.dart';

enum _SortMode { nameAsc, nameDesc, dateNewest, dateOldest, sizeLargest, sizeSmallest }
enum _ViewMode { list, grid }
enum _ClipMode { none, copy, cut }

class _ClipboardItem {
  const _ClipboardItem(this.entries, this.mode);
  final List<FileEntry> entries;
  final _ClipMode mode;
}

class FileExplorerScreen extends StatefulWidget {
  const FileExplorerScreen({super.key, this.initialPath});

  /// Si se pasa, el explorador abre en esta ruta (p. ej. desde Favoritos).
  final String? initialPath;

  @override
  State<FileExplorerScreen> createState() => _FileExplorerScreenState();
}

class _FileExplorerScreenState extends State<FileExplorerScreen>
    with WidgetsBindingObserver {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  List<Map<String, String>> _roots = [];
  String _currentPath = '';
  List<FileEntry> _entries = [];
  List<FileEntry> _filtered = [];
  bool _loading = true;
  bool _hasPermission = false;
  bool _searching = false;
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
    _loadFavorites();
    _bootstrap();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingPermission) {
      _awaitingPermission = false;
      _bootstrap();
    }
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_favKey) ?? [];
    if (mounted) setState(() {
      _favorites..clear()..addAll(list);
    });
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favKey, _favorites);
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    _hasPermission = await DeviceFilesService.hasPermission();
    if (!_hasPermission) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    _roots = await DeviceFilesService.getRoots();
    final initial = widget.initialPath;
    if (initial != null && initial.isNotEmpty) {
      await _navigateTo(initial);
    } else if (_roots.isNotEmpty) {
      await _navigateTo(_roots.first['path']!);
    } else if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _requestPermission() async {
    _awaitingPermission = true;
    await DeviceFilesService.openPermissionSettings();
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
      _toast('No se pudo listar el directorio');
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

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchCtrl.text.trim().toLowerCase();
      _applyFilterAndSort();
    });
  }

  void _applyFilterAndSort() {
    var list = List<FileEntry>.from(_entries);
    if (_searchQuery.isNotEmpty) {
      list = list.where((e) => e.name.toLowerCase().contains(_searchQuery)).toList();
    }
    list = list.where((e) => e.matchesType(_filter)).toList();
    int cmp(FileEntry a, FileEntry b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      switch (_sort) {
        case _SortMode.nameAsc:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case _SortMode.nameDesc:
          return b.name.toLowerCase().compareTo(a.name.toLowerCase());
        case _SortMode.dateNewest:
          return b.modifiedMs.compareTo(a.modifiedMs);
        case _SortMode.dateOldest:
          return a.modifiedMs.compareTo(b.modifiedMs);
        case _SortMode.sizeLargest:
          return b.size.compareTo(a.size);
        case _SortMode.sizeSmallest:
          return a.size.compareTo(b.size);
      }
    }
    list.sort(cmp);
    _filtered = list;
  }

  void _toast(String msg, {SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), action: action, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 3)),
    );
  }

  Future<void> _createFolder() async {
    final name = await _promptName('Nueva carpeta', 'Nombre de la carpeta');
    if (name == null || name.isEmpty) return;
    final ok = await DeviceFilesService.createDirectory('$_currentPath/$name');
    if (ok) { _toast('Carpeta creada'); await _navigateTo(_currentPath); }
    else { _toast('No se pudo crear la carpeta'); }
  }

  Future<void> _createFile() async {
    final name = await _promptName('Nuevo archivo', 'Nombre del archivo');
    if (name == null || name.isEmpty) return;
    final ok = await DeviceFilesService.createFile('$_currentPath/$name');
    if (ok) { _toast('Archivo creado'); await _navigateTo(_currentPath); }
    else { _toast('No se pudo crear el archivo'); }
  }

  Future<String?> _promptName(String title, String hint, {String initial = ''}) async {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HubColors.panel,
        title: Text(title, style: TextStyle(color: HubColors.textoPrincipal)),
        content: TextField(
          controller: ctrl, autofocus: true,
          style: TextStyle(color: HubColors.textoPrincipal),
          decoration: InputDecoration(
            hintText: hint, hintStyle: TextStyle(color: HubColors.textoSecundario),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: HubColors.linea)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: HubColors.pomelo)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancelar', style: TextStyle(color: HubColors.textoSecundario))),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: Text('Aceptar', style: TextStyle(color: HubColors.pomelo))),
        ],
      ),
    );
  }

  Future<void> _rename(FileEntry entry) async {
    final name = await _promptName('Renombrar', 'Nuevo nombre', initial: entry.name);
    if (name == null || name.isEmpty || name == entry.name) return;
    final ok = await DeviceFilesService.renameEntry(entry.path, name);
    if (ok) { _toast('Renombrado'); await _navigateTo(_currentPath); }
    else { _toast('No se pudo renombrar'); }
  }

  Future<void> _deleteEntries(List<FileEntry> entries) async {
    if (entries.isEmpty) return;
    final limitMsg = FileOpGuard.checkBatch(entries.length, op: 'eliminación');
    if (limitMsg != null) {
      _toast(limitMsg);
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HubColors.panel,
        title: Text('Eliminar', style: TextStyle(color: HubColors.textoPrincipal)),
        content: Text(
          entries.length == 1 ? '¿Eliminar "${entries.first.name}"?' : '¿Eliminar ${entries.length} elementos?',
          style: TextStyle(color: HubColors.textoSecundario),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancelar', style: TextStyle(color: HubColors.textoSecundario))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirm != true) return;
    var okCount = 0;
    for (final e in entries) {
      if (await DeviceFilesService.deleteEntry(e.path)) okCount++;
    }
    FileOpGuard.record(entries.length);
    _toast(okCount == entries.length ? 'Eliminado' : 'Eliminados $okCount de ${entries.length}');
    setState(() { _selected.clear(); _selectionMode = false; });
    await _navigateTo(_currentPath);
  }

  void _copySelected({required bool cut}) {
    final entries = _entries.where((e) => _selected.contains(e.path)).toList();
    if (entries.isEmpty) return;
    final limitMsg = FileOpGuard.checkBatch(entries.length, op: cut ? 'corte' : 'copia');
    if (limitMsg != null) {
      _toast(limitMsg);
      return;
    }
    setState(() {
      _clipboard = _ClipboardItem(entries, cut ? _ClipMode.cut : _ClipMode.copy);
      _selectionMode = false;
      _selected.clear();
    });
    _toast(cut ? 'Cortado (${entries.length})' : 'Copiado (${entries.length})');
  }

  Future<void> _paste() async {
    final clip = _clipboard;
    if (clip == null || clip.entries.isEmpty) return;
    final limitMsg = FileOpGuard.checkBatch(clip.entries.length, op: 'pegado');
    if (limitMsg != null) {
      _toast(limitMsg);
      return;
    }
    var okCount = 0;
    for (final e in clip.entries) {
      final dest = '$_currentPath/${e.name}';
      final ok = clip.mode == _ClipMode.cut
          ? await DeviceFilesService.moveEntry(e.path, dest)
          : await DeviceFilesService.copyEntry(e.path, dest);
      if (ok) okCount++;
    }
    FileOpGuard.record(clip.entries.length);
    if (clip.mode == _ClipMode.cut) setState(() => _clipboard = null);
    _toast('Pegados $okCount de ${clip.entries.length}');
    await _navigateTo(_currentPath);
  }

  void _toggleFavorite() {
    final adding = !_favorites.contains(_currentPath);
    if (adding) {
      _favorites.add(_currentPath);
      _toast('Añadido a favoritos');
    } else {
      _favorites.remove(_currentPath);
      _toast('Quitado de favoritos');
    }
    _saveFavorites();
    _touchFavoriteMeta('file:$_currentPath', adding);
    setState(() {});
  }

  Future<void> _touchFavoriteMeta(String key, bool add) async {
    const metaKey = 'favorites_meta_v1';
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(metaKey);
      final meta = <String, dynamic>{};
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          decoded.forEach((k, v) => meta[k.toString()] = v);
        }
      }
      if (add) {
        meta[key] = DateTime.now().toIso8601String();
      } else {
        meta.remove(key);
      }
      await prefs.setString(metaKey, jsonEncode(meta));
    } catch (_) {}
  }

  void _showFavorites() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: HubColors.panel,
      builder: (ctx) {
        if (_favorites.isEmpty) {
          return SafeArea(child: Padding(padding: EdgeInsets.all(24), child: Text('Sin favoritos', style: TextStyle(color: HubColors.textoSecundario))));
        }
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(padding: EdgeInsets.all(16), child: Text('Favoritos', style: TextStyle(color: HubColors.textoPrincipal, fontWeight: FontWeight.w700))),
              ..._favorites.map((p) => ListTile(
                leading: Icon(Icons.star_rounded, color: HubColors.amarillo),
                title: Text(p.split('/').last.isEmpty ? p : p.split('/').last, style: TextStyle(color: HubColors.textoPrincipal)),
                subtitle: Text(p, style: TextStyle(color: HubColors.textoSecundario, fontSize: 11)),
                onTap: () { Navigator.pop(ctx); _navigateTo(p); },
                trailing: IconButton(
                  icon: Icon(Icons.close, size: 18, color: HubColors.textoSecundario),
                  onPressed: () { setState(() => _favorites.remove(p)); _saveFavorites(); Navigator.pop(ctx); _showFavorites(); },
                ),
              )),
            ],
          ),
        );
      },
    );
  }

  Future<void> _goToPath() async {
    final path = await _promptName('Ir a ruta', 'Ruta absoluta', initial: _currentPath);
    if (path == null || path.isEmpty) return;
    await _navigateTo(path);
  }

  void _showDetails(FileEntry entry) {
    showDialog(context: context, builder: (_) => FileDetailsDialog(entry: entry));
  }

  void _showContextMenu(FileEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: HubColors.panel,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: Icon(Icons.info_outline, color: HubColors.textoAcento), title: Text('Detalles', style: TextStyle(color: HubColors.textoPrincipal)), onTap: () { Navigator.pop(ctx); _showDetails(entry); }),
            ListTile(leading: Icon(Icons.drive_file_rename_outline, color: HubColors.textoAcento), title: Text('Renombrar', style: TextStyle(color: HubColors.textoPrincipal)), onTap: () { Navigator.pop(ctx); _rename(entry); }),
            ListTile(leading: Icon(Icons.copy_rounded, color: HubColors.textoAcento), title: Text('Copiar', style: TextStyle(color: HubColors.textoPrincipal)), onTap: () { Navigator.pop(ctx); setState(() { _selected..clear()..add(entry.path); }); _copySelected(cut: false); }),
            ListTile(leading: Icon(Icons.cut_rounded, color: HubColors.textoAcento), title: Text('Cortar', style: TextStyle(color: HubColors.textoPrincipal)), onTap: () { Navigator.pop(ctx); setState(() { _selected..clear()..add(entry.path); }); _copySelected(cut: true); }),
            ListTile(leading: const Icon(Icons.delete_outline, color: Colors.redAccent), title: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)), onTap: () { Navigator.pop(ctx); _deleteEntries([entry]); }),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showCreateMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: HubColors.panel,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: Icon(Icons.create_new_folder_rounded, color: HububColors.amarillo), title: Text('Nueva carpeta', style: TextStyle(color: HubColors.textoPrincipal)), onTap: () { Navigator.pop(ctx); _createFolder(); }),
            ListTile(leading: Icon(Icons.note_add_rounded, color: HubColors.textoAcento), title: Text('Nuevo archivo', style: TextStyle(color: HubColors.textoPrincipal)), onTap: () { Navigator.pop(ctx); _createFile(); }),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // NOTE: truncated for size - RESTORE FULL FROM LOCAL
  // This is incomplete - need full file
  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: HubColors.fondoPrincipal, body: Center(child: Text('File explorer loading...')));
  }
}
