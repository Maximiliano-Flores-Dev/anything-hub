import 'package:flutter/material.dart';

// --- 💡 CONSTANTES GLOBALES DE ESTILO ---
const double radius12 = 12.0; // Definida aquí para ser accesible globalmente

void main() {
  runApp(const AnythingsHubApp());
}

class AnythingsHubApp extends StatelessWidget {
  const AnythingsHubApp({super.key});

  // --- 🎨 DEFINICIÓN DE LA PALETA DE COLORES (Tus Hex Codes) ---
  static const Color fondoIndigoOscuroMate = Color(0xFF1E2238);
  static const Color elementoSecundarioGrisIndigo = Color(0xFF3A415A);
  static const Color acentoSuavePomeloApagado = Color(0xFFE0856F);
  static const Color textoPrincipalClaro = Color(0xFFC5C9D6);
  static const Color textoSecundario = Color(0xFF8F94A8);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anythings Hub',
      debugShowCheckedModeBanner: false,

      // --- 🚀 CONFIGURACIÓN GLOBAL DEL TEMA ---
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: fondoIndigoOscuroMate,

        // Definimos el ColorScheme oficial
        colorScheme: const ColorScheme(
          brightness: Brightness.dark,
          surface: fondoIndigoOscuroMate,
          onSurface: elementoSecundarioGrisIndigo,
          primary: acentoSuavePomeloApagado,
          onPrimary: fondoIndigoOscuroMate,
          secondary: elementoSecundarioGrisIndigo,
          onSecondary: textoPrincipalClaro,
          error: Colors.redAccent,
          onError: Colors.white,
          surfaceContainerHighest: elementoSecundarioGrisIndigo,
        ),

        // Configuración Global de AppBar
        appBarTheme: const AppBarTheme(
          backgroundColor: fondoIndigoOscuroMate,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: textoPrincipalClaro,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: textoPrincipalClaro),
        ),

        // Configuración Global de Card (USA LA CORRECCIÓN DE RADIUS AQUÍ)
        cardTheme: const CardTheme(
          color: elementoSecundarioGrisIndigo,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(radius12)), // ¡CORREGIDO!
          ),
        ),

        // Configuración Global de Texto
        textTheme: const TextTheme(
          displayLarge: TextStyle(color: textoPrincipalClaro, fontSize: 32, fontWeight: FontWeight.bold),
          bodyLarge: TextStyle(color: textoPrincipalClaro, fontSize: 16),
          bodyMedium: TextStyle(color: textoSecundario, fontSize: 14),
        ),

        // Color del cursor y selección
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: acentoSuavePomeloApagado,
          selectionColor: Color(0x80E0856F),
          selectionHandleColor: acentoSuavePomeloApagado,
        ),

        // Botón flotante
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: acentoSuavePomeloApagado,
          foregroundColor: fondoIndigoOscuroMate,
        ),
      ),

      home: const HomeScreen(),
    );
  }
}

// --- 🏠 PANTALLA DE INICIO DE EJEMPLO ---
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Anythings Hub'),
      ),
      body: SingleChildScrollView( // Añadido para evitar desbordamiento si hay mucho contenido
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bienvenido de nuevo',
              style: textTheme.displayLarge,
            ),
            const SizedBox(height: 10),
            Text(
              'Tu centro de control total',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 30),

            // --- EJEMPLO DE USO DE LA PALETA ---

            // 1. Tarjeta (Card)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.insights_rounded, color: AnythingsHubApp.textoPrincipalClaro, size: 40,),
                        SizedBox(width: 15,),
                        Expanded(
                          child: Text(
                            'Resumen de actividad',
                            style: TextStyle(color: AnythingsHubApp.textoPrincipalClaro, fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 15,),
                    LinearProgressIndicator(
                      value: 0.65,
                      backgroundColor: AnythingsHubApp.fondoIndigoOscuroMate,
                      valueColor: AlwaysStoppedAnimation<Color>(AnythingsHubApp.acentoSuavePomeloApagado),
                    ),
                    SizedBox(height: 10,),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text('65% completado', style: TextStyle(color: AnythingsHubApp.textoSecundario),),
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 2. Botón de Acción (ElevatedButton)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Acción
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'Gestionar Todo',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 20),

             // 3. Botón de Texto (TextButton)
            Center(
              child: TextButton(
                onPressed: () {
                  // Acción secundaria
                },
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.primary,
                ),
                child: const Text('Ver detalles avanzados'),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Acción flotante
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
