import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../modules/projects/services/project_fs_service.dart';

/// Utilidades de solo-lectura para el File Manager:
/// hashes, preview de texto, thumbnails/cache de iconos.
/// No abre ni ejecuta archivos externos.
class FilePreviewService {
  static const _iconCacheSubdir = 'icons';
  static const textExtensions = {'txt', 'md', 'json', 'log', 'csv', 'yaml', 'yml'};
  static const imageExtensions = {'jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'};

  static Future<Directory> _iconsCacheDir() async {
    final root = await ProjectFsService.getRootDirectory();
    final dir = Directory(p.join(root.path, ProjectFsService.cacheDir, _iconCacheSubdir));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// MD5 + SHA-1 de un archivo (solo lectura).
  /// Archivos > 64 MB: se hashea por chunks sin cargar todo en RAM.
  static Future<({String md5hex, String sha1hex})?> hashes(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      final stat = await file.stat();
      if (stat.type != FileSystemEntityType.file) return null;

      if (stat.size <= 64 * 1024 * 1024) {
        final bytes = await file.readAsBytes();
        return (
          md5hex: md5.convert(bytes).toString(),
          sha1hex: sha1.convert(bytes).toString(),
        );
      }

      // Chunked for large files
      final md5Output = _DigestSink();
      final sha1Output = _DigestSink();
      final md5Conv = md5.startChunkedConversion(md5Output);
      final sha1Conv = sha1.startChunkedConversion(sha1Output);
      await for (final chunk in file.openRead()) {
        md5Conv.add(chunk);
        sha1Conv.add(chunk);
      }
      md5Conv.close();
      sha1Conv.close();
      return (
        md5hex: md5Output.value!.toString(),
        sha1hex: sha1Output.value!.toString(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Primeras [maxLines] líneas de un archivo de texto (solo lectura).
  static Future<String?> textPreview(String path, {int maxLines = 20}) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      final lines = <String>[];
      await for (final line in file
          .openRead()
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())) {
        lines.add(line);
        if (lines.length >= maxLines) break;
      }
      return lines.join('\n');
    } catch (_) {
      return null;
    }
  }

  static bool isImage(String ext) => imageExtensions.contains(ext.toLowerCase());

  static bool isText(String ext) => textExtensions.contains(ext.toLowerCase());

  static bool isApk(String ext) => ext.toLowerCase() == 'apk';

  /// Guarda bytes de icono APK en `.anythinghub/cache/icons/<key>.png`.
  static Future<File?> cacheIconBytes(String key, Uint8List bytes) async {
    try {
      final dir = await _iconsCacheDir();
      final safe = key.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final f = File(p.join(dir.path, '$safe.png'));
      await f.writeAsBytes(bytes, flush: true);
      return f;
    } catch (_) {
      return null;
    }
  }

  /// Lee icono cacheado si existe.
  static Future<File?> cachedIcon(String key) async {
    try {
      final dir = await _iconsCacheDir();
      final safe = key.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final f = File(p.join(dir.path, '$safe.png'));
      if (await f.exists()) return f;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Clave estable para un path de APK (hash del path + size).
  static String apkCacheKey(String path, int size) {
    final h = md5.convert(utf8.encode('$path|$size')).toString().substring(0, 16);
    return 'apk_$h';
  }
}

class _DigestSink implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}
