import 'dart:typed_data';

/// Tipo de ítem favorito unificado.
enum FavoriteType {
  app,
  web,
  file,
}

extension FavoriteTypeLabel on FavoriteType {
  String get label {
    switch (this) {
      case FavoriteType.app:
        return 'App';
      case FavoriteType.web:
        return 'Web';
      case FavoriteType.file:
        return 'Archivo';
    }
  }

  String get sectionTitle {
    switch (this) {
      case FavoriteType.app:
        return 'Apps';
      case FavoriteType.web:
        return 'Webs';
      case FavoriteType.file:
        return 'Archivos';
    }
  }

  int get sectionOrder {
    switch (this) {
      case FavoriteType.app:
        return 0;
      case FavoriteType.web:
        return 1;
      case FavoriteType.file:
        return 2;
    }
  }
}

/// Ítem unificado de la colección de favoritos.
class FavoriteItem {
  const FavoriteItem({
    required this.type,
    required this.id,
    required this.title,
    required this.favoritedAt,
    this.subtitle,
    this.iconBytes,
    this.packageName,
    this.url,
    this.path,
    this.isDirectory = false,
  });

  final FavoriteType type;

  /// Identificador estable: packageName | web id | path
  final String id;

  final String title;
  final String? subtitle;
  final DateTime favoritedAt;

  /// Ícono real de la app (PNG) cuando type == app.
  final Uint8List? iconBytes;

  final String? packageName;
  final String? url;
  final String? path;

  /// Solo relevante para type == file.
  final bool isDirectory;

  String get metaKey => '${type.name}:$id';

  bool get hasKnownDate => favoritedAt.millisecondsSinceEpoch > 0;

  FavoriteItem copyWith({DateTime? favoritedAt, bool? isDirectory}) {
    return FavoriteItem(
      type: type,
      id: id,
      title: title,
      favoritedAt: favoritedAt ?? this.favoritedAt,
      subtitle: subtitle,
      iconBytes: iconBytes,
      packageName: packageName,
      url: url,
      path: path,
      isDirectory: isDirectory ?? this.isDirectory,
    );
  }
}

/// Ordenación (sin el antiguo "Por tipo", que ahora es filtro).
enum FavoriteSort {
  alphaAsc,
  recent,
  oldest,
}

extension FavoriteSortLabel on FavoriteSort {
  String get label {
    switch (this) {
      case FavoriteSort.alphaAsc:
        return 'A → 9';
      case FavoriteSort.recent:
        return 'Recientes';
      case FavoriteSort.oldest:
        return 'Antiguos';
    }
  }
}
