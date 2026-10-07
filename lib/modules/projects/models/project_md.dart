/// Modelo oficial de `project.md` según el plan v2.0.
/// Parser tolerante: YAML front-matter + cuerpo Markdown.
class ProjectMd {
  ProjectMd({
    required this.name,
    required this.id,
    required this.created,
    this.lastOpened,
    this.tags = const [],
    this.editor = 'acode',
    this.termuxPath,
    this.language,
    this.description = '',
    this.commands = const {},
    this.notes = '',
  });

  final String name;
  final String id;
  final DateTime created;
  DateTime? lastOpened;
  final List<String> tags;
  final String editor;
  final String? termuxPath;
  final String? language;
  final String description;
  final Map<String, String> commands;
  final String notes;

  String toMarkdown() {
    final tagsStr = tags.isEmpty ? '[]' : '[${tags.join(', ')}]';
    final buf = StringBuffer()
      ..writeln('---')
      ..writeln('name: $name')
      ..writeln('id: $id')
      ..writeln('created: ${created.toIso8601String()}')
      ..writeln('last_opened: ${(lastOpened ?? created).toIso8601String()}')
      ..writeln('tags: $tagsStr')
      ..writeln('editor: $editor');
    if (termuxPath != null && termuxPath!.isNotEmpty) {
      buf.writeln('termux_path: $termuxPath');
    }
    if (language != null && language!.isNotEmpty) {
      buf.writeln('language: $language');
    }
    buf
      ..writeln('---')
      ..writeln()
      ..writeln('# Descripción')
      ..writeln(description.isEmpty ? 'Breve descripción del proyecto.' : description)
      ..writeln()
      ..writeln('## Comandos útiles');
    if (commands.isEmpty) {
      buf
        ..writeln('- build: `./gradlew assembleDebug`')
        ..writeln('- test: `./gradlew test`')
        ..writeln('- run: `./gradlew installDebug`');
    } else {
      commands.forEach((k, v) => buf.writeln('- $k: `$v`'));
    }
    buf
      ..writeln()
      ..writeln('## Notas')
      ..writeln(notes.isEmpty ? 'Cualquier nota adicional del desarrollador.' : notes);
    return buf.toString();
  }

  static ProjectMd? fromMarkdown(String content) {
    try {
      final parts = content.split(RegExp(r'^---\s*$', multiLine: true));
      if (parts.length < 3) return null;
      final front = parts[1].trim();
      final body = parts.sublist(2).join('---').trim();
      final map = <String, String>{};
      for (final line in front.split('\n')) {
        final idx = line.indexOf(':');
        if (idx <= 0) continue;
        final key = line.substring(0, idx).trim();
        var val = line.substring(idx + 1).trim();
        if ((val.startsWith('"') && val.endsWith('"')) ||
            (val.startsWith("'") && val.endsWith("'"))) {
          val = val.substring(1, val.length - 1);
        }
        map[key] = val;
      }
      final name = map['name'] ?? 'Sin nombre';
      final id = map['id'] ?? '';
      if (id.isEmpty) return null;
      DateTime created;
      try {
        created = DateTime.parse(map['created'] ?? '');
      } catch (_) {
        created = DateTime.now();
      }
      DateTime? lastOpened;
      try {
        final raw = map['last_opened'];
        if (raw != null && raw.isNotEmpty) {
          lastOpened = DateTime.parse(raw);
        }
      } catch (_) {}
      List<String> tags = [];
      final tagsRaw = map['tags'] ?? '[]';
      if (tagsRaw.startsWith('[') && tagsRaw.endsWith(']')) {
        tags = tagsRaw
            .substring(1, tagsRaw.length - 1)
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      String description = '';
      String notes = '';
      final descMatch = RegExp(
        r'# Descripción\s*\n([\s\S]*?)(?=\n## |\n# |$)',
        multiLine: true,
      ).firstMatch(body);
      if (descMatch != null) {
        description = descMatch.group(1)!.trim();
      }
      final notesMatch = RegExp(
        r'## Notas\s*\n([\s\S]*?)(?=\n## |$)',
        multiLine: true,
      ).firstMatch(body);
      if (notesMatch != null) {
        notes = notesMatch.group(1)!.trim();
      }
      // Preserve ## Commands / ## Comandos útiles so updateLastOpened does not wipe them
      final commands = <String, String>{};
      final cmdsMatch = RegExp(
        r'## (?:Commands|Comandos útiles)\s*\n([\s\S]*?)(?=\n## |$)',
        multiLine: true,
      ).firstMatch(body);
      if (cmdsMatch != null) {
        final block = cmdsMatch.group(1)!;
        final lineRe = RegExp(r'^-\s*([^:]+):\s*`([^`]*)`');
        for (final line in block.split('\n')) {
          final m = lineRe.firstMatch(line.trim());
          if (m != null) {
            commands[m.group(1)!.trim()] = m.group(2)!;
          }
        }
      }
      return ProjectMd(
        name: name,
        id: id,
        created: created,
        lastOpened: lastOpened,
        tags: tags,
        editor: map['editor'] ?? 'acode',
        termuxPath: map['termux_path'],
        language: map['language'],
        description: description,
        notes: notes,
        commands: commands,
      );
    } catch (_) {
      return null;
    }
  }

  ProjectMd copyWith({
    String? name,
    DateTime? lastOpened,
    List<String>? tags,
    String? editor,
    String? termuxPath,
    String? language,
    String? description,
    Map<String, String>? commands,
    String? notes,
  }) {
    return ProjectMd(
      name: name ?? this.name,
      id: id,
      created: created,
      lastOpened: lastOpened ?? this.lastOpened,
      tags: tags ?? this.tags,
      editor: editor ?? this.editor,
      termuxPath: termuxPath ?? this.termuxPath,
      language: language ?? this.language,
      description: description ?? this.description,
      commands: commands ?? this.commands,
      notes: notes ?? this.notes,
    );
  }
}
