import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import 'project_fs_service.dart';
import 'termux_service.dart';

/// Editor instalado detectado en el dispositivo.
class InstalledEditor {
  const InstalledEditor({
    required this.packageName,
    required this.label,
    required this.id,
  });

  final String packageName;
  final String label;
  final String id;

  Map<String, dynamic> toJson() => {
        'package': packageName,
        'label': label,
        'id': id,
      };

  factory InstalledEditor.fromJson(Map<String, dynamic> j) => InstalledEditor(
        packageName: j['package'] as String,
        label: j['label'] as String,
        id: j['id'] as String,
      );
}

class EditorPreferences {
  EditorPreferences({
    this.preferred = 'acode',
    this.fallback = 'vscode.dev',
    this.whitelist = const [
      'com.foxdebug.acode',
      'com.markor',
      'com.termux',
      'com.aor.droidedit',
      'com.github.mobile',
    ],
  });

  String preferred;
  String fallback;
  List<String> whitelist;

  Map<String, dynamic> toJson() => {
        'preferred': preferred,
        'fallback': fallback,
        'whitelist': whitelist,
      };

  factory EditorPreferences.fromJson(Map<String, dynamic> j) =>
      EditorPreferences(
        preferred: j['preferred'] as String? ?? 'acode',
        fallback: j['fallback'] as String? ?? 'vscode.dev',
        whitelist: List<String>.from(j['whitelist'] as List? ?? const []),
      );
}

class EditorService {
  static const MethodChannel _ch = MethodChannel('anythings.hub/device_apps');

  static const Map<String, String> _knownLabels = {
    'com.foxdebug.acode': 'Acode',
    'com.markor': 'Markor',
    'com.termux': 'Termux',
    'com.aor.droidedit': 'DroidEdit',
    'com.github.mobile': 'GitHub',
    'com.spisoft.quicknote': 'QuickNote',
  };

  static const Map<String, String> _idByPackage = {
    'com.foxdebug.acode': 'acode',
    'com.markor': 'markor',
    'com.termux': 'termux',
    'com.aor.droidedit': 'code_editor',
  };

  static Future<EditorPreferences> loadPreferences() async {
    try {
      final root = await ProjectFsService.getRootDirectory();
      final file =
          File(p.join(root.path, ProjectFsService.configDir, 'editors.json'));
      if (await file.exists()) {
        final raw = await file.readAsString();
        return EditorPreferences.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      }
    } catch (_) {}
    return EditorPreferences();
  }

  static Future<void> savePreferences(EditorPreferences prefs) async {
    final root = await ProjectFsService.getRootDirectory();
    final dir = Directory(p.join(root.path, ProjectFsService.configDir));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final file = File(p.join(dir.path, 'editors.json'));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(prefs.toJson()),
    );
  }

  static Future<List<InstalledEditor>> detectInstalledEditors() async {
    final prefs = await loadPreferences();
    final found = <InstalledEditor>[];

    try {
      final raw =
          await _ch.invokeMethod<List<dynamic>>('listInstalledPackages');
      if (raw != null) {
        for (final pkg in raw.whereType<String>()) {
          if (prefs.whitelist.contains(pkg) ||
              _knownLabels.containsKey(pkg)) {
            found.add(InstalledEditor(
              packageName: pkg,
              label: _knownLabels[pkg] ?? pkg.split('.').last,
              id: _idByPackage[pkg] ?? 'custom',
            ));
          }
        }
      }
    } on MissingPluginException {
    } on PlatformException {
    }

    return found;
  }

  static Future<String> resolveEditor() async {
    final prefs = await loadPreferences();
    final installed = await detectInstalledEditors();
    final installedPkgs = installed.map((e) => e.packageName).toSet();

    if (prefs.preferred != 'vscode.dev') {
      for (final e in installed) {
        if (e.id == prefs.preferred || e.packageName == prefs.preferred) {
          return e.id;
        }
      }
    }

    for (final pkg in prefs.whitelist) {
      if (installedPkgs.contains(pkg)) {
        return _idByPackage[pkg] ?? 'custom';
      }
    }

    return prefs.fallback;
  }

  static Future<bool> openProject({
    required String projectPath,
    String? preferredEditorId,
  }) async {
    final editorId = preferredEditorId ?? await resolveEditor();

    if (editorId == 'vscode.dev') {
      final uri = Uri.parse('https://vscode.dev');
      if (await canLaunchUrl(uri)) {
        return launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return false;
    }

    if (editorId == 'termux') {
      return TermuxService.openInFolder(projectPath);
    }

    final installed = await detectInstalledEditors();
    InstalledEditor? target;
    for (final e in installed) {
      if (e.id == editorId) {
        target = e;
        break;
      }
    }
    if (target == null) return false;

    try {
      final result = await _ch.invokeMethod<bool>('launchAppWithPath', {
        'package': target.packageName,
        'path': projectPath,
      });
      return result ?? false;
    } catch (_) {
      try {
        final result = await _ch.invokeMethod<bool>('launchApp', {
          'package': target.packageName,
        });
        return result ?? false;
      } catch (_) {
        return false;
      }
    }
  }
}
