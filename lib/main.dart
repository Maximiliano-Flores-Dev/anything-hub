import 'package:flutter/material.dart';

const double radius12 = 12.0;

void main() {
  runApp(const AnythingsHubApp());
}

class AnythingsHubApp extends StatelessWidget {
  const AnythingsHubApp({super.key});

  // Nuevos tonos solicitados para la jerarquía de UI
  static const Color fondoSidebar = Color(0xFF060B11);
  static const Color fondoPrincipal = Color(0xFF040508);
  
  static const Color elementoSecundarioGrisIndigo = Color(0xFF1A2232);
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
        scaffoldBackgroundColor: fondoPrincipal,
        colorScheme: const ColorScheme(
          brightness: Brightness.dark,
          surface: fondoPrincipal,
          onSurface: elementoSecundarioGrisIndigo,
          primary: acentoSuavePomeloApagado,
          onPrimary: fondoPrincipal,
          secondary: elementoSecundarioGrisIndigo,
          onSecondary: textoPrincipalClaro,
          error: Colors.redAccent,
          onError: Colors.white,
        ),
      ),
      home: const MainLayoutScreen(),
    );
  }
}

class MainLayoutScreen extends StatefulWidget {
  const MainLayoutScreen({super.key});

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Obtenemos el ancho total de la pantalla del dispositivo
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AnythingsHubApp.fondoPrincipal,
      body: SafeArea(
        child: Row(
          children: [
            // --- SIDEBAR (Ocupa un porcentaje menor y dinámico: ~15% por defecto, expandible a ~30%) ---
            CollapsibleSidebar(screenWidth: screenWidth),

            // --- CONTENIDO PRINCIPAL (Protagonista absoluto: ~85% a ~70% de la pantalla) ---
            Expanded(
              child: Container(
                color: AnythingsHubApp.fondoPrincipal,
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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

                            // --- GRID DE 6 TARJETAS CON ASSETS ---
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
                                  assetPath: "assets/images/ChatGPT Image 29 sept 2026, 08_55_20 p.m..png",
                                ),
                                DashboardCard(
                                  title: "Carpetas del Proyecto",
                                  subtitle: "Acceso rápido a tus proyectos",
                                  assetPath: "assets/images/ChatGPT Image 29 sept 2026, 08_57_55 p.m..png",
                                ),
                                DashboardCard(
                                  title: "Webs Rápidas",
                                  subtitle: "Tus sitios favoritos, al instante",
                                  assetPath: "assets/images/ChatGPT Image 29 sept 2026, 09_04_13 p.m..png",
                                ),
                                DashboardCard(
                                  title: "Favoritos",
                                  subtitle: "Todo lo que te importa",
                                  assetPath: "assets/images/ChatGPT Image 29 sept 2026, 10_15_46 p.m..png",
                                ),
                                DashboardCard(
                                  title: "Gestión de Archivos",
                                  subtitle: "Explora, organiza y accede rápido",
                                  assetPath: "",
                                ),
                                DashboardCard(
                                  title: "Modos de Rendimiento",
                                  subtitle: "Ajusta el rendimiento de tu dispositivo",
                                  assetPath: "assets/images/card_perf.png",
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Botón principal
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {},
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AnythingsHubApp.acentoSuavePomeloApagado,
                                  foregroundColor: AnythingsHubApp.fondoPrincipal,
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

                    // --- FOOTER MENU ---
                    Container(
                      height: 60,
                      decoration: const BoxDecoration(
                        color: AnythingsHubApp.fondoPrincipal,
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
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: AnythingsHubApp.acentoSuavePomeloApagado,
        child: const Icon(Icons.add, color: AnythingsHubApp.fondoPrincipal),
      ),
    );
  }
}

// --- SIDEBAR EXPANDIBLE CON TONO #060B11 Y ANCHO PROPORCIONAL ---
class CollapsibleSidebar extends StatefulWidget {
  final double screenWidth;
  const CollapsibleSidebar({super.key, required this.screenWidth});

  @override
  State<CollapsibleSidebar> createState() => _CollapsibleSidebarState();
}

class _CollapsibleSidebarState extends State<CollapsibleSidebar>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _controller;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleSidebar() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Definimos los anchos en base a un porcentaje estricto de la pantalla para que no compita
    // Contraído: ~14% de la pantalla (aprox 65-75px en móviles)
    // Expandido: ~30% de la pantalla para mostrar cómodamente la matriz 2x2
    double minWidth = widget.screenWidth * 0.16;
    double maxWidth = widget.screenWidth * 0.32;

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity! > 200 && !_isExpanded) {
          _toggleSidebar();
        } else if (details.primaryVelocity! < -200 && _isExpanded) {
          _toggleSidebar();
        }
      },
      child: AnimatedBuilder(
        animation: _expandAnimation,
        builder: (context, child) {
          double currentWidth = minWidth + (_expandAnimation.value * (maxWidth - minWidth));

          return Container(
            width: currentWidth,
            color: AnythingsHubApp.fondoSidebar, // Tono específico #060B11
            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAppGroupSection(
                  Icons.access_time_rounded, 
                  "Recientes", 
                  [Icons.alarm, Icons.history, Icons.timer, Icons.update], 
                  true
                ),
                _buildAppGroupSection(
                  Icons.folder_open_rounded, 
                  "Carpetas", 
                  [Icons.folder, Icons.folder_special, Icons.folder_shared, Icons.snippet_folder], 
                  false
                ),
                _buildAppGroupSection(
                  Icons.web_rounded, 
                  "Webs", 
                  [Icons.public, Icons.language, Icons.bookmark, Icons.link], 
                  false
                ),
                _buildAppGroupSection(
                  Icons.apps_rounded, 
                  "Apps", 
                  [Icons.extension, Icons.widgets, Icons.dashboard, Icons.category], 
                  false
                ),
                _buildAppGroupSection(
                  Icons.star_rounded, 
                  "Favoritos", 
                  [Icons.star, Icons.star_border, Icons.grade, Icons.auto_awesome], 
                  false
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAppGroupSection(IconData mainIcon, String label, List<IconData> groupIcons, bool isActive) {
    return GestureDetector(
      onTap: _toggleSidebar,
      child: SizedBox(
        height: 85,
        child: Stack(
          alignment: Alignment.topLeft,
          clipBehavior: Clip.none,
          children: List.generate(groupIcons.length, (index) {
            double t = _expandAnimation.value;

            int col = index % 2;
            int row = index ~/ 2;

            double collapsedLeft = index * 2.5;
            double collapsedTop = index * 3.5;

            double expandedLeft = col * 36.0 + 2.0;
            double expandedTop = row * 36.0 + 2.0;

            double currentLeft = collapsedLeft + (expandedLeft - collapsedLeft) * t;
            double currentTop = collapsedTop + (expandedTop - collapsedTop) * t;

            double scale = 1.0 - ((3 - index) * 0.02 * (1 - t));

            return Positioned(
              left: currentLeft,
              top: currentTop,
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isActive && index == 0
                        ? AnythingsHubApp.acentoSuavePomeloApagado.withOpacity(0.3)
                        : AnythingsHubApp.elementoSecundarioGrisIndigo.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isActive && index == 0
                          ? AnythingsHubApp.acentoSuavePomeloApagado
                          : Colors.transparent,
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4 + (index * 0.05)),
                        blurRadius: 3 + (index * 1.5),
                        offset: Offset(0, 1 + index.toDouble()),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      index == 0 ? mainIcon : groupIcons[index],
                      color: isActive && index == 0
                          ? AnythingsHubApp.acentoSuavePomeloApagado
                          : AnythingsHubApp.textoPrincipalClaro,
                      size: 16,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// --- WIDGET DE TARJETA ADAPTADO PARA IMÁGENES PNG ---
class DashboardCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String assetPath;

  const DashboardCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.assetPath,
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
          Expanded(
            child: Center(
              child: Image.asset(
                assetPath,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.broken_image, size: 36, color: AnythingsHubApp.acentoSuavePomeloApagado);
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
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
