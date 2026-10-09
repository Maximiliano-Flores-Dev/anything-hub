import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/hub_colors.dart';
import 'core/macro_customization.dart';
import 'modules/projects/services/oauth_deep_link_handler.dart';
import 'screens/main_layout_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MacroCustomization.instance.load();
  _applySystemUi();
  // Deep-link OAuth (solo activo cuando el módulo de proyectos se use)
  OAuthDeepLinkHandler.init();
  runApp(const AnythingsHubApp());
}

void _applySystemUi() {
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: HubColors.fondoPrincipal,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
}

class AnythingsHubApp extends StatefulWidget {
  const AnythingsHubApp({super.key});

  @override
  State<AnythingsHubApp> createState() => _AnythingsHubAppState();
}

class _AnythingsHubAppState extends State<AnythingsHubApp> {
  @override
  void initState() {
    super.initState();
    MacroCustomization.instance.addListener(_onMacroChanged);
  }

  @override
  void dispose() {
    MacroCustomization.instance.removeListener(_onMacroChanged);
    super.dispose();
  }

  void _onMacroChanged() {
    _applySystemUi();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anythings Hub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: HubColors.fondoPrincipal,
        colorScheme: ColorScheme(
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
