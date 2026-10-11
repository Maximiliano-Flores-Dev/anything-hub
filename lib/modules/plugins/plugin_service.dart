import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../core/logger.dart';
import '../projects/services/project_fs_service.dart';
import 'plugin_models.dart';

/// Catálogo remoto (carpeta `plugins/` del repo) + instalación local
/// en `.anythinghub/plugins/`. Solo descarga manifiestos/JSON — no ejecuta código.
class PluginService {
  static const catalogUrl =
      'https://raw.githubusercontent.com/Maximiliano-Flores-Dev/anything-hub/main/plugins/catalog.json';

  static const pluginsDirName = 'plugins';

  static Future<Directory> localPluginsRoot() async {
    final root = await ProjectFsService.getRootDirectory();
    final dir = Directory(p.join(root.path, pluginsDirName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<List<HubPluginEntry>> listInstalled() async {
    final root = await localPluginsRoot();
    final out = <HubPluginEntry>[];
    if (!await root.exists()) return out;
    await for (final entity in root.list()) {
      if (entity is! Directory) continue;
      final mf = File(p.join(entity.path, 'manifest.json'));
      if (!await mf.exists()) continue;
      try {
        final json = jsonDecode(await mf.readAsString()) as Map<String, dynamic>;
        final m = HubPluginManifest.fromJson(json);
        if (m.isValid) {
          out.add(HubPluginEntry(
            manifest: m,
            installed: true,
            localPath: entity.path,
          ));
        }
      } catch (e) {
        SystemLogger.log('Plugin inválido en ${entity.path}: $e');
      }
    }
    out.sort((a, b) => a.manifest.name.compareTo(b.manifest.name));
    return out;
  }

  static Future<List<HubPluginEntry>> fetchCatalog() async {
    try {
      final res = await http.get(Uri.parse(catalogUrl)).timeout(
            const Duration(seconds: 12),
          );
      if (res.statusCode != 200) {
        SystemLogger.log('Catálogo plugins HTTP ${res.statusCode}');
        return [];
      }
      final data = jsonDecode(res.body);
      final list = data is Map
          ? (data['plugins'] as List<dynamic>? ?? [])
          : (data as List<dynamic>);
      final installed = await listInstalled();
      final installedIds = {for (final e in installed) e.manifest.id};

      final out = <HubPluginEntry>[];
      for (final raw in list) {
        if (raw is! Map) continue;
        final m = HubPluginManifest.fromJson(Map<String, dynamic>.from(raw));
        if (!m.isValid) continue;
        out.add(HubPluginEntry(
          manifest: m,
          installed: installedIds.contains(m.id),
          catalogUrl: catalogUrl,
          localPath: installedIds.contains(m.id)
              ? installed.firstWhere((e) => e.manifest.id == m.id).localPath
              : null,
        ));
      }
      return out;
    } catch (e) {
      SystemLogger.log('Error catálogo plugins: $e');
      return [];
    }
  }

  static Future<bool> install(HubPluginManifest manifest, {String? bundleUrl}) async {
    if (!manifest.isValid) return false;
    try {
      await ProjectFsService.ensureStructure();
      final root = await localPluginsRoot();
      final dest = Directory(p.join(root.path, manifest.id));
      if (!await dest.exists()) {
        await dest.create(recursive: true);
      }
      final mf = File(p.join(dest.path, 'manifest.json'));
      await mf.writeAsString(
        const JsonEncoder.withIndent('  ').convert(manifest.toJson()),
      );

      if (bundleUrl != null && bundleUrl.isNotEmpty) {
        try {
          final res = await http.get(Uri.parse(bundleUrl)).timeout(
                const Duration(seconds: 15),
              );
          if (res.statusCode == 200) {
            final bundle = File(p.join(dest.path, 'bundle.json'));
            await bundle.writeAsBytes(res.bodyBytes);
          }
        } catch (e) {
          SystemLogger.log('Bundle plugin opcional falló: $e');
        }
      }

      final meta = File(p.join(dest.path, 'installed.json'));
      await meta.writeAsString(jsonEncode({
        'installedAt': DateTime.now().toIso8601String(),
        'source': 'github-catalog',
      }));
      return true;
    } catch (e) {
      SystemLogger.log('Install plugin falló: $e');
      return false;
    }
  }

  static Future<bool> uninstall(String pluginId) async {
    try {
      final root = await localPluginsRoot();
      final dest = Directory(p.join(root.path, pluginId));
      if (await dest.exists()) {
        await dest.delete(recursive: true);
      }
      return true;
    } catch (e) {
      SystemLogger.log('Uninstall plugin falló: $e');
      return false;
    }
  }

  static Future<bool> isInstalled(String pluginId) async {
    final root = await localPluginsRoot();
    final mf = File(p.join(root.path, pluginId, 'manifest.json'));
    return mf.exists();
  }
}
