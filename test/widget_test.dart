import 'package:flutter_test/flutter_test.dart';

import 'package:anything_hub/main.dart';

void main() {
  testWidgets('AnythingsHubApp builds', (WidgetTester tester) async {
    await tester.pumpWidget(const AnythingsHubApp());
    // Smoke test: la app monta sin crash.
    expect(find.byType(AnythingsHubApp), findsOneWidget);
  });
}
