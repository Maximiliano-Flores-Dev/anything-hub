import 'package:flutter/material.dart';

import '../models/project_md.dart';
import '../services/editor_service.dart';
import '../services/isolation_service.dart';
import '../services/project_activation_service.dart';
import '../services/project_fs_service.dart';
import '../services/termux_service.dart';
import 'editor_settings_sheet.dart';
import 'github_auth_screen.dart';
import 'hub_colors_local.dart';
import 'local_docs_screen.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  List<ProjectMd> _projects = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ProjectFsService.ensureStructure();
      final list = await ProjectFsService.listProjects();
      if (!mounted) return;
      setState(() {
        _projects = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _createProject() async {
    final nameCtrl = TextEditingController();
    String selectedEditor = 'acode';
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              backgroundColor: HubColors.panel,
              title: Text('Nuevo proyecto', style: TextStyle(color: HubColors.textoPrincipal)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    style: TextStyle(color: HubColors.textoPrincipal),
                    decoration: InputDecoration(
                      hintText: 'Nombre del proyecto',
                      hintStyle: TextStyle(color: HubColors.textoSecundario.withOpacity(0.7)),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: HubColors.linea)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: HubColors.pomelo)),
                    ),
                  ),
                  SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedEditor,
                    dropdownColor: HubColors.panel,
                    style: TextStyle(color: HubColors.textoPrincipal),
                    items: const [
                      DropdownMenuItem(value: 'acode', child: Text('Acode')),
                      DropdownMenuItem(value: 'markor', child: Text('Markor')),
                      DropdownMenuItem(value: 'termux', child: Text('Termux')),
                      DropdownMenuItem(value: 'vscode.dev', child: Text('vscode.dev')),
                    ],
                    onChanged: (v) {
                      if (v != null) setLocal(() => selectedEditor = v);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancelar', style: TextStyle(color: HubColors.textoSecundario)),
                ),
                TextButton(
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    Navigator.pop(ctx, {'name': name, 'editor': selectedEditor});
                  },
                  child: Text('Crear', style: TextStyle(color: HubColors.pomelo)),
                ),
              ],
            );
          },
        );
      },
    );
    if (result == null) return;

    try {
      await ProjectFsService.createProject(
        name: result['name']!,
        editor: result['editor'] ?? 'acode',
        tags: const ['anythinghub'],
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Proyecto "${result['name']}" creado'),
          backgroundColor: HubColors.panel,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _openProject(ProjectMd project) async {
    final path = await ProjectFsService.getProjectPath(project.id) ?? '';
    final editor = project.editor.isNotEmpty
        ? project.editor
        : await EditorService.resolveEditor();

    await ProjectFsService.updateLastOpened(project.id);

    bool ok = false;
    if (editor == 'termux') {
      ok = await TermuxService.openInFolder(path);
    } else {
      ok = await EditorService.openProject(
        projectPath: path,
        preferredEditorId: editor,
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Abriendo ${project.name} con $editor'
            : 'No se pudo abrir el editor ($editor)'),
        backgroundColor: HubColors.panel,
      ),
    );
    await _load();
  }

  Future<void> _confirmUninstall() async {
    final first = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HubColors.panel,
        title: Text('Desinstalar módulo', style: TextStyle(color: HubColors.textoPrincipal)),
        content: Text(
          'Se eliminará completamente .anythinghub/ y todos los proyectos.',
          style: TextStyle(color: HubColors.textoSecundario),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continuar', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (first != true) return;

    final second = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HubColors.panel,
        title: Text('Confirmación final', style: TextStyle(color: HubColors.textoPrincipal)),
        content: Text(
          '¿Estás seguro? Se borrará todo el módulo de proyectos.',
          style: TextStyle(color: HubColors.textoSecundario),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, borrar todo', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (second != true) return;

    await ProjectFsService.uninstallModule();
    await ProjectActivationService.deactivate();
    await IsolationService.enforceIsolationIfInactive();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HubColors.fondoPrincipal,
      appBar: AppBar(
        backgroundColor: HubColors.fondoSidebar,
        elevation: 0,
        title: Text('Proyectos', style: TextStyle(color: HubColors.textoPrincipal)),
        iconTheme: IconThemeData(color: HubColors.textoPrincipal),
        actions: [
          IconButton(
            icon: const Icon(Icons.code_rounded),
            tooltip: 'Editor predeterminado',
            onPressed: () {
              showModalBottomSheet<void>(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (_) => const EditorSettingsSheet(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.lock_outline_rounded),
            tooltip: 'GitHub OAuth',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const GitHubAuthScreen()),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            color: HubColors.panel,
            onSelected: (value) {
              switch (value) {
                case 'docs':
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const LocalDocsScreen()),
                  );
                  break;
                case 'uninstall':
                  _confirmUninstall();
                  break;
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'docs',
                child: Text('Documentación', style: TextStyle(color: HubColors.textoPrincipal)),
              ),
              PopupMenuItem(
                value: 'uninstall',
                child: Text('Desinstalar módulo', style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: HubColors.pomelo,
        foregroundColor: HubColors.fondoPrincipal,
        onPressed: _createProject,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: HubColors.pomelo))
          : _error != null
              ? Center(child: Text(_error!, style: TextStyle(color: Colors.redAccent)))
              : _projects.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.folder_open_rounded,
                              size: 56, color: HubColors.textoSecundario.withOpacity(0.5)),
                          SizedBox(height: 12),
                          Text('No hay proyectos todavía',
                              style: TextStyle(color: HubColors.textoSecundario, fontSize: 15)),
                          SizedBox(height: 6),
                          Text('Toca + para crear el primero',
                              style: TextStyle(color: HubColors.textoAcento, fontSize: 13)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: HubColors.pomelo,
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                        itemCount: _projects.length,
                        separatorBuilder: (_, __) => SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final p = _projects[i];
                          return Container(
                            decoration: BoxDecoration(
                              color: HubColors.panel,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: HubColors.linea.withOpacity(0.6)),
                            ),
                            child: ListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  gradient: HubColors.degradado,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.code_rounded, color: Colors.white, size: 22),
                              ),
                              title: Text(p.name,
                                  style: TextStyle(
                                      color: HubColors.textoPrincipal, fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                p.tags.isEmpty ? p.editor : '${p.editor} · ${p.tags.join(' · ')}',
                                style: TextStyle(
                                    color: HubColors.textoSecundario, fontSize: 12.5),
                              ),
                              trailing: Icon(Icons.chevron_right_rounded,
                                  color: HubColors.textoSecundario),
                              onTap: () => _openProject(p),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
