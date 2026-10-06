import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anything_hub/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AnythingsHubApp builds', (WidgetTester tester) async {
    // Smoke test: monta la app. Puede haber excepciones de plugins
    // (secure storage, path_provider, etc.) en test; no deben tumbar el CI.
    await tester.pumpWidget(const AnythingsHubApp());
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(AnythingsHubApp), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  }, skip: false);
}
