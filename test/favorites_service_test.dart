import 'package:flutter_test/flutter_test.dart';

import 'package:anything_hub/modules/favorites/models/favorite_item.dart';
import 'package:anything_hub/modules/favorites/services/favorites_service.dart';

void main() {
  late FavoritesService service;

  setUp(() {
    service = FavoritesService();
  });

  FavoriteItem item({
    required FavoriteType type,
    required String id,
    required String title,
    required DateTime at,
  }) {
    return FavoriteItem(
      type: type,
      id: id,
      title: title,
      favoritedAt: at,
      packageName: type == FavoriteType.app ? id : null,
      url: type == FavoriteType.web ? 'https://example.com' : null,
      path: type == FavoriteType.file ? '/storage/$id' : null,
    );
  }

  final t0 = DateTime(2026, 1, 1);
  final t1 = DateTime(2026, 2, 1);
  final t2 = DateTime(2026, 3, 1);

  List<FavoriteItem> sample() => [
        item(type: FavoriteType.app, id: 'com.a', title: 'Zebra', at: t0),
        item(type: FavoriteType.app, id: 'com.b', title: 'Alpha', at: t2),
        item(type: FavoriteType.web, id: 'w1', title: 'GitHub', at: t1),
        item(type: FavoriteType.file, id: 'docs', title: 'Docs', at: t0),
      ];

  group('groupAndSort', () {
    test('alphaAsc ordena por título dentro de cada sección', () {
      final g = service.groupAndSort(sample(), FavoriteSort.alphaAsc);
      expect(g[FavoriteType.app]!.map((e) => e.title).toList(), ['Alpha', 'Zebra']);
    });

    test('recent ordena por fecha descendente', () {
      final g = service.groupAndSort(sample(), FavoriteSort.recent);
      expect(g[FavoriteType.app]!.map((e) => e.title).toList(), ['Alpha', 'Zebra']);
    });

    test('oldest ordena por fecha ascendente', () {
      final g = service.groupAndSort(sample(), FavoriteSort.oldest);
      expect(g[FavoriteType.app]!.map((e) => e.title).toList(), ['Zebra', 'Alpha']);
    });

    test('typeFilter deja solo un tipo', () {
      final g = service.groupAndSort(
        sample(),
        FavoriteSort.alphaAsc,
        typeFilter: FavoriteType.web,
      );
      expect(g.keys.toList(), [FavoriteType.web]);
      expect(g[FavoriteType.web]!.length, 1);
      expect(g[FavoriteType.web]!.first.title, 'GitHub');
    });

    test('secciones vacías no aparecen', () {
      final onlyApps = sample().where((e) => e.type == FavoriteType.app).toList();
      final g = service.groupAndSort(onlyApps, FavoriteSort.alphaAsc);
      expect(g.containsKey(FavoriteType.web), isFalse);
      expect(g.containsKey(FavoriteType.file), isFalse);
      expect(g.containsKey(FavoriteType.app), isTrue);
    });
  });

  group('FavoriteItem', () {
    test('metaKey incluye tipo e id', () {
      final a = item(type: FavoriteType.app, id: 'com.x', title: 'X', at: t0);
      expect(a.metaKey, 'app:com.x');
    });

    test('hasKnownDate es false para epoch', () {
      final a = item(
        type: FavoriteType.app,
        id: 'com.x',
        title: 'X',
        at: DateTime.fromMillisecondsSinceEpoch(0),
      );
      expect(a.hasKnownDate, isFalse);
    });
  });
}
