import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anything_hub/core/hub_colors.dart';

/// Smoke test ligero: no monta la app completa (plugins nativos fallan en CI).
void main() {
  testWidgets('MaterialApp con tema Hub monta sin crash', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: HubColors.fondoPrincipal,
        ),
        home: const Scaffold(
          body: Center(child: Text('Anythings Hub')),
        ),
      ),
    );
    expect(find.text('Anythings Hub'), findsOneWidget);
  });
}
