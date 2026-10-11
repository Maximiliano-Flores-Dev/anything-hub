import 'package:flutter/services.dart';

import '../core/logger.dart';

/// Metadatos de un archivo o carpeta listado por el puente nativo.
class FileEntry {
  const FileEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.size,
    required this.modifiedMs,
    this.mimeType,
  });

  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final int modifiedMs;
  final String? mimeType;

  String get extension {
    final i = name.lastIndexOf('.');
    if (i < 0 || i == name.length - 1) return '';
    return name.substring(i + 1);
  }

  bool matchesType(FileFilter filter) {
    if (filter == FileFilter.all) return true;
    if (isDirectory) return filter == FileFilter.folders;
    final ext = extension.toLowerCase();
    switch (filter) {
      case FileFilter.folders:
        return false;
      case FileFilter.images:
        return const {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic'}.contains(ext);
      case FileFilter.videos:
        return const {'mp4', 'mkv', 'avi', 'webm', 'mov', '3gp'}.contains(ext);
      case FileFilter.audio:
        return const {'mp3', 'wav', 'flac', 'ogg', 'm4a', 'aac'}.contains(ext);
      case FileFilter.documents:
        return const {'pdf', 'txt', 'md', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'csv'}.contains(ext);
      case FileFilter.archives:
        return const {'zip', 'rar', '7z', 'tar', 'gz'}.contains(ext);
      case FileFilter.apks:
        return ext == 'apk';
      case FileFilter.all:
        return true;
    }
  }

  factory FileEntry.fromMap(Map<dynamic, dynamic> m) {
    return FileEntry(
      name: m['name'] as String? ?? '',
      path: m['path'] as String? ?? '',
      isDirectory: m['isDirectory'] == true,
      size: (m['size'] as num?)?.toInt() ?? 0,
      modifiedMs: (m['modifiedMs'] as num?)?.toInt() ?? 0,
      mimeType: m['mimeType'] as String?,
    );
  }
}

enum FileFilter { all, folders, images, videos, audio, documents, archives, apks }

class StorageInfo {
  const StorageInfo({required this.totalBytes, required this.freeBytes});
  final int totalBytes;
  final int freeBytes;
  double get usedRatio => totalBytes == 0 ? 0 : 1 - (freeBytes / totalBytes);
}

/// Puente a DeviceFilesBridge.kt
class DeviceFilesService {
  static const _ch = MethodChannel('com.anything.hub/files');

  static Future<bool> hasPermission() async {
    try {
      return await _ch.invokeMethod<bool>('hasPermission') ?? false;
    } catch (e) {
      SystemLogger.log('hasPermission files: $e');
      return false;
    }
  }

  static Future<void> openPermissionSettings() async {
    try {
      await _ch.invokeMethod('openPermissionSettings');
    } catch (e) {
      SystemLogger.log('openPermissionSettings files: $e');
    }
  }

  static Future<List<Map<String, String>>> getRoots() async {
    try {
      final raw = await _ch.invokeMethod<List<dynamic>>('getRoots');
      if (raw == null) return [];
      return raw.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return {
          'path': m['path'] as String? ?? '',
          'label': m['label'] as String? ?? '',
        };
      }).toList();
    } catch (e) {
      SystemLogger.log('getRoots: $e');
      return [];
    }
  }

  static Future<List<FileEntry>?> listDirectory(String path, {bool showHidden = false}) async {
    try {
      final raw = await _ch.invokeMethod<List<dynamic>>('listDirectory', {
        'path': path,
        'showHidden': showHidden,
      });
      if (raw == null) return null;
      return raw.map((e) => FileEntry.fromMap(e as Map)).toList();
    } catch (e) {
      SystemLogger.log('listDirectory: $e');
      return null;
    }
  }

  static Future<StorageInfo?> getStorageInfo(String path) async {
    try {
      final raw = await _ch.invokeMethod<Map<dynamic, dynamic>>('getStorageInfo', {'path': path});
      if (raw == null) return null;
      return StorageInfo(
        totalBytes: (raw['totalBytes'] as num?)?.toInt() ?? 0,
        freeBytes: (raw['freeBytes'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      SystemLogger.log('getStorageInfo: $e');
      return null;
    }
  }

  static Future<bool> createDirectory(String path) async {
    try {
      return await _ch.invokeMethod<bool>('createDirectory', {'path': path}) ?? false;
    } catch (e) {
      SystemLogger.log('createDirectory: $e');
      return false;
    }
  }

  static Future<bool> createFile(String path) async {
    try {
      return await _ch.invokeMethod<bool>('createFile', {'path': path}) ?? false;
    } catch (e) {
      SystemLogger.log('createFile: $e');
      return false;
    }
  }

  static Future<bool> renameEntry(String path, String newName) async {
    try {
      return await _ch.invokeMethod<bool>('rename', {'path': path, 'newName': newName}) ?? false;
    } catch (e) {
      SystemLogger.log('rename: $e');
      return false;
    }
  }

  static Future<bool> deleteEntry(String path) async {
    try {
      return await _ch.invokeMethod<bool>('delete', {'path': path}) ?? false;
    } catch (e) {
      SystemLogger.log('delete: $e');
      return false;
    }
  }

  static Future<bool> copyEntry(String src, String dest) async {
    try {
      return await _ch.invokeMethod<bool>('copy', {'src': src, 'dest': dest}) ?? false;
    } catch (e) {
      SystemLogger.log('copy: $e');
      return false;
    }
  }

  static Future<bool> moveEntry(String src, String dest) async {
    try {
      return await _ch.invokeMethod<bool>('move', {'src': src, 'dest': dest}) ?? false;
    } catch (e) {
      SystemLogger.log('move: $e');
      return false;
    }
  }
}
