import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/project_md.dart';

class ProjectFsService {
  static const String rootDirName = '.anythinghub';
  static const String cacheDir = 'cache';
  static const String configDir = 'config';
  static const String logsDir = 'logs';
  static const String projectsDir = 'projects';
  static const String pluginsDir = 'plugins';

  /// Preferencia: carpeta pública Documents para que editores (Acode, Markor)
  /// y el explorador del sistema puedan ver `.anythinghub` / `project.md`.
  static Future<Directory> getRootDirectory() async {
    final publicDocs = Directory('/storage/emulated/0/Documents');
    try {
      if (await publicDocs.exists()) {
        return Directory(p.join(publicDocs.path, rootDirName));
      }
    } catch (_) {}

    try {
      final ext = await getExternalStorageDirectory();
      if (ext != null) {
        return Directory(p.join(ext.path, rootDirName));
      }
    } catch (_) {}

    final base = await getApplicationDocumentsDirectory();
    return Directory(p.join(base.path, rootDirName));
  }

  static Future<void> ensureStructure() async {
    final root = await getRootDirectory();
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    for (final sub in [cacheDir, configDir, logsDir, projectsDir, pluginsDir]) {
      final d = Directory(p.join(root.path, sub));
      if (!await d.exists()) {
        await d.create(recursive: true);
      }
    }
    final icons = Directory(p.join(root.path, cacheDir, 'icons'));
    if (!await icons.exists()) {
      await icons.create(recursive: true);
    }

    final editorsFile = File(p.join(root.path, configDir, 'editors.json'));
    if (!await editorsFile.exists()) {
      await editorsFile.writeAsString('''
{
  "preferred": "acode",
  "fallback": "vscode.dev",
  "whitelist": [
    "com.foxdebug.acode",
    "com.markor",
    "com.termux"
  ]
}
''');
    }
  }

  static Future<ProjectMd> createProject({
    required String name,
    String? language,
    List<String> tags = const [],
    String editor = 'acode',
  }) async {
    await ensureStructure();
    final root = await getRootDirectory();
    final id = const Uuid().v4();
    final safeName = name
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '-')
        .toLowerCase();
    final baseFolder = safeName.isEmpty ? id : safeName;
    var projectPath = p.join(root.path, projectsDir, baseFolder);

    var dir = Directory(projectPath);
    if (await dir.exists()) {
      final unique = '$baseFolder-${id.substring(0, 8)}';
      projectPath = p.join(root.path, projectsDir, unique);
      dir = Directory(projectPath);
    }
    await dir.create(recursive: true);

    final now = DateTime.now();
    final project = ProjectMd(
      name: name,
      id: id,
      created: now,
      lastOpened: now,
      tags: tags,
      editor: editor,
      language: language,
      description: 'Proyecto creado desde Anythings Hub.',
    );

    final mdFile = File(p.join(dir.path, 'project.md'));
    await mdFile.writeAsString(project.toMarkdown());

    final gitignore = File(p.join(dir.path, '.gitignore'));
    await gitignore.writeAsString('''
# Anythings Hub
.anythinghub/cache/
*.log
.DS_Store
''');

    return project;
  }

  static Future<List<ProjectMd>> listProjects() async {
    final root = await getRootDirectory();
    final projectsRoot = Directory(p.join(root.path, projectsDir));
    if (!await projectsRoot.exists()) return [];

    final list = <ProjectMd>[];
    await for (final entity in projectsRoot.list()) {
      if (entity is! Directory) continue;
      final md = File(p.join(entity.path, 'project.md'));
      if (!await md.exists()) continue;
      final content = await md.readAsString();
      final parsed = ProjectMd.fromMarkdown(content);
      if (parsed != null) list.add(parsed);
    }
    list.sort((a, b) {
      final da = b.lastOpened ?? b.created;
      final db = a.lastOpened ?? a.created;
      return da.compareTo(db);
    });
    return list;
  }

  static Future<void> uninstallModule() async {
    final root = await getRootDirectory();
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  }

  static Future<bool> hasAnyTrace() async {
    final root = await getRootDirectory();
    return await root.exists();
  }

  static Future<String?> getProjectPath(String projectId) async {
    final root = await getRootDirectory();
    final projectsRoot = Directory(p.join(root.path, projectsDir));
    if (!await projectsRoot.exists()) return null;

    await for (final entity in projectsRoot.list()) {
      if (entity is! Directory) continue;
      final md = File(p.join(entity.path, 'project.md'));
      if (!await md.exists()) continue;
      final content = await md.readAsString();
      final parsed = ProjectMd.fromMarkdown(content);
      if (parsed != null && parsed.id == projectId) {
        return entity.path;
      }
    }
    return null;
  }

  static Future<void> updateLastOpened(String projectId) async {
    final path = await getProjectPath(projectId);
    if (path == null) return;
    final md = File(p.join(path, 'project.md'));
    if (!await md.exists()) return;
    final content = await md.readAsString();
    final parsed = ProjectMd.fromMarkdown(content);
    if (parsed == null) return;
    final updated = parsed.copyWith(lastOpened: DateTime.now());
    await md.writeAsString(updated.toMarkdown());
  }

  static Future<void> saveProject(ProjectMd project) async {
    final path = await getProjectPath(project.id);
    if (path == null) return;
    final md = File(p.join(path, 'project.md'));
    await md.writeAsString(project.toMarkdown());
  }
}
