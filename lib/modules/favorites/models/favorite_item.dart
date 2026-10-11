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

  /// Orden de secciones por defecto.
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
  });

  final FavoriteType type;

  /// Identificador estable: packageName | web id | path
  final String id;

  final String title;
  final String? subtitle;
  final DateTime favoritedAt;

  /// Ícono real de la app (PNG) cuando type == app.
  final Uint8List? iconBytes;

  // Datos de acción según tipo
  final String? packageName;
  final String? url;
  final String? path;

  /// Clave usada para timestamps en SharedPreferences.
  String get metaKey => '${type.name}:$id';

  FavoriteItem copyWith({DateTime? favoritedAt}) {
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
    );
  }
}

/// Opciones de ordenación de la lista de favoritos.
enum FavoriteSort {
  alphaAsc,   // A → 9
  recent,     // más reciente primero
  oldest,     // más antiguo primero
  byType,     // solo reordena secciones (orden fijo de tipos)
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
      case FavoriteSort.byType:
        return 'Por tipo';
    }
  }
}
