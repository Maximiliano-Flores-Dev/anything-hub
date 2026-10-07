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
        title: Text(title, style: const TextStyle(color: HubColors.textoPrincipal)),
        content: TextField(
          controller: ctrl, autofocus: true,
          style: const TextStyle(color: HubColors.textoPrincipal),
          decoration: InputDecoration(
            hintText: hint, hintStyle: const TextStyle(color: HubColors.textoSecundario),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: HubColors.linea)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: HubColors.pomelo)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: HubColors.textoSecundario))),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Aceptar', style: TextStyle(color: HubColors.pomelo))),
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HubColors.panel,
        title: const Text('Eliminar', style: TextStyle(color: HubColors.textoPrincipal)),
        content: Text(
          entries.length == 1 ? '¿Eliminar "${entries.first.name}"?' : '¿Eliminar ${entries.length} elementos?',
          style: const TextStyle(color: HubColors.textoSecundario),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar', style: TextStyle(color: HubColors.textoSecundario))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirm != true) return;
    var okCount = 0;
    for (final e in entries) {
      if (await DeviceFilesService.deleteEntry(e.path)) okCount++;
    }
    _toast(okCount == entries.length ? 'Eliminado' : 'Eliminados $okCount de ${entries.length}');
    setState(() { _selected.clear(); _selectionMode = false; });
    await _navigateTo(_currentPath);
  }

  void _copySelected({required bool cut}) {
    final entries = _entries.where((e) => _selected.contains(e.path)).toList();
    if (entries.isEmpty) return;
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
    var okCount = 0;
    for (final e in clip.entries) {
      final dest = '$_currentPath/${e.name}';
      final ok = clip.mode == _ClipMode.cut
          ? await DeviceFilesService.moveEntry(e.path, dest)
          : await DeviceFilesService.copyEntry(e.path, dest);
      if (ok) okCount++;
    }
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
          return const SafeArea(child: Padding(padding: EdgeInsets.all(24), child: Text('Sin favoritos', style: TextStyle(color: HubColors.textoSecundario))));
        }
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(padding: EdgeInsets.all(16), child: Text('Favoritos', style: TextStyle(color: HubColors.textoPrincipal, fontWeight: FontWeight.w700))),
              ..._favorites.map((p) => ListTile(
                leading: const Icon(Icons.star_rounded, color: HubColors.amarillo),
                title: Text(p.split('/').last.isEmpty ? p : p.split('/').last, style: const TextStyle(color: HubColors.textoPrincipal)),
                subtitle: Text(p, style: const TextStyle(color: HubColors.textoSecundario, fontSize: 11)),
                onTap: () { Navigator.pop(ctx); _navigateTo(p); },
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18, color: HubColors.textoSecundario),
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
            ListTile(leading: const Icon(Icons.info_outline, color: HubColors.textoAcento), title: const Text('Detalles', style: TextStyle(color: HubColors.textoPrincipal)), onTap: () { Navigator.pop(ctx); _showDetails(entry); }),
            ListTile(leading: const Icon(Icons.drive_file_rename_outline, color: HubColors.textoAcento), title: const Text('Renombrar', style: TextStyle(color: HubColors.textoPrincipal)), onTap: () { Navigator.pop(ctx); _rename(entry); }),
            ListTile(leading: const Icon(Icons.copy_rounded, color: HubColors.textoAcento), title: const Text('Copiar', style: TextStyle(color: HubColors.textoPrincipal)), onTap: () { Navigator.pop(ctx); setState(() { _selected..clear()..add(entry.path); }); _copySelected(cut: false); }),
            ListTile(leading: const Icon(Icons.cut_rounded, color: HubColors.textoAcento), title: const Text('Cortar', style: TextStyle(color: HubColors.textoPrincipal)), onTap: () { Navigator.pop(ctx); setState(() { _selected..clear()..add(entry.path); }); _copySelected(cut: true); }),
            ListTile(leading: const Icon(Icons.delete_outline, color: Colors.redAccent), title: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)), onTap: () { Navigator.pop(ctx); _deleteEntries([entry]); }),
            const SizedBox(height: 8),
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
            ListTile(leading: const Icon(Icons.create_new_folder_rounded, color: HubColors.amarillo), title: const Text('Nueva carpeta', style: TextStyle(color: HubColors.textoPrincipal)), onTap: () { Navigator.pop(ctx); _createFolder(); }),
            ListTile(leading: const Icon(Icons.note_add_rounded, color: HubColors.textoAcento), title: const Text('Nuevo archivo', style: TextStyle(color: HubColors.textoPrincipal)), onTap: () { Navigator.pop(ctx); _createFile(); }),
            const SizedBox(height: 8),
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
                trailing: _sort == m ? const Icon(Icons.check, color: HubColors.pomelo, size: 18) : null,
                onTap: () { Navigator.pop(ctx); setState(() { _sort = m; _applyFilterAndSort(); }); },
              ),
            const SizedBox(height: 8),
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
          InkWell(onTap: () { if (_roots.isNotEmpty) _navigateTo(_roots.first['path']!); }, child: const Icon(Icons.home_rounded, size: 18, color: HubColors.textoAcento)),
          for (var i = 0; i < parts.length; i++) ...[
            const Icon(Icons.chevron_right, size: 16, color: HubColors.textoSecundario),
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
                const Icon(Icons.folder_off_rounded, size: 64, color: HubColors.textoSecundario),
                const SizedBox(height: 16),
                const Text('Se necesita acceso a todos los archivos', textAlign: TextAlign.center, style: TextStyle(color: HubColors.textoPrincipal, fontSize: 16)),
                const SizedBox(height: 20),
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
          style: const TextStyle(color: HubColors.textoPrincipal, fontSize: 16),
        ),
        iconTheme: const IconThemeData(color: HubColors.textoPrincipal),
        leading: _selectionMode
            ? IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() { _selectionMode = false; _selected.clear(); }))
            : (_currentPath.split('/').where((p) => p.isNotEmpty).length > 1
                ? IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () {
                    final parent = _currentPath.substring(0, _currentPath.lastIndexOf('/'));
                    if (parent.isNotEmpty) _navigateTo(parent);
                  })
                : null),
        actions: [
          if (_selectionMode) ...[
            IconButton(icon: const Icon(Icons.copy_rounded), tooltip: 'Copiar', onPressed: () => _copySelected(cut: false)),
            IconButton(icon: const Icon(Icons.cut_rounded), tooltip: 'Cortar', onPressed: () => _copySelected(cut: true)),
            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), tooltip: 'Eliminar', onPressed: () {
              final entries = _entries.where((e) => _selected.contains(e.path)).toList();
              _deleteEntries(entries);
            }),
          ] else ...[
            if (_clipboard != null) IconButton(icon: const Icon(Icons.content_paste_rounded), tooltip: 'Pegar', onPressed: _paste),
            IconButton(
              icon: Icon(_favorites.contains(_currentPath) ? Icons.star_rounded : Icons.star_outline_rounded, color: _favorites.contains(_currentPath) ? HubColors.amarillo : null),
              tooltip: 'Favorito', onPressed: _toggleFavorite,
            ),
            IconButton(icon: const Icon(Icons.star_half_rounded), tooltip: 'Ver favoritos', onPressed: _showFavorites),
            IconButton(
              icon: Icon(_view == _ViewMode.list ? Icons.grid_view_rounded : Icons.view_list_rounded),
              tooltip: 'Vista',
              onPressed: () => setState(() { _view = _view == _ViewMode.list ? _ViewMode.grid : _ViewMode.list; }),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              color: HubColors.panel,
              onSelected: (v) {
                switch (v) {
                  case 'create': _showCreateMenu(); break;
                  case 'sort': _showSortMenu(); break;
                  case 'hidden': setState(() => _showHidden = !_showHidden); _navigateTo(_currentPath); break;
                  case 'goto': _goToPath(); break;
                  case 'refresh': _navigateTo(_currentPath); break;
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'create', child: Text('Crear', style: TextStyle(color: HubColors.textoPrincipal))),
                const PopupMenuItem(value: 'sort', child: Text('Ordenar', style: TextStyle(color: HubColors.textoPrincipal))),
                PopupMenuItem(value: 'hidden', child: Text(_showHidden ? 'Ocultar ocultos' : 'Mostrar ocultos', style: const TextStyle(color: HubColors.textoPrincipal))),
                const PopupMenuItem(value: 'goto', child: Text('Ir a ruta', style: TextStyle(color: HubColors.textoPrincipal))),
                const PopupMenuItem(value: 'refresh', child: Text('Actualizar', style: TextStyle(color: HubColors.textoPrincipal))),
              ],
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: HubColors.pomelo))
          : Column(
              children: [
                _buildBreadcrumb(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: TextField(
                    controller: _searchCtrl,
                    focusNode: _searchFocus,
                    style: const TextStyle(color: HubColors.textoPrincipal, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Buscar…',
                      hintStyle: const TextStyle(color: HubColors.textoSecundario),
                      prefixIcon: const Icon(Icons.search, color: HubColors.textoSecundario, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => _searchCtrl.clear()) : null,
                      filled: true,
                      fillColor: HubColors.panel,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
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
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            label: Text(_filterLabel(f), style: TextStyle(fontSize: 12, color: _filter == f ? HubColors.fondoPrincipal : HubColors.textoPrincipal)),
                            selected: _filter == f,
                            onSelected: (_) => setState(() { _filter = f; _applyFilterAndSort(); }),
                            selectedColor: HubColors.pomelo,
                            backgroundColor: HubColors.panel,
                            showCheckmark: false,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                    ],
                  ),
                ),
                if (_storageInfo != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        Expanded(child: LinearProgressIndicator(value: _storageInfo!.usedRatio.clamp(0.0, 1.0), backgroundColor: HubColors.linea, color: HubColors.pomelo, minHeight: 4)),
                        const SizedBox(width: 8),
                        Text('${_storageInfo!.usedLabel} / ${_storageInfo!.totalLabel}', style: const TextStyle(color: HubColors.textoSecundario, fontSize: 11)),
                      ],
                    ),
                  ),
                Expanded(
                  child: _filtered.isEmpty
                      ? const Center(child: Text('Vacío', style: TextStyle(color: HubColors.textoSecundario)))
                      : _view == _ViewMode.grid
                          ? GridView.builder(
                              padding: const EdgeInsets.all(12),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.85),
                              itemCount: _filtered.length,
                              itemBuilder: (ctx, i) {
                                final e = _filtered[i];
                                final sel = _selected.contains(e.path);
                                return InkWell(
                                  onTap: () {
                                    if (_selectionMode) {
                                      setState(() { if (sel) { _selected.remove(e.path); if (_selected.isEmpty) _selectionMode = false; } else { _selected.add(e.path); } });
                                    } else if (e.isDirectory) { _navigateTo(e.path); }
                                    else { _showDetails(e); }
                                  },
                                  onLongPress: () => setState(() { _selectionMode = true; _selected.add(e.path); }),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: sel ? HubColors.pomelo.withOpacity(0.15) : HubColors.panel,
                                      borderRadius: BorderRadius.circular(12),
                                      border: sel ? Border.all(color: HubColors.pomelo, width: 1.5) : null,
                                    ),
                                    padding: const EdgeInsets.all(8),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        FileThumb(entry: e, fallbackIcon: _iconFor(e), fallbackColor: _iconColor(e), size: 48),
                                        const SizedBox(height: 6),
                                        Text(e.name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(color: HubColors.textoPrincipal, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            )
                          : ListView.builder(
                              itemCount: _filtered.length,
                              itemBuilder: (ctx, i) {
                                final e = _filtered[i];
                                final sel = _selected.contains(e.path);
                                return ListTile(
                                  selected: sel,
                                  selectedTileColor: HubColors.pomelo.withOpacity(0.12),
                                  leading: FileThumb(entry: e, fallbackIcon: _iconFor(e), fallbackColor: _iconColor(e)),
                                  title: Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: HubColors.textoPrincipal)),
                                  subtitle: Text(e.isDirectory ? '' : e.sizeLabel, style: const TextStyle(color: HubColors.textoSecundario, fontSize: 11)),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_selectionMode) Icon(sel ? Icons.check_circle : Icons.circle_outlined, color: sel ? HubColors.pomelo : HubColors.textoSecundario, size: 22),
                                      if (!_selectionMode && e.isDirectory) const Icon(Icons.chevron_right_rounded, color: HubColors.textoSecundario, size: 20),
                                      if (!_selectionMode && !e.isDirectory) IconButton(icon: const Icon(Icons.more_vert_rounded, color: HubColors.textoSecundario, size: 18), onPressed: () => _showContextMenu(e), visualDensity: VisualDensity.compact),
                                    ],
                                  ),
                                  onTap: () {
                                    if (_selectionMode) {
                                      setState(() { if (sel) { _selected.remove(e.path); if (_selected.isEmpty) _selectionMode = false; } else { _selected.add(e.path); } });
                                    } else if (e.isDirectory) { _navigateTo(e.path); }
                                    else { _showDetails(e); }
                                  },
                                  onLongPress: () => setState(() { _selectionMode = true; _selected.add(e.path); }),
                                );
                              },
                            ),
                ),
              ],
            ),
      floatingActionButton: _selectionMode ? null : FloatingActionButton(
        backgroundColor: HubColors.pomelo,
        foregroundColor: HubColors.fondoPrincipal,
        onPressed: _showCreateMenu,
        child: const Icon(Icons.add),
      ),
    );
  }

  String _filterLabel(FileFilter f) {
    switch (f) {
      case FileFilter.all: return 'Todos';
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
