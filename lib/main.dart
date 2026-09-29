import 'package:flutter/material.dart';

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
  static const Color textoSecundario = Color(0xFF8F94A8); // Añadido para mejor jerarquía

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anythings Hub',
      debugShowCheckedModeBanner: false,

      // --- 🚀 CONFIGURACIÓN GLOBAL DEL TEMA (Aplica la paleta a toda la app) ---
      theme: ThemeData(
        // Usamos el modo oscuro base
        brightness: Brightness.dark,
        scaffoldBackgroundColor: fondoIndigoOscuroMate,

        // Definimos el ColorScheme oficial de la app
        colorScheme: const ColorScheme(
          brightness: Brightness.dark,
          
          // Fondo principal de la app (Scaffold)
          surface: fondoIndigoOscuroMate,
          
          // Color de fondo para tarjetas (Cards), diálogos, etc.
          onSurface: elementoSecundarioGrisIndigo,
          
          // Color principal para elementos destacados (Botones, switches activos)
          primary: acentoSuavePomeloApagado,
          
          // Color del texto principal sobre el color 'primary'
          onPrimary: fondoIndigoOscuroMate,
          
          // Otros colores necesarios para completar el esquema (usando tonos de la paleta o neutros)
          secondary: elementoSecundarioGrisIndigo,
          onSecondary: textoPrincipalClaro,
          error: Colors.redAccent,
          onError: Colors.white,
          
          // Fondo de las barras (AppBar, BottomNavigationBar)
          surfaceContainerHighest: elementoSecundarioGrisIndigo, 
        ),

        // Configuración Global de AppBar (aplica la paleta)
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

        // Configuración Global de Card (usa onSurface automáticamente)
        cardTheme: const CardTheme(
          color: elementoSecundarioGrisIndigo,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.radius12),
          ),
        ),

        // Configuración Global de Texto (usa los colores de texto)
        textTheme: const TextTheme(
          displayLarge: TextStyle(color: textoPrincipalClaro, fontSize: 32, fontWeight: FontWeight.bold),
          bodyLarge: TextStyle(color: textoPrincipalClaro, fontSize: 16),
          bodyMedium: TextStyle(color: textoSecundario, fontSize: 14),
        ),

        // Color del cursor y selección de texto
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: acentoSuavePomeloApagado,
          selectionColor: Color(0x80E0856F), // Pomelo semi-transparente
          selectionHandleColor: acentoSuavePomeloApagado,
        ),
        
        // Usamos el botón flotante por defecto con el color primario
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
    // Obtenemos el esquema de colores actual para usarlo dinámicamente
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Anythings Hub'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título usando el estilo de texto global
            Text(
              'Bienvenido de nuevo',
              style: textTheme.displayLarge,
            ),
            const SizedBox(height: 10),
            // Subtítulo usando el estilo de cuerpo medio global
            Text(
              'Tu centro de control total',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 30),

            // --- EJEMPLO DE USO DE LA PALETA ---

            // 1. Tarjeta (Card) usando el color de fondo de tarjeta definido en el tema
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

            // 2. Botón de Acción (ElevatedButton) usando el color primario
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Acción
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary, // Usa #E0856F
                  foregroundColor: colorScheme.onPrimary, // Usa #1E2238
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

             // 3. Botón de Texto (TextButton) usando el color primario
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
      // Botón flotante usando el tema por defecto
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Acción flotante
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

// --- 💡 CONSTANTE LOCAL PARA BORDES (Opcional, para limpieza) ---
const double radius12 = 12.0;
