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
    if (_roots.isNotEmpty) {
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
    if (_favorites.contains(_currentPath)) {
      _favorites.remove(_currentPath);
      _toast('Quitado de favoritos');
    } else {
      _favorites.add(_currentPath);
      _toast('Añadido a favoritos');
    }
    _saveFavorites();
    setState(() {});
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
            ListTile(leading: Icon(Icons.create_new_folder_rounded, color: HubColors.amarillo), title: Text('Nueva carpeta', style: TextStyle(color: HubColors.textoPrincipal)), onTap: () { Navigator.pop(ctx); _createFolder(); }),
            ListTile(leading: Icon(Icons.note_add_rounded, color: HubColors.textoAcento), title: Text('Nuevo archivo', style: TextStyle(color: HubColors.textoPrincipal)), onTap: () { Navigator.pop(ctx); _createFile(); }),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showSortMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: HubColors.panel,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final m in _SortMode.values)
              ListTile(
                title: Text(_sortLabel(m), style: TextStyle(color: _sort == m ? HubColors.pomelo : HubColors.textoPrincipal)),
                trailing: _sort == m ? Icon(Icons.check, color: HubColors.pomelo, size: 18) : null,
                onTap: () { Navigator.pop(ctx); setState(() { _sort = m; _applyFilterAndSort(); }); },
              ),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _sortLabel(_SortMode m) {
    switch (m) {
      case _SortMode.nameAsc: return 'Nombre A→Z';
      case _SortMode.nameDesc: return 'Nombre Z→A';
      case _SortMode.dateNewest: return 'Más recientes';
      case _SortMode.dateOldest: return 'Más antiguos';
      case _SortMode.sizeLargest: return 'Más grandes';
      case _SortMode.sizeSmallest: return 'Más pequeños';
    }
  }

  IconData _iconFor(FileEntry e) {
    if (e.isDirectory) return Icons.folder_rounded;
    final ext = e.extension.toLowerCase();
    if (const {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'}.contains(ext)) return Icons.image_rounded;
    if (ext == 'apk') return Icons.android_rounded;
    if (const {'txt', 'md', 'json', 'xml', 'html', 'css', 'js', 'dart'}.contains(ext)) return Icons.description_rounded;
    if (const {'mp4', 'mkv', 'avi', 'webm'}.contains(ext)) return Icons.movie_rounded;
    if (const {'mp3', 'wav', 'flac', 'ogg', 'm4a'}.contains(ext)) return Icons.audiotrack_rounded;
    return Icons.insert_drive_file_rounded;
  }

  Color _iconColor(FileEntry e) {
    if (e.isDirectory) return HubColors.amarillo;
    final ext = e.extension.toLowerCase();
    if (const {'jpg', 'jpeg', 'png', 'gif', 'webp'}.contains(ext)) return const Color(0xFF5B8DEF);
    if (ext == 'apk') return const Color(0xFF3DDC84);
    if (const {'mp4', 'mkv', 'avi'}.contains(ext)) return const Color(0xFFE85D75);
    return HubColors.textoSecundario;
  }

  Widget _buildBreadcrumb() {
    final parts = _currentPath.split('/').where((p) => p.isNotEmpty).toList();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          InkWell(onTap: () { if (_roots.isNotEmpty) _navigateTo(_roots.first['path']!); }, child: Icon(Icons.home_rounded, size: 18, color: HubColors.textoAcento)),
          for (var i = 0; i < parts.length; i++) ...[
            Icon(Icons.chevron_right, size: 16, color: HubColors.textoSecundario),
            InkWell(
              onTap: () { final path = '/' + parts.sublist(0, i + 1).join('/'); _navigateTo(path); },
              child: Text(parts[i], style: TextStyle(color: i == parts.length - 1 ? HubColors.textoPrincipal : HubColors.textoAcento, fontSize: 13, fontWeight: i == parts.length - 1 ? FontWeight.w600 : FontWeight.normal)),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasPermission) {
      return Scaffold(
        backgroundColor: HubColors.fondoPrincipal,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.folder_off_rounded, size: 64, color: HubColors.textoSecundario),
                SizedBox(height: 16),
                Text('Se necesita acceso a todos los archivos', textAlign: TextAlign.center, style: TextStyle(color: HubColors.textoPrincipal, fontSize: 16)),
                SizedBox(height: 20),
                GradientPillButton(label: 'Conceder acceso a archivos', icon: Icons.folder_open, onPressed: _requestPermission),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: HubColors.fondoPrincipal,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _selectionMode ? '${_selected.length} seleccionados' : (_currentPath.split('/').last.isEmpty ? 'Archivos' : _currentPath.split('/').last),
          style: TextStyle(color: HubColors.textoPrincipal, fontSize: 16),
        ),
        iconTheme: IconThemeData(color: HubColors.textoPrincipal),
        actions: [
          if (_selectionMode) ...[
            IconButton(icon: const Icon(Icons.copy_rounded), onPressed: () => _copySelected(cut: false), tooltip: 'Copiar'),
            IconButton(icon: const Icon(Icons.cut_rounded), onPressed: () => _copySelected(cut: true), tooltip: 'Cortar'),
            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _deleteEntries(_entries.where((e) => _selected.contains(e.path)).toList()), tooltip: 'Eliminar'),
            IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() { _selectionMode = false; _selected.clear(); }), tooltip: 'Cancelar'),
          ] else ...[
            if (_clipboard != null)
              IconButton(icon: const Icon(Icons.paste_rounded), onPressed: _paste, tooltip: 'Pegar'),
            IconButton(icon: Icon(_favorites.contains(_currentPath) ? Icons.star_rounded : Icons.star_outline_rounded, color: _favorites.contains(_currentPath) ? HubColors.amarillo : null), onPressed: _toggleFavorite, tooltip: 'Favorito'),
            IconButton(icon: const Icon(Icons.more_vert), onPressed: () {
              showModalBottomSheet<void>(
                context: context,
                backgroundColor: HubColors.panel,
                builder: (ctx) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(leading: Icon(Icons.sort, color: HubColors.textoAcento), title: Text('Ordenar', style: TextStyle(color: HubColors.textoPrincipal)), onTap: () { Navigator.pop(ctx); _showSortMenu(); }),
                      ListTile(leading: Icon(_view == _ViewMode.list ? Icons.grid_view_rounded : Icons.view_list_rounded, color: HubColors.textoAcento), title: Text(_view == _ViewMode.list ? 'Vista cuadrícula' : 'Vista lista', style: TextStyle(color: HubColors.textoPrincipal)), onTap: () { Navigator.pop(ctx); setState(() => _view = _view == _ViewMode.list ? _ViewMode.grid : _ViewMode.list); }),
                      ListTile(leading: Icon(_showHidden ? Icons.visibility_off : Icons.visibility, color: HubColors.textoAcento), title: Text(_showHidden ? 'Ocultar ocultos' : 'Mostrar ocultos', style: TextStyle(color: HubColors.textoPrincipal)), onTap: () { Navigator.pop(ctx); setState(() => _showHidden = !_showHidden); _navigateTo(_currentPath); }),
                      ListTile(leading: Icon(Icons.star_rounded, color: HubColors.amarillo), title: Text('Favoritos', style: TextStyle(color: HubColors.textoPrincipal)), onTap: () { Navigator.pop(ctx); _showFavorites(); }),
                      ListTile(leading: Icon(Icons.drive_file_move_outline, color: HubColors.textoAcento), title: Text('Ir a ruta', style: TextStyle(color: HubColors.textoPrincipal)), onTap: () { Navigator.pop(ctx); _goToPath(); }),
                      SizedBox(height: 8),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
      floatingActionButton: _selectionMode ? null : FloatingActionButton(
        backgroundColor: HubColors.pomelo,
        onPressed: _showCreateMenu,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          _buildBreadcrumb(),
          if (_storageInfo != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: _storageInfo!.usedRatio.clamp(0.0, 1.0),
                      backgroundColor: HubColors.linea,
                      color: HubColors.pomelo,
                      minHeight: 4,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text('${_storageInfo!.usedLabel} / ${_storageInfo!.totalLabel}', style: TextStyle(color: HubColors.textoSecundario, fontSize: 11)),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              style: TextStyle(color: HubColors.textoPrincipal, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Buscar…',
                hintStyle: TextStyle(color: HubColors.textoSecundario),
                prefixIcon: Icon(Icons.search, color: HubColors.textoSecundario, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchCtrl.clear(); })
                    : null,
                filled: true,
                fillColor: HubColors.panel,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                for (final f in FileFilter.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: FilterChip(
                      label: Text(_filterLabel(f), style: TextStyle(fontSize: 12, color: _filter == f ? Colors.white : HubColors.textoSecundario)),
                      selected: _filter == f,
                      onSelected: (_) => setState(() { _filter = f; _applyFilterAndSort(); }),
                      selectedColor: HubColors.pomelo,
                      backgroundColor: HubColors.panel,
                      checkmarkColor: Colors.white,
                      side: BorderSide.none,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 4),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: HubColors.pomelo))
                : _filtered.isEmpty
                    ? Center(child: Text('Vacío', style: TextStyle(color: HubColors.textoSecundario)))
                    : RefreshIndicator(
                        color: HubColors.pomelo,
                        onRefresh: () => _navigateTo(_currentPath),
                        child: _view == _ViewMode.list ? _buildList() : _buildGrid(),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      itemCount: _filtered.length,
      itemBuilder: (ctx, i) {
        final e = _filtered[i];
        final selected = _selected.contains(e.path);
        return ListTile(
          leading: Icon(_iconFor(e), color: _iconColor(e)),
          title: Text(e.name, style: TextStyle(color: HubColors.textoPrincipal, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(e.isDirectory ? 'Carpeta' : e.sizeLabel, style: TextStyle(color: HubColors.textoSecundario, fontSize: 11)),
          selected: selected,
          selectedTileColor: HubColors.pomelo.withOpacity(0.12),
          onTap: () {
            if (_selectionMode) {
              setState(() {
                if (selected) _selected.remove(e.path); else _selected.add(e.path);
                if (_selected.isEmpty) _selectionMode = false;
              });
            } else if (e.isDirectory) {
              _navigateTo(e.path);
            } else {
              DeviceFilesService.openFile(e.path);
            }
          },
          onLongPress: () {
            if (!_selectionMode) {
              setState(() { _selectionMode = true; _selected.add(e.path); });
            } else {
              _showContextMenu(e);
            }
          },
          trailing: _selectionMode
              ? Icon(selected ? Icons.check_circle : Icons.circle_outlined, color: selected ? HubColors.pomelo : HubColors.textoSecundario, size: 22)
              : null,
        );
      },
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 0.85),
      itemCount: _filtered.length,
      itemBuilder: (ctx, i) {
        final e = _filtered[i];
        final selected = _selected.contains(e.path);
        return InkWell(
          onTap: () {
            if (_selectionMode) {
              setState(() {
                if (selected) _selected.remove(e.path); else _selected.add(e.path);
                if (_selected.isEmpty) _selectionMode = false;
              });
            } else if (e.isDirectory) {
              _navigateTo(e.path);
            } else {
              DeviceFilesService.openFile(e.path);
            }
          },
          onLongPress: () {
            if (!_selectionMode) {
              setState(() { _selectionMode = true; _selected.add(e.path); });
            } else {
              _showContextMenu(e);
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: selected ? HubColors.pomelo.withOpacity(0.15) : HubColors.panel,
              borderRadius: BorderRadius.circular(12),
              border: selected ? Border.all(color: HubColors.pomelo, width: 1.5) : null,
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_iconFor(e), color: _iconColor(e), size: 36),
                SizedBox(height: 6),
                Text(e.name, style: TextStyle(color: HubColors.textoPrincipal, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
              ],
            ),
          ),
        );
      },
    );
  }

  String _filterLabel(FileFilter f) {
    switch (f) {
      case FileFilter.all: return 'Todo';
      case FileFilter.folders: return 'Carpetas';
      case FileFilter.images: return 'Imágenes';
      case FileFilter.videos: return 'Videos';
      case FileFilter.audio: return 'Audio';
      case FileFilter.documents: return 'Docs';
      case FileFilter.archives: return 'Archivos';
      case FileFilter.apks: return 'APKs';
    }
  }
}
