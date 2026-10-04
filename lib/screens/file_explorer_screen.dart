import 'dart:io' show File;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/hub_colors.dart';
import '../core/logger.dart';
import '../services/device_files_service.dart';
import '../ui/widgets/gradient_pill_button.dart';

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
  final List<String> _favorites = []; // paths
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
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_favKey) ?? [];
      if (mounted) setState(() => _favorites.addAll(list));
    } catch (_) {}
  }

  Future<void> _saveFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_favKey, _favorites);
    } catch (_) {}
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

  Future<void> _requestPermission() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HubColors.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Acceso a archivos',
            style: TextStyle(color: HubColors.textoPrincipal)),
        content: const Text(
          'Para explorar y gestionar archivos del dispositivo, Anythings Hub necesita el permiso de "Acceso a todos los archivos". Te llevaré a Ajustes; actívalo y vuelve aquí.',
          style: TextStyle(color: HubColors.textoSecundario, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: HubColors.textoSecundario)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: HubColors.pomelo),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Abrir Ajustes',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (go == true) {
      _awaitingPermission = true;
      await DeviceFilesService.openPermissionSettings();
    }
  }

  Future<void> _navigateTo(String path) async {
    setState(() {
      _loading = true;
      _selected.clear();
      _selectionMode = false;
      _searchQuery = '';
      _searchCtrl.clear();
      _searching = false;
    });
    final list = await DeviceFilesService.listDirectory(
      path,
      showHidden: _showHidden,
    );
    final info = await DeviceFilesService.getStorageInfo(path);
    if (!mounted) return;
    if (list == null) {
      _toast('No se pudo leer la carpeta');
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

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchCtrl.text.trim().toLowerCase();
      _applyFilterAndSort();
    });
  }

  void _applyFilterAndSort() {
    var list = List<FileEntry>.from(_entries);
    if (_searchQuery.isNotEmpty) {
      list = list
          .where((e) => e.name.toLowerCase().contains(_searchQuery))
          .toList();
    }
    list = list.where((e) => e.matchesType(_filter)).toList();
    list.sort((a, b) {
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
    });
    _filtered = list;
  }

  List<String> get _breadcrumbs {
    if (_currentPath.isEmpty) return [];
    final parts = _currentPath.split('/').where((p) => p.isNotEmpty).toList();
    final crumbs = <String>[];
    var acc = '';
    for (final p in parts) {
      acc += '/$p';
      crumbs.add(acc);
    }
    return crumbs;
  }

  bool get _isFavorite => _favorites.contains(_currentPath);

  void _toast(String msg, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: HubColors.panel,
          action: action,
          content: Text(msg,
              style: const TextStyle(color: HubColors.textoPrincipal)),
        ),
      );
  }

  // ─── Acciones de creación ───────────────────────────────────────────────
  Future<void> _createFolder() async {
    final name = await _promptName('Nueva carpeta', 'Nombre de la carpeta');
    if (name == null || name.isEmpty) return;
    final full = '$_currentPath/$name';
    final ok = await DeviceFilesService.createDirectory(full);
    if (ok) {
      _toast('Carpeta creada');
      await _navigateTo(_currentPath);
    } else {
      _toast('No se pudo crear la carpeta');
    }
  }

  Future<void> _createFile() async {
    final name = await _promptName('Nuevo archivo', 'nombre.txt');
    if (name == null || name.isEmpty) return;
    final full = '$_currentPath/$name';
    final ok = await DeviceFilesService.createFile(full);
    if (ok) {
      _toast('Archivo creado');
      await _navigateTo(_currentPath);
    } else {
      _toast('No se pudo crear el archivo');
    }
  }

  Future<String?> _promptName(String title, String hint, {String initial = ''}) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HubColors.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(color: HubColors.textoPrincipal)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: HubColors.textoPrincipal),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: HubColors.textoSecundario),
            enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: HubColors.linea)),
            focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: HubColors.pomelo)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar',
                style: TextStyle(color: HubColors.textoSecundario)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: HubColors.pomelo),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Aceptar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ─── Renombrar / Eliminar ───────────────────────────────────────────────
  Future<void> _rename(FileEntry entry) async {
    final newName =
        await _promptName('Renombrar', entry.name, initial: entry.name);
    if (newName == null || newName.isEmpty || newName == entry.name) return;
    final ok = await DeviceFilesService.renameEntry(entry.path, newName);
    if (ok) {
      _toast('Renombrado');
      await _navigateTo(_currentPath);
    } else {
      _toast('No se pudo renombrar');
    }
  }

  Future<void> _deleteEntries(List<FileEntry> entries) async {
    if (entries.isEmpty) return;
    final label = entries.length == 1
        ? '"${entries.first.name}"'
        : '${entries.length} elementos';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HubColors.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Eliminar $label?',
            style: const TextStyle(color: HubColors.textoPrincipal)),
        content: Text(
          entries.any((e) => e.isDirectory)
              ? 'Se eliminarán carpetas y todo su contenido. Esta acción no se puede deshacer.'
              : 'Esta acción no se puede deshacer.',
          style: const TextStyle(color: HubColors.textoSecundario, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: HubColors.textoSecundario)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    var failed = 0;
    for (final e in entries) {
      final success = await DeviceFilesService.deleteEntry(e.path);
      if (!success) failed++;
    }
    if (failed == 0) {
      _toast('Eliminado');
    } else {
      _toast('$failed elemento(s) no se pudieron eliminar');
    }
    setState(() {
      _selected.clear();
      _selectionMode = false;
    });
    await _navigateTo(_currentPath);
  }

  // ─── Portapapeles ───────────────────────────────────────────────────────
  void _copySelected({required bool cut}) {
    final items = _entries.where((e) => _selected.contains(e.path)).toList();
    if (items.isEmpty) return;
    setState(() {
      _clipboard = _ClipboardItem(items, cut ? _ClipMode.cut : _ClipMode.copy);
      _selectionMode = false;
      _selected.clear();
    });
    _toast(cut
        ? '${items.length} recortado(s)'
        : '${items.length} copiado(s)');
  }

  Future<void> _paste() async {
    final clip = _clipboard;
    if (clip == null || clip.entries.isEmpty) return;
    setState(() => _loading = true);
    var failed = 0;
    for (final e in clip.entries) {
      final dest = '$_currentPath/${e.name}';
      final ok = clip.mode == _ClipMode.cut
          ? await DeviceFilesService.moveEntry(e.path, dest)
          : await DeviceFilesService.copyEntry(e.path, dest);
      if (!ok) failed++;
    }
    if (clip.mode == _ClipMode.cut) {
      setState(() => _clipboard = null);
    }
    if (failed == 0) {
      _toast(clip.mode == _ClipMode.cut ? 'Movido' : 'Copiado');
    } else {
      _toast('$failed operación(es) fallaron');
    }
    await _navigateTo(_currentPath);
  }

  // ─── Favoritos ──────────────────────────────────────────────────────────
  void _toggleFavorite() {
    setState(() {
      if (_isFavorite) {
        _favorites.remove(_currentPath);
        _toast('Eliminado de favoritos');
      } else {
        _favorites.add(_currentPath);
        _toast('Añadido a favoritos');
      }
    });
    _saveFavorites();
  }

  void _showFavorites() {
    if (_favorites.isEmpty) {
      _toast('No tienes carpetas favoritas');
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: HubColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: HubColors.linea,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Favoritos',
                  style: TextStyle(
                      color: HubColors.textoPrincipal,
                      fontWeight: FontWeight.w600,
                      fontSize: 16)),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _favorites.length,
                itemBuilder: (_, i) {
                  final path = _favorites[i];
                  final name = path.split('/').last;
                  return ListTile(
                    leading: const Icon(Icons.folder_special_rounded,
                        color: HubColors.amarillo),
                    title: Text(name,
                        style: const TextStyle(color: HubColors.textoPrincipal)),
                    subtitle: Text(path,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: HubColors.textoSecundario, fontSize: 11)),
                    trailing: IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: HubColors.textoSecundario, size: 18),
                      onPressed: () {
                        setState(() => _favorites.remove(path));
                        _saveFavorites();
                        Navigator.pop(ctx);
                        _showFavorites();
                      },
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _navigateTo(path);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ─── Ir a ruta ──────────────────────────────────────────────────────────
  Future<void> _goToPath() async {
    final path = await _promptName('Ir a ruta', '/storage/emulated/0',
        initial: _currentPath);
    if (path == null || path.isEmpty) return;
    await _navigateTo(path);
  }

  // ─── Menú contextual ────────────────────────────────────────────────────
  void _showContextMenu(FileEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: HubColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: HubColors.linea,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: HubColors.textoPrincipal,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (!entry.isDirectory)
                _sheetTile(Icons.open_in_new_rounded, 'Abrir', HubColors.pomelo,
                    () async {
                  Navigator.pop(ctx);
                  final ok = await DeviceFilesService.openFile(entry.path);
                  if (!ok && mounted) _toast('No se pudo abrir el archivo');
                }),
              if (!entry.isDirectory)
                _sheetTile(Icons.share_rounded, 'Compartir', HubColors.textoAcento,
                    () async {
                  Navigator.pop(ctx);
                  final ok = await DeviceFilesService.shareFile(entry.path);
                  if (!ok && mounted) _toast('No se pudo compartir');
                }),
              _sheetTile(Icons.drive_file_rename_outline_rounded, 'Renombrar',
                  HubColors.amarillo, () {
                Navigator.pop(ctx);
                _rename(entry);
              }),
              _sheetTile(Icons.content_copy_rounded, 'Copiar',
                  HubColors.textoSecundario, () {
                Navigator.pop(ctx);
                setState(() {
                  _selected
                    ..clear()
                    ..add(entry.path);
                  _copySelected(cut: false);
                });
              }),
              _sheetTile(Icons.content_cut_rounded, 'Cortar',
                  HubColors.textoSecundario, () {
                Navigator.pop(ctx);
                setState(() {
                  _selected
                    ..clear()
                    ..add(entry.path);
                  _copySelected(cut: true);
                });
              }),
              _sheetTile(Icons.delete_outline_rounded, 'Eliminar', Colors.redAccent,
                  () {
                Navigator.pop(ctx);
                _deleteEntries([entry]);
              }),
              _sheetTile(Icons.info_outline_rounded, 'Detalles',
                  HubColors.textoAcento, () {
                Navigator.pop(ctx);
                _showDetails(entry);
              }),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetTile(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: const TextStyle(color: HubColors.textoPrincipal)),
      onTap: onTap,
    );
  }

  void _showDetails(FileEntry entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HubColors.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(entry.name,
            style: const TextStyle(
                color: HubColors.textoPrincipal, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow(
                'Tipo',
                entry.isDirectory
                    ? 'Carpeta'
                    : (entry.extension.isEmpty
                        ? 'Archivo'
                        : entry.extension.toUpperCase())),
            _detailRow('Ruta', entry.path),
            if (!entry.isDirectory) _detailRow('Tamaño', entry.sizeLabel),
            _detailRow('Modificado', _formatDate(entry.modified)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Cerrar', style: TextStyle(color: HubColors.pomelo)),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(color: HubColors.textoSecundario, fontSize: 11)),
          const SizedBox(height: 2),
          Text(value,
              style:
                  const TextStyle(color: HubColors.textoPrincipal, fontSize: 13)),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  IconData _iconFor(FileEntry e) {
    if (e.isDirectory) return Icons.folder_rounded;
    final ext = e.extension.toLowerCase();
    if (const {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic', 'svg'}
        .contains(ext)) {
      return Icons.image_rounded;
    }
    if (const {'mp4', 'mkv', 'avi', 'mov', 'webm', '3gp'}.contains(ext)) {
      return Icons.movie_rounded;
    }
    if (const {'mp3', 'wav', 'flac', 'aac', 'ogg', 'm4a'}.contains(ext)) {
      return Icons.audiotrack_rounded;
    }
    if (ext == 'pdf') return Icons.picture_as_pdf_rounded;
    if (const {'doc', 'docx', 'txt', 'md', 'rtf'}.contains(ext)) {
      return Icons.description_rounded;
    }
    if (const {'xls', 'xlsx', 'csv'}.contains(ext)) {
      return Icons.table_chart_rounded;
    }
    if (const {'zip', 'rar', '7z', 'tar', 'gz'}.contains(ext)) {
      return Icons.folder_zip_rounded;
    }
    if (ext == 'apk') return Icons.android_rounded;
    return Icons.insert_drive_file_rounded;
  }

  Color _iconColor(FileEntry e) {
    if (e.isDirectory) return HubColors.amarillo;
    final ext = e.extension.toLowerCase();
    if (const {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic'}
        .contains(ext)) {
      return const Color(0xFF5B8DEF);
    }
    if (const {'mp4', 'mkv', 'avi', 'mov', 'webm'}.contains(ext)) {
      return const Color(0xFFE85D75);
    }
    if (const {'mp3', 'wav', 'flac', 'aac', 'ogg', 'm4a'}.contains(ext)) {
      return const Color(0xFF7C80C6);
    }
    if (ext == 'pdf') return Colors.redAccent;
    if (const {'zip', 'rar', '7z', 'tar', 'gz'}.contains(ext)) {
      return HubColors.pomelo;
    }
    if (ext == 'apk') return const Color(0xFF3DDC84);
    return HubColors.textoSecundario;
  }

  // ─── Menú + (crear) ─────────────────────────────────────────────────────
  void _showCreateMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: HubColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: HubColors.linea,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            _sheetTile(Icons.create_new_folder_rounded, 'Nueva carpeta',
                HubColors.amarillo, () {
              Navigator.pop(ctx);
              _createFolder();
            }),
            _sheetTile(Icons.note_add_rounded, 'Nuevo archivo de texto',
                HubColors.pomelo, () {
              Navigator.pop(ctx);
              _createFile();
            }),
            if (_clipboard != null)
              _sheetTile(Icons.paste_rounded, 'Pegar aquí', HubColors.textoAcento,
                  () {
                Navigator.pop(ctx);
                _paste();
              }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ─── Barra de selección ─────────────────────────────────────────────────
  Widget _buildSelectionBar() {
    return Container(
      color: HubColors.fondoSidebar,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Cancelar',
            onPressed: () => setState(() {
              _selectionMode = false;
              _selected.clear();
            }),
            icon: const Icon(Icons.close_rounded,
                color: HubColors.textoSecundario),
          ),
          Expanded(
            child: Text(
              '${_selected.length} seleccionado(s)',
              style: const TextStyle(
                  color: HubColors.textoPrincipal, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            tooltip: 'Seleccionar todo',
            onPressed: () => setState(() {
              if (_selected.length == _filtered.length) {
                _selected.clear();
              } else {
                _selected
                  ..clear()
                  ..addAll(_filtered.map((e) => e.path));
              }
            }),
            icon: Icon(
              _selected.length == _filtered.length
                  ? Icons.deselect_rounded
                  : Icons.select_all_rounded,
              color: HubColors.textoSecundario,
            ),
          ),
          IconButton(
            tooltip: 'Copiar',
            onPressed: () => _copySelected(cut: false),
            icon: const Icon(Icons.content_copy_rounded,
                color: HubColors.textoSecundario),
          ),
          IconButton(
            tooltip: 'Cortar',
            onPressed: () => _copySelected(cut: true),
            icon: const Icon(Icons.content_cut_rounded,
                color: HubColors.textoSecundario),
          ),
          IconButton(
            tooltip: 'Eliminar',
            onPressed: () {
              final items =
                  _entries.where((e) => _selected.contains(e.path)).toList();
              _deleteEntries(items);
            },
            icon: const Icon(Icons.delete_outline_rounded,
                color: Colors.redAccent),
          ),
        ],
      ),
    );
  }

  // ─── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HubColors.fondoPrincipal,
      body: SafeArea(
        child: Column(
          children: [
            if (_selectionMode) _buildSelectionBar() else _buildHeader(),
            if (_currentPath.isNotEmpty && !_searching && !_selectionMode)
              _buildBreadcrumbs(),
            if (_storageInfo != null && !_searching && !_selectionMode)
              _buildStorageBar(),
            if (!_selectionMode) _buildFilterChips(),
            Divider(height: 1, color: HubColors.linea.withOpacity(0.6)),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      floatingActionButton: _hasPermission && !_loading && !_selectionMode
          ? FloatingActionButton(
              onPressed: _showCreateMenu,
              backgroundColor: HubColors.pomelo,
              child: const Icon(Icons.add_rounded, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: SizedBox(
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: 'Volver',
                onPressed: () {
                  if (_searching) {
                    setState(() {
                      _searching = false;
                      _searchCtrl.clear();
                      _searchQuery = '';
                      _applyFilterAndSort();
                    });
                  } else if (_breadcrumbs.length > 1) {
                    _navigateTo(_breadcrumbs[_breadcrumbs.length - 2]);
                  } else {
                    Navigator.of(context).maybePop();
                  }
                },
                icon: Icon(
                  _searching
                      ? Icons.close_rounded
                      : Icons.arrow_back_ios_new_rounded,
                  color: HubColors.textoSecundario,
                  size: 20,
                ),
              ),
            ),
            if (!_searching)
              const Text(
                'Explorador',
                style: TextStyle(
                  color: HubColors.textoPrincipal,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(left: 48, right: 8),
                child: TextField(
                  controller: _searchCtrl,
                  focusNode: _searchFocus,
                  autofocus: true,
                  style: const TextStyle(
                      color: HubColors.textoPrincipal, fontSize: 16),
                  decoration: const InputDecoration(
                    hintText: 'Buscar archivos...',
                    hintStyle: TextStyle(color: HubColors.textoSecundario),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            if (!_searching)
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Buscar',
                      onPressed: () {
                        setState(() => _searching = true);
                        _searchFocus.requestFocus();
                      },
                      icon: const Icon(Icons.search_rounded,
                          color: HubColors.pomelo, size: 22),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Más opciones',
                      icon: const Icon(Icons.more_vert_rounded,
                          color: HubColors.textoSecundario, size: 22),
                      color: HubColors.panel,
                      onSelected: (v) {
                        switch (v) {
                          case 'sort':
                            _showSortMenu();
                            break;
                          case 'view':
                            setState(() => _view = _view == _ViewMode.list
                                ? _ViewMode.grid
                                : _ViewMode.list);
                            break;
                          case 'hidden':
                            setState(() => _showHidden = !_showHidden);
                            _navigateTo(_currentPath);
                            break;
                          case 'fav':
                            _toggleFavorite();
                            break;
                          case 'favs':
                            _showFavorites();
                            break;
                          case 'goto':
                            _goToPath();
                            break;
                          case 'refresh':
                            _navigateTo(_currentPath);
                            break;
                          case 'select':
                            setState(() => _selectionMode = true);
                            break;
                          case 'paste':
                            _paste();
                            break;
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'sort',
                          child: _menuRow(Icons.sort_rounded, 'Ordenar'),
                        ),
                        PopupMenuItem(
                          value: 'view',
                          child: _menuRow(
                            _view == _ViewMode.list
                                ? Icons.grid_view_rounded
                                : Icons.view_list_rounded,
                            _view == _ViewMode.list
                                ? 'Vista cuadrícula'
                                : 'Vista lista',
                          ),
                        ),
                        PopupMenuItem(
                          value: 'select',
                          child: _menuRow(
                              Icons.checklist_rounded, 'Seleccionar'),
                        ),
                        if (_clipboard != null)
                          PopupMenuItem(
                            value: 'paste',
                            child: _menuRow(Icons.paste_rounded, 'Pegar aquí'),
                          ),
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'hidden',
                          child: _menuRow(
                            _showHidden
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            _showHidden
                                ? 'Ocultar ocultos'
                                : 'Mostrar ocultos',
                          ),
                        ),
                        PopupMenuItem(
                          value: 'fav',
                          child: _menuRow(
                            _isFavorite
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            _isFavorite
                                ? 'Quitar de favoritos'
                                : 'Añadir a favoritos',
                          ),
                        ),
                        PopupMenuItem(
                          value: 'favs',
                          child: _menuRow(
                              Icons.folder_special_rounded, 'Ver favoritos'),
                        ),
                        PopupMenuItem(
                          value: 'goto',
                          child: _menuRow(
                              Icons.drive_file_move_rounded, 'Ir a ruta…'),
                        ),
                        PopupMenuItem(
                          value: 'refresh',
                          child: _menuRow(Icons.refresh_rounded, 'Actualizar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _menuRow(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 20, color: HubColors.textoSecundario),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: HubColors.textoPrincipal)),
      ],
    );
  }

  void _showSortMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: HubColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: HubColors.linea,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Ordenar por',
                  style: TextStyle(
                      color: HubColors.textoPrincipal,
                      fontWeight: FontWeight.w600)),
            ),
            for (final e in [
              (_SortMode.nameAsc, 'Nombre A-Z'),
              (_SortMode.nameDesc, 'Nombre Z-A'),
              (_SortMode.dateNewest, 'Más reciente'),
              (_SortMode.dateOldest, 'Más antiguo'),
              (_SortMode.sizeLargest, 'Más grande'),
              (_SortMode.sizeSmallest, 'Más pequeño'),
            ])
              ListTile(
                title: Text(e.$2,
                    style: TextStyle(
                      color: _sort == e.$1
                          ? HubColors.pomelo
                          : HubColors.textoPrincipal,
                      fontWeight:
                          _sort == e.$1 ? FontWeight.w600 : FontWeight.normal,
                    )),
                trailing: _sort == e.$1
                    ? const Icon(Icons.check_rounded, color: HubColors.pomelo)
                    : null,
                onTap: () {
                  setState(() {
                    _sort = e.$1;
                    _applyFilterAndSort();
                  });
                  Navigator.pop(ctx);
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildBreadcrumbs() {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          GestureDetector(
            onTap: () {
              if (_roots.isNotEmpty) _navigateTo(_roots.first['path']!);
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Icon(Icons.home_rounded, size: 18, color: HubColors.pomelo),
            ),
          ),
          for (var i = 0; i < _breadcrumbs.length; i++) ...[
            const Icon(Icons.chevron_right_rounded,
                size: 16, color: HubColors.textoSecundario),
            GestureDetector(
              onTap: () => _navigateTo(_breadcrumbs[i]),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Text(
                  _breadcrumbs[i].split('/').last,
                  style: TextStyle(
                    color: i == _breadcrumbs.length - 1
                        ? HubColors.textoPrincipal
                        : HubColors.textoSecundario,
                    fontSize: 13,
                    fontWeight: i == _breadcrumbs.length - 1
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStorageBar() {
    final info = _storageInfo!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: info.usedRatio.clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: HubColors.linea.withOpacity(0.4),
              valueColor: AlwaysStoppedAnimation(
                info.usedRatio > 0.9 ? Colors.redAccent : HubColors.pomelo,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${info.usedLabel} usados de ${info.totalLabel} · ${info.freeLabel} libres',
            style: const TextStyle(
                color: HubColors.textoSecundario, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    const chips = [
      (FileFilter.all, 'Todo'),
      (FileFilter.folders, 'Carpetas'),
      (FileFilter.images, 'Imágenes'),
      (FileFilter.videos, 'Vídeos'),
      (FileFilter.audio, 'Audio'),
      (FileFilter.documents, 'Docs'),
      (FileFilter.archives, 'Zips'),
      (FileFilter.apks, 'APKs'),
    ];
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (final c in chips)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: Text(c.$2, style: const TextStyle(fontSize: 12)),
                selected: _filter == c.$1,
                onSelected: (_) => setState(() {
                  _filter = c.$1;
                  _applyFilterAndSort();
                }),
                selectedColor: HubColors.pomelo.withOpacity(0.25),
                checkmarkColor: HubColors.pomelo,
                labelStyle: TextStyle(
                  color: _filter == c.$1
                      ? HubColors.pomelo
                      : HubColors.textoSecundario,
                  fontWeight:
                      _filter == c.$1 ? FontWeight.w600 : FontWeight.normal,
                ),
                backgroundColor: HubColors.panel,
                side: BorderSide(
                  color: _filter == c.$1
                      ? HubColors.pomelo.withOpacity(0.6)
                      : HubColors.linea.withOpacity(0.5),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (!_hasPermission) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.folder_off_rounded,
                  size: 48, color: HubColors.textoSecundario),
              const SizedBox(height: 16),
              const Text(
                'Se necesita permiso de almacenamiento',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: HubColors.textoPrincipal,
                    fontSize: 16,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Concede acceso a todos los archivos para explorar, crear carpetas y gestionar tus documentos.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: HubColors.textoSecundario, fontSize: 13),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 220,
                child: GradientPillButton(
                  label: 'Conceder permiso',
                  icon: Icons.lock_open_rounded,
                  onPressed: _requestPermission,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _bootstrap,
                child: const Text('Ya lo activé, reintentar',
                    style: TextStyle(color: HubColors.textoAcento)),
              ),
            ],
          ),
        ),
      );
    }

    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
              strokeWidth: 2.2, color: HubColors.pomelo),
        ),
      );
    }

    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _searchQuery.isNotEmpty || _filter != FileFilter.all
                  ? Icons.search_off_rounded
                  : Icons.folder_open_rounded,
              size: 44,
              color: HubColors.textoSecundario,
            ),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Sin resultados para "$_searchQuery"'
                  : (_filter != FileFilter.all
                      ? 'Nada en este filtro'
                      : 'Carpeta vacía'),
              style: const TextStyle(
                  color: HubColors.textoPrincipal,
                  fontSize: 15,
                  fontWeight: FontWeight.w600),
            ),
            if (_searchQuery.isEmpty && _filter == FileFilter.all) ...[
              const SizedBox(height: 6),
              const Text(
                'Toca + para crear una carpeta o archivo',
                style:
                    TextStyle(color: HubColors.textoSecundario, fontSize: 13),
              ),
            ],
          ],
        ),
      );
    }

    if (_view == _ViewMode.grid) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 80),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.85,
        ),
        itemCount: _filtered.length,
        itemBuilder: (ctx, i) {
          final e = _filtered[i];
          final selected = _selected.contains(e.path);
          return GestureDetector(
            onTap: () {
              if (_selectionMode) {
                setState(() {
                  if (selected) {
                    _selected.remove(e.path);
                    if (_selected.isEmpty) _selectionMode = false;
                  } else {
                    _selected.add(e.path);
                  }
                });
              } else if (e.isDirectory) {
                _navigateTo(e.path);
              } else {
                DeviceFilesService.openFile(e.path);
              }
            },
            onLongPress: () {
              if (!_selectionMode) {
                setState(() {
                  _selectionMode = true;
                  _selected.add(e.path);
                });
              } else {
                _showContextMenu(e);
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: selected
                    ? HubColors.pomelo.withOpacity(0.15)
                    : HubColors.panel,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? HubColors.pomelo.withOpacity(0.7)
                      : HubColors.linea.withOpacity(0.5),
                ),
              ),
              child: Stack(
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_iconFor(e), size: 36, color: _iconColor(e)),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          e.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: HubColors.textoPrincipal, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  if (selected)
                    const Positioned(
                      top: 6,
                      right: 6,
                      child: Icon(Icons.check_circle_rounded,
                          color: HubColors.pomelo, size: 20),
                    ),
                ],
              ),
            ),
          );
        },
      );
    }

    // List view
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 80),
      itemCount: _filtered.length,
      itemBuilder: (ctx, i) {
        final e = _filtered[i];
        final selected = _selected.contains(e.path);
        return Material(
          color: selected
              ? HubColors.pomelo.withOpacity(0.08)
              : Colors.transparent,
          child: InkWell(
            onTap: () {
              if (_selectionMode) {
                setState(() {
                  if (selected) {
                    _selected.remove(e.path);
                    if (_selected.isEmpty) _selectionMode = false;
                  } else {
                    _selected.add(e.path);
                  }
                });
              } else if (e.isDirectory) {
                _navigateTo(e.path);
              } else {
                DeviceFilesService.openFile(e.path);
              }
            },
            onLongPress: () {
              if (!_selectionMode) {
                setState(() {
                  _selectionMode = true;
                  _selected.add(e.path);
                });
              } else {
                _showContextMenu(e);
              }
            },
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  if (_selectionMode) ...[
                    Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      color: selected
                          ? HubColors.pomelo
                          : HubColors.textoSecundario,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                  ],
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _iconColor(e).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child:
                        Icon(_iconFor(e), size: 24, color: _iconColor(e)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: HubColors.textoPrincipal,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          e.isDirectory
                              ? _formatDate(e.modified)
                              : '${e.sizeLabel}  ·  ${_formatDate(e.modified)}',
                          style: const TextStyle(
                              color: HubColors.textoSecundario,
                              fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  if (!_selectionMode && e.isDirectory)
                    const Icon(Icons.chevron_right_rounded,
                        color: HubColors.textoSecundario, size: 20),
                  if (!_selectionMode && !e.isDirectory)
                    IconButton(
                      icon: const Icon(Icons.more_vert_rounded,
                          color: HubColors.textoSecundario, size: 18),
                      onPressed: () => _showContextMenu(e),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
