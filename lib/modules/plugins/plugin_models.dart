/// Manifest de un plugin de Anythings Hub.
/// Solo metadatos / configuracion — no ejecuta codigo remoto.
class HubPluginManifest {
  const HubPluginManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.description,
    this.author = '',
    this.category = 'misc',
    this.tags = const [],
    this.homepage = '',
    this.minHubVersion = '1.0.0',
    this.permissions = const [],
    this.configSchema = const {},
    this.extendsFeature = '',
    this.capabilities = const [],
  });

  final String id;
  final String name;
  final String version;
  final String description;
  final String author;
  final String category;
  final List<String> tags;
  final String homepage;
  final String minHubVersion;
  final List<String> permissions;
  final Map<String, dynamic> configSchema;

  /// Feature del nucleo que este plugin amplía (ej. "performance-modes").
  final String extendsFeature;

  /// Capacidades declarativas (ej. "overlay", "fps-counter", "game-mode").
  /// La app solo lee metadatos; no ejecuta codigo del plugin.
  final List<String> capabilities;

  factory HubPluginManifest.fromJson(Map<String, dynamic> j) {
    return HubPluginManifest(
      id: (j['id'] as String?)?.trim() ?? '',
      name: (j['name'] as String?)?.trim() ?? 'Plugin',
      version: (j['version'] as String?)?.trim() ?? '0.0.0',
      description: (j['description'] as String?)?.trim() ?? '',
      author: (j['author'] as String?)?.trim() ?? '',
      category: (j['category'] as String?)?.trim() ?? 'misc',
      tags: (j['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      homepage: (j['homepage'] as String?)?.trim() ?? '',
      minHubVersion: (j['minHubVersion'] as String?)?.trim() ?? '1.0.0',
      permissions:
          (j['permissions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
              const [],
      configSchema: (j['configSchema'] as Map<String, dynamic>?) ?? const {},
      extendsFeature: (j['extendsFeature'] as String?)?.trim() ?? '',
      capabilities:
          (j['capabilities'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
              const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'version': version,
        'description': description,
        'author': author,
        'category': category,
        'tags': tags,
        'homepage': homepage,
        'minHubVersion': minHubVersion,
        'permissions': permissions,
        'configSchema': configSchema,
        'extendsFeature': extendsFeature,
        'capabilities': capabilities,
      };

  bool get isValid => id.isNotEmpty && name.isNotEmpty;

  bool get extendsPerfModes => extendsFeature == 'performance-modes';
  bool get offersOverlay => capabilities.contains('overlay');
  bool get offersFps => capabilities.contains('fps-counter');
  bool get offersGameMode => capabilities.contains('game-mode');
}

class HubPluginEntry {
  const HubPluginEntry({
    required this.manifest,
    required this.installed,
    this.localPath,
    this.catalogUrl,
  });

  final HubPluginManifest manifest;
  final bool installed;
  final String? localPath;
  final String? catalogUrl;
}
