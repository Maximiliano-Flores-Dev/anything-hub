import 'package:flutter/material.dart';

// --- 💡 CONSTANTES GLOBALES DE ESTILO ---
const double radius12 = 12.0;

void main() {
  runApp(const AnythingsHubApp());
}

class AnythingsHubApp extends StatelessWidget {
  const AnythingsHubApp({super.key});

  // --- 🎨 PALETA DE COLORES ---
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
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: fondoIndigoOscuroMate,
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
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: textoPrincipalClaro),
          bodyMedium: TextStyle(color: textoSecundario),
        ),
      ),
      home: const MainLayoutScreen(),
    );
  }
}

// --- 📱 LAYOUT PRINCIPAL (Side Menu + Contenido + Footer) ---
class MainLayoutScreen extends StatefulWidget {
  const MainLayoutScreen({super.key});

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  int _selectedIndex = 0; // Para el Footer Navigation

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            // --- 📁 1. SIDE MENU (Izquierda) ---
            Container(
              width: 95,
              color: AnythingsHubApp.fondoIndigoOscuroMate,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSideMenuItem(Icons.access_time_rounded, "Recientes", true),
                  _buildSideMenuItem(Icons.folder_open_rounded, "Carpetas Frecuentes", false),
                  _buildSideMenuItem(Icons.web_rounded, "Webs Guardadas", false),
                  _buildSideMenuItem(Icons.apps_rounded, "Mis Aplicaciones", false),
                  _buildSideMenuItem(Icons.star_rounded, "Favoritos", false),
                ],
              ),
            ),

            // --- 🖥️ 2. CONTENIDO PRINCIPAL Y FOOTER ---
            Expanded(
              child: Column(
                children: [
                  // Área scrolleable del Dashboard (Título + 6 Tarjetas + Botón Gestión)
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Cabecera superior con título y engranaje
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Anythings Hub',
                                style: TextStyle(
                                  color: AnythingsHubApp.textoPrincipalClaro,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                onPressed: () {},
                                icon: const Icon(Icons.settings_outlined, color: AnythingsHubApp.textoPrincipalClaro),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Bienvenido de\nnuevo',
                            style: TextStyle(
                              color: AnythingsHubApp.textoPrincipalClaro,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Tu centro de control total',
                            style: TextStyle(
                              color: AnythingsHubApp.textoSecundario,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // --- 🧊 3. LAS 6 TARJETAS (Grid 2 columnas) ---
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.95,
                            children: const [
                              DashboardCard(
                                title: "Mis Aplicaciones",
                                subtitle: "Gestiona y abre tus apps",
                                iconOrMock: Icons.grid_view_rounded,
                              ),
                              DashboardCard(
                                title: "Carpetas del Proyecto",
                                subtitle: "Acceso rápido a tus proyectos",
                                iconOrMock: Icons.folder_special_rounded,
                              ),
                              DashboardCard(
                                title: "Webs Rápidas",
                                subtitle: "Tus sitios favoritos, al instante",
                                iconOrMock: Icons.public_rounded,
                              ),
                              DashboardCard(
                                title: "Favoritos",
                                subtitle: "Todo lo que te importa",
                                iconOrMock: Icons.star_border_rounded,
                              ),
                              DashboardCard(
                                title: "Gestión de Archivos",
                                subtitle: "Explora, organiza y accede rápido",
                                iconOrMock: Icons.folder_copy_rounded,
                              ),
                              DashboardCard(
                                title: "Modos de Rendimiento",
                                subtitle: "Ajusta el rendimiento de tu dispositivo",
                                iconOrMock: Icons.memory_rounded,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Botón principal "Gestionar Todo"
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AnythingsHubApp.acentoSuavePomeloApagado,
                                foregroundColor: AnythingsHubApp.fondoIndigoOscuroMate,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.settings, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Gestionar Todo',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Center(
                            child: Text(
                              'Ver detalles avanzados',
                              style: TextStyle(color: AnythingsHubApp.textoSecundario, fontSize: 12),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),

                  // --- 🧭 4. FOOTER MENU (Inferior) ---
                  Container(
                    height: 60,
                    decoration: const BoxDecoration(
                      color: AnythingsHubApp.fondoIndigoOscuroMate,
                      border: Border(
                        top: BorderSide(color: AnythingsHubApp.elementoSecundarioGrisIndigo, width: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        IconButton(
                          icon: Icon(Icons.home_rounded, color: _selectedIndex == 0 ? AnythingsHubApp.acentoSuavePomeloApagado : AnythingsHubApp.textoSecundario),
                          onPressed: () => setState(() => _selectedIndex = 0),
                        ),
                        IconButton(
                          icon: Icon(Icons.grid_view_rounded, color: _selectedIndex == 1 ? AnythingsHubApp.acentoSuavePomeloApagado : AnythingsHubApp.textoSecundario),
                          onPressed: () => setState(() => _selectedIndex = 1),
                        ),
                        IconButton(
                          icon: Icon(Icons.search_rounded, color: _selectedIndex == 2 ? AnythingsHubApp.acentoSuavePomeloApagado : AnythingsHubApp.textoSecundario),
                          onPressed: () => setState(() => _selectedIndex = 2),
                        ),
                        IconButton(
                          icon: Icon(Icons.person_outline_rounded, color: _selectedIndex == 3 ? AnythingsHubApp.acentoSuavePomeloApagado : AnythingsHubApp.textoSecundario),
                          onPressed: () => setState(() => _selectedIndex = 3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      // --- ➕ 5. BOTÓN FLOTANTE CON ACCESOS RÁPIDOS SIMULADOS ---
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: AnythingsHubApp.acentoSuavePomeloApagado,
        child: const Icon(Icons.add, color: AnythingsHubApp.fondoIndigoOscuroMate),
      ),
    );
  }

  // Widget auxiliar para los elementos del menú lateral
  Widget _buildSideMenuItem(IconData icon, String label, bool isActive) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isActive ? AnythingsHubApp.acentoSuavePomeloApagado.withOpacity(0.2) : AnythingsHubApp.elementoSecundarioGrisIndigo.withOpacity(0.4),
            borderRadius: BorderRadius.circular(radius12),
          ),
          child: Icon(
            icon,
            color: isActive ? AnythingsHubApp.acentoSuavePomeloApagado : AnythingsHubApp.textoPrincipalClaro,
            size: 24,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isActive ? AnythingsHubApp.textoPrincipalClaro : AnythingsHubApp.textoSecundario,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

// --- 🧱 WIDGET PARA LAS TARJETAS DEL DASHBOARD ---
class DashboardCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData iconOrMock;

  const DashboardCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.iconOrMock,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AnythingsHubApp.elementoSecundarioGrisIndigo,
        borderRadius: BorderRadius.circular(radius12),
      ),
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Espacio superior para la vista previa o icono simulado
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(iconOrMock, size: 36, color: AnythingsHubApp.acentoSuavePomeloApagado),
            ],
          ),
          // Textos de la tarjeta y flecha
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: AnythingsHubApp.textoPrincipalClaro,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 16, color: AnythingsHubApp.textoSecundario),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AnythingsHubApp.textoSecundario,
                  fontSize: 10,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
