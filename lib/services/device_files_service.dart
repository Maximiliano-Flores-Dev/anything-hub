import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../core/logger.dart';

enum FileFilter { all, folders, images, videos, audio, documents, archives, apks }

class FileEntry {
  const FileEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.size,
    required this.modifiedMs,
    this.extension = '',
  });

  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final int modifiedMs;
  final String extension;

  DateTime get modified => DateTime.fromMillisecondsSinceEpoch(modifiedMs);

  String get sizeLabel {
    if (isDirectory) return 'Carpeta';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  static FileEntry fromMap(Map m) => FileEntry(
        name: m['name'] as String,
        path: m['path'] as String,
        isDirectory: m['isDir'] == true,
        size: (m['size'] as num?)?.toInt() ?? 0,
        modifiedMs: (m['modified'] as num?)?.toInt() ?? 0,
        extension: (m['ext'] as String?) ?? '',
      );

  bool matchesType(FileFilter filter) {
    if (filter == FileFilter.all) return true;
    if (isDirectory) return filter == FileFilter.folders;
    final e = extension.toLowerCase();
    switch (filter) {
      case FileFilter.images:
        return const {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic', 'svg'}
            .contains(e);
      case FileFilter.videos:
        return const {'mp4', 'mkv', 'avi', 'mov', 'webm', '3gp', 'flv'}.contains(e);
      case FileFilter.audio:
        return const {'mp3', 'wav', 'flac', 'aac', 'ogg', 'm4a', 'wma'}.contains(e);
      case FileFilter.documents:
        return const {
          'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'md', 'rtf', 'csv'
        }.contains(e);
      case FileFilter.archives:
        return const {'zip', 'rar', '7z', 'tar', 'gz', 'bz2'}.contains(e);
      case FileFilter.apks:
        return e == 'apk';
      case FileFilter.folders:
        return false;
      case FileFilter.all:
        return true;
    }
  }
}

class StorageInfo {
  const StorageInfo({required this.totalBytes, required this.freeBytes});
  final int totalBytes;
  final int freeBytes;
  int get usedBytes => totalBytes - freeBytes;
  double get usedRatio => totalBytes == 0 ? 0 : usedBytes / totalBytes;

  String get totalLabel => _fmt(totalBytes);
  String get freeLabel => _fmt(freeBytes);
  String get usedLabel => _fmt(usedBytes);

  static String _fmt(int b) {
    if (b < 1024 * 1024 * 1024) return '${(b / (1024 * 1024)).toStringAsFixed(0)} MB';
    return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

class DeviceFilesService {
  static const MethodChannel _ch = MethodChannel('anythings.hub/device_files');

  static Future<T?> _call<T>(String method, [dynamic args]) async {
    try {
      SystemLogger.channel('device_files', method);
      return await _ch.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      SystemLogger.log('Canal archivos "$method" falló: ${e.message}');
      return null;
    }
  }

  static Future<bool> hasPermission() async =>
      await _call<bool>('hasStoragePermission') ?? false;

  static Future<void> openPermissionSettings() async {
    await _call<Object?>('openStoragePermissionSettings');
  }

  static Future<List<Map<String, String>>> getRoots() async {
    final raw = await _call<List<dynamic>>('getRoots');
    if (raw == null) return [];
    return raw.whereType<Map>().map((m) => {
          'label': m['label'] as String? ?? '',
          'path': m['path'] as String? ?? '',
        }).toList();
  }

  static Future<StorageInfo?> getStorageInfo(String path) async {
    final raw = await _call<Map>('getStorageInfo', {'path': path});
    if (raw == null) return null;
    return StorageInfo(
      totalBytes: (raw['total'] as num?)?.toInt() ?? 0,
      freeBytes: (raw['free'] as num?)?.toInt() ?? 0,
    );
  }

  static Future<List<FileEntry>?> listDirectory(
    String path, {
    bool showHidden = false,
  }) async {
    final raw = await _call<List<dynamic>>('listDirectory', {
      'path': path,
      'showHidden': showHidden,
    });
    if (raw == null) return null;
    return raw.whereType<Map>().map(FileEntry.fromMap).toList();
  }

  static Future<bool> createDirectory(String path) async =>
      await _call<bool>('createDirectory', {'path': path}) ?? false;

  static Future<bool> createFile(String path) async =>
      await _call<bool>('createFile', {'path': path}) ?? false;

  static Future<bool> deleteEntry(String path) async =>
      await _call<bool>('delete', {'path': path}) ?? false;

  static Future<bool> renameEntry(String path, String newName) async =>
      await _call<bool>('rename', {'path': path, 'newName': newName}) ?? false;

  static Future<bool> copyEntry(String src, String dest) async =>
      await _call<bool>('copy', {'src': src, 'dest': dest}) ?? false;

  static Future<bool> moveEntry(String src, String dest) async =>
      await _call<bool>('move', {'src': src, 'dest': dest}) ?? false;

  static Future<bool> openFile(String path) async =>
      await _call<bool>('openFile', {'path': path}) ?? false;

  static Future<bool> shareFile(String path) async =>
      await _call<bool>('shareFile', {'path': path}) ?? false;
}

/// Límites de operaciones masivas (Code Hardening).
class FileOpGuard {
  static const int maxBatchItems = 100;
  static const int maxOpsPerMinute = 200;

  static final List<DateTime> _window = [];

  static String? checkBatch(int count, {String op = 'operación'}) {
    if (count <= 0) return 'Nada que procesar';
    if (count > maxBatchItems) {
      return 'Máximo $maxBatchItems elementos por $op. '
          'Seleccionaste $count.';
    }
    _prune();
    if (_window.length + count > maxOpsPerMinute) {
      return 'Demasiadas operaciones en poco tiempo '
          '(máx $maxOpsPerMinute/min). Espera un momento.';
    }
    return null;
  }

  static void record(int count) {
    final now = DateTime.now();
    for (var i = 0; i < count; i++) {
      _window.add(now);
    }
    _prune();
  }

  static void _prune() {
    final cutoff = DateTime.now().subtract(const Duration(minutes: 1));
    _window.removeWhere((t) => t.isBefore(cutoff));
  }
}
