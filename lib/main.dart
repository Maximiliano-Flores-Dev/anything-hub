import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/hub_colors.dart';
import 'modules/projects/services/oauth_deep_link_handler.dart';
import 'screens/main_layout_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: HubColors.fondoPrincipal,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  // Deep-link OAuth (solo activo cuando el módulo de proyectos se use)
  OAuthDeepLinkHandler.init();
  runApp(const AnythingsHubApp());
}

class AnythingsHubApp extends StatelessWidget {
  const AnythingsHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anythings Hub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: HubColors.fondoPrincipal,
        colorScheme: const ColorScheme(
          brightness: Brightness.dark,
          surface: HubColors.fondoPrincipal,
          onSurface: HubColors.textoPrincipal,
          primary: HubColors.pomelo,
          onPrimary: HubColors.fondoPrincipal,
          secondary: HubColors.panel,
          onSecondary: HubColors.textoPrincipal,
          error: Colors.redAccent,
          onError: Colors.white,
        ),
      ),
      home: const MainLayoutScreen(),
    );
  }
}
