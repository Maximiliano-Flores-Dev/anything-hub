import 'package:flutter_test/flutter_test.dart';
import 'package:anything_hub/modules/projects/models/project_md.dart';

void main() {
  group('ProjectMd', () {
    test('toMarkdown / fromMarkdown round-trip', () {
      final original = ProjectMd(
        name: 'Mi Proyecto',
        id: '550e8400-e29b-41d4-a716-446655440000',
        created: DateTime.utc(2026, 10, 4, 16, 35),
        lastOpened: DateTime.utc(2026, 10, 4, 17, 0),
        tags: const ['android', 'kotlin'],
        editor: 'acode',
        language: 'kotlin',
        description: 'Descripción de prueba',
        notes: 'Notas de prueba',
      );

      final md = original.toMarkdown();
      final parsed = ProjectMd.fromMarkdown(md);

      expect(parsed, isNotNull);
      expect(parsed!.name, original.name);
      expect(parsed.id, original.id);
      expect(parsed.editor, 'acode');
      expect(parsed.language, 'kotlin');
      expect(parsed.tags, containsAll(['android', 'kotlin']));
      expect(parsed.description, contains('Descripción de prueba'));
      expect(parsed.notes, contains('Notas de prueba'));
    });

    test('fromMarkdown returns null on invalid content', () {
      expect(ProjectMd.fromMarkdown('sin front-matter'), isNull);
      expect(ProjectMd.fromMarkdown('---\nname: x\n---\n'), isNull);
    });

    test('copyWith preserves id and updates fields', () {
      final base = ProjectMd(
        name: 'A',
        id: 'id-1',
        created: DateTime.utc(2026, 1, 1),
        editor: 'acode',
      );
      final updated = base.copyWith(
        name: 'B',
        editor: 'vscode.dev',
        lastOpened: DateTime.utc(2026, 2, 1),
      );
      expect(updated.id, 'id-1');
      expect(updated.name, 'B');
      expect(updated.editor, 'vscode.dev');
      expect(updated.lastOpened, DateTime.utc(2026, 2, 1));
    });
  });
}
