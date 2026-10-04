import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'modules/projects/services/oauth_deep_link_handler.dart';

// PLACEHOLDER temporal. Restaura el main completo:
//   cat docs/main_b64_part*.txt | base64 -d | gzip -d > lib/main.dart
// O:
//   git checkout 708596b3b42c1d02f47a61677eef76187860e2ef -- lib/main.dart
//   y aplica docs/MAIN_DART_INTEGRATION.md

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  OAuthDeepLinkHandler.init();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: Color(0xFF040A16),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Restaura lib/main.dart\n\n'
            'cat docs/main_b64_part*.txt | base64 -d | gzip -d > lib/main.dart\n\n'
            'Ver docs/RESTORE_MAIN.md',
            style: TextStyle(color: Colors.white, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  ));
}
