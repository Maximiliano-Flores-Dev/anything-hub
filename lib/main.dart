import 'dart:math' as math;

import 'package:anything_hub/services/logger_service.dart';
import 'package:flutter/material.dart';

const double radius12 = 12.0;

void main() {
  runApp(const AnythingsHubApp());
}

class AnythingsHubApp extends StatelessWidget {
  const AnythingsHubApp({super.key});

  // Jerarquía de UI
  static const Color fondoSidebar = Color(0xFF060B11);
  static const Color fondoPrincipal = Color(0xFF040508);

  static const Color elementoSecundarioGrisIndigo = Color(0xFF1A2232);
  static const Color acentoSuavePomeloApagado = Color(0xFFE0856F);
  static const Color textoPrincipalClaro = Color(0xFFC5C9D6);
  static const Color textoSecundario = Color(0xFF8F94A8);

  // Borde degradado de las cards: nace en el acento y se apaga hacia un gris-índigo más claro
  static const Color bordeGradienteInicio = Color(0xCCE0856F);
  static const Color bordeGradienteFin = Color(0xFF2A3550);

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

// --- DATOS DE LAS CARDS ---
class _CardData {
  final String title;
  final String subtitle;
  final String assetPath;
  final IconData icon;

  const _CardData({
    required this.title,
    required this.subtitle,
    required this.assetPath,
    required this.icon,
  });
}

class MainLayoutScreen extends StatefulWidget {
  const MainLayoutScreen({super.key});

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  int _selectedIndex = 0;

  static const List<_CardData> _cards = [
    _CardData(
      title: 'Mis Aplicaciones',
      subtitle: 'Gestiona y abre tus apps',
      assetPath: 'assets/images/ChatGPT Image 29 sept 2026, 08_55_20 p.m..png',
      icon: Icons.apps_rounded,
    ),
    _CardData(
      title: 'Carpetas del Proyecto',
      subtitle: 'Acceso rápido a tus proyectos',
      assetPath: 'assets/images/ChatGPT Image 29 sept 2026, 08_57_55 p.m..png',
      icon: Icons.folder_open_rounded,
    ),
    _CardData(
      title: 'Webs Rápidas',
      subtitle: 'Tus sitios favoritos, al instante',
      assetPath: 'assets/images/ChatGPT Image 29 sept 2026, 09_04_13 p.m..png',
      icon: Icons.public_rounded,
    ),
    _CardData(
      title: 'Favoritos',
      subtitle: 'Todo lo que te importa',
      assetPath: 'assets/images/ChatGPT Image 29 sept 2026, 10_15_46 p.m..png',
      icon: Icons.star_rounded,
    ),
    _CardData(
      title: 'Gestión de Archivos',
      subtitle: 'Explora, organiza y accede rápido',
      assetPath: '',
      icon: Icons.folder_copy_rounded,
    ),
    _CardData(
      title: 'Modos de Rendimiento',
      subtitle: 'Ajusta el rendimiento de tu dispositivo',
      assetPath: 'assets/images/card_perf.png',
      icon: Icons.speed_rounded,
    ),
  ];

  void _onCardTap(String title) {
    SystemLogger.log('Card → $title');
  }

  void _showQuickAddSheet() {
    SystemLogger.log('FAB → abrir acciones rápidas');
    final messenger = ScaffoldMessenger.of(context);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AnythingsHubApp.fondoSidebar,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _QuickAddSheet(
        onSelected: (label) {
          Navigator.of(sheetContext).pop();
          SystemLogger.log('FAB → acción: $label');
          messenger.showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: AnythingsHubApp.elementoSecundarioGrisIndigo,
              content: Text(
                '$label: próximamente',
                style: const TextStyle(color: AnythingsHubApp.textoPrincipalClaro),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AnythingsHubApp.fondoPrincipal,
      body: SafeArea(
        child: Row(
          children: [
            // --- SIDEBAR (~16% contraído, ~32% expandido) con el FAB circular abajo ---
            CollapsibleSidebar(
              screenWidth: screenWidth,
              onAddPressed: _showQuickAddSheet,
            ),

            // --- CONTENIDO PRINCIPAL ---
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
                                  icon: const Icon(Icons.settings_outlined,
                                      color: AnythingsHubApp.textoPrincipalClaro),
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

                            // --- GRID DE 6 TARJETAS ---
                            // mainAxisExtent fija el alto: el texto siempre cabe,
                            // sin importar cuánto se angoste la card al expandir el sidebar.
                            GridView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _cards.length,
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                mainAxisExtent: 172,
                              ),
                              itemBuilder: (context, i) {
                                final c = _cards[i];
                                return DashboardCard(
                                  title: c.title,
                                  subtitle: c.subtitle,
                                  assetPath: c.assetPath,
                                  fallbackIcon: c.icon,
                                  onTap: () => _onCardTap(c.title),
                                );
                              },
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
                          _footerButton(Icons.home_rounded, 0),
                          _footerButton(Icons.grid_view_rounded, 1),
                          _footerButton(Icons.search_rounded, 2),
                          _footerButton(Icons.person_outline_rounded, 3),
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
    );
  }

  Widget _footerButton(IconData icon, int index) {
    final selected = _selectedIndex == index;
    return IconButton(
      icon: Icon(
        icon,
        color: selected
            ? AnythingsHubApp.acentoSuavePomeloApagado
            : AnythingsHubApp.textoSecundario,
      ),
      onPressed: () {
        SystemLogger.log('Footer → tab $index');
        setState(() => _selectedIndex = index);
      },
    );
  }
}

// --- BOTTOM SHEET DE ACCIONES RÁPIDAS (lo abre el FAB) ---
class _QuickAction {
  final IconData icon;
  final String label;
  final String description;

  const _QuickAction(this.icon, this.label, this.description);
}

class _QuickAddSheet extends StatelessWidget {
  final ValueChanged<String> onSelected;

  const _QuickAddSheet({required this.onSelected});

  static const List<_QuickAction> _actions = [
    _QuickAction(Icons.extension_rounded, 'Nueva app', 'Registra una app para abrirla desde el hub'),
    _QuickAction(Icons.folder_open_rounded, 'Nueva carpeta', 'Atajo a una carpeta de proyecto'),
    _QuickAction(Icons.language_rounded, 'Nueva web', 'Guarda un sitio como acceso rápido'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AnythingsHubApp.textoSecundario.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Añadir al hub',
              style: TextStyle(
                color: AnythingsHubApp.textoPrincipalClaro,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            for (final action in _actions)
              ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () => onSelected(action.label),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AnythingsHubApp.elementoSecundarioGrisIndigo,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(action.icon, size: 20, color: AnythingsHubApp.acentoSuavePomeloApagado),
                ),
                title: Text(
                  action.label,
                  style: const TextStyle(
                    color: AnythingsHubApp.textoPrincipalClaro,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  action.description,
                  style: const TextStyle(color: AnythingsHubApp.textoSecundario, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// --- FAB TOTALMENTE CIRCULAR ---
// Material + CircleBorder: la forma, la sombra y el ripple son círculos perfectos.
class _CircleFab extends StatelessWidget {
  final double size;
  final VoidCallback onPressed;

  const _CircleFab({required this.size, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Añadir',
      child: Material(
        color: AnythingsHubApp.acentoSuavePomeloApagado,
        shape: const CircleBorder(),
        elevation: 4,
        shadowColor: Colors.black,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox.square(
            dimension: size,
            child: Icon(
              Icons.add_rounded,
              color: AnythingsHubApp.fondoPrincipal,
              size: size * 0.55,
            ),
          ),
        ),
      ),
    );
  }
}

// --- GRUPOS DEL SIDEBAR ---
class _SidebarGroup {
  final IconData mainIcon;
  final List<IconData> icons;
  final bool isActive;

  const _SidebarGroup(this.mainIcon, this.icons, {this.isActive = false});
}

// --- SIDEBAR EXPANDIBLE: EL DEDO CONTROLA LA ANIMACIÓN ---
class CollapsibleSidebar extends StatefulWidget {
  final double screenWidth;
  final VoidCallback onAddPressed;

  const CollapsibleSidebar({
    super.key,
    required this.screenWidth,
    required this.onAddPressed,
  });

  @override
  State<CollapsibleSidebar> createState() => _CollapsibleSidebarState();
}

class _CollapsibleSidebarState extends State<CollapsibleSidebar>
    with SingleTickerProviderStateMixin {
  // value: 0.0 = contraído, 1.0 = expandido
  late final AnimationController _controller;

  static const List<_SidebarGroup> _groups = [
    _SidebarGroup(
      Icons.access_time_rounded,
      [Icons.alarm, Icons.history, Icons.timer, Icons.update],
      isActive: true,
    ),
    _SidebarGroup(
      Icons.folder_open_rounded,
      [Icons.folder, Icons.folder_special, Icons.folder_shared, Icons.snippet_folder],
    ),
    _SidebarGroup(
      Icons.web_rounded,
      [Icons.public, Icons.language, Icons.bookmark, Icons.link],
    ),
    _SidebarGroup(
      Icons.apps_rounded,
      [Icons.extension, Icons.widgets, Icons.dashboard, Icons.category],
    ),
    _SidebarGroup(
      Icons.star_rounded,
      [Icons.star, Icons.star_border, Icons.grade, Icons.auto_awesome],
    ),
  ];

  double get _minWidth => widget.screenWidth * 0.16;
  double get _maxWidth => widget.screenWidth * 0.32;
  double get _range => _maxWidth - _minWidth;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Tap en una sección: alterna con una curva suave, sin overshoot.
  void _toggleSidebar() {
    SystemLogger.log('Sidebar → ${_controller.value > 0.5 ? "contraer" : "expandir"}');
    _controller.animateTo(
      _controller.value > 0.5 ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _onDragStart(DragStartDetails details) {
    // Si había una animación en curso, el dedo toma el control desde donde está.
    _controller.stop();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    // 1 px de dedo = 1 px de sidebar: sin lag ni saltos.
    _controller.value = (_controller.value + details.delta.dx / _range).clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails details) {
    // Velocidad en "unidades de animación por segundo".
    final velocity = details.velocity.pixelsPerSecond.dx / _range;

    // Flick rápido manda la dirección; si no, decide la mitad del recorrido.
    final shouldOpen = velocity.abs() > 3.0 ? velocity > 0 : _controller.value > 0.5;

    // fling usa una simulación de resorte: se siente física, no mecánica.
    _controller.fling(velocity: shouldOpen ? 2.5 : -2.5);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            final currentWidth = _minWidth + _range * t;
            // El FAB nunca supera el ancho útil del sidebar contraído.
            final fabSize = math.min(48.0, currentWidth - 12.0);

            return Container(
              width: currentWidth,
              color: AnythingsHubApp.fondoSidebar,
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 12),
              child: Column(
                children: [
                  // Secciones: se reparten el espacio; si la pantalla es baja, hacen scroll vertical.
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              for (final group in _groups) _buildAppGroupSection(group, t),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // --- FAB: abajo a la izquierda, dentro del sidebar ---
                  _CircleFab(size: fabSize, onPressed: widget.onAddPressed),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAppGroupSection(_SidebarGroup group, double t) {
    return GestureDetector(
      onTap: _toggleSidebar,
      child: SizedBox(
        height: 85,
        child: Stack(
          alignment: Alignment.topLeft,
          clipBehavior: Clip.none,
          children: List.generate(group.icons.length, (index) {
            final col = index % 2;
            final row = index ~/ 2;

            final collapsedLeft = index * 2.5;
            final collapsedTop = index * 3.5;

            final expandedLeft = col * 36.0 + 2.0;
            final expandedTop = row * 36.0 + 2.0;

            final currentLeft = collapsedLeft + (expandedLeft - collapsedLeft) * t;
            final currentTop = collapsedTop + (expandedTop - collapsedTop) * t;

            final scale = 1.0 - ((3 - index) * 0.02 * (1 - t));
            final highlighted = group.isActive && index == 0;

            return Positioned(
              left: currentLeft,
              top: currentTop,
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: highlighted
                        ? AnythingsHubApp.acentoSuavePomeloApagado.withOpacity(0.3)
                        : AnythingsHubApp.elementoSecundarioGrisIndigo.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: highlighted
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
                      index == 0 ? group.mainIcon : group.icons[index],
                      color: highlighted
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

// --- TARJETA CON BORDE DEGRADADO ---
class DashboardCard extends StatelessWidget {
  static const double _borderWidth = 1.2;

  final String title;
  final String subtitle;
  final String assetPath;
  final IconData fallbackIcon;
  final VoidCallback? onTap;

  const DashboardCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.assetPath,
    this.fallbackIcon = Icons.apps_rounded,
    this.onTap,
  });

  Widget _buildVisual() {
    final fallback = Icon(
      fallbackIcon,
      size: 40,
      color: AnythingsHubApp.acentoSuavePomeloApagado,
    );

    // Sin asset (o asset ausente): ícono limpio en vez del "broken image".
    if (assetPath.isEmpty) return fallback;

    return Image.asset(
      assetPath,
      fit: BoxFit.contain,
      // Decodifica a un tamaño acorde a la card: menos memoria, scroll más fluido.
      cacheWidth: 360,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // Capa exterior: el degradado. Su padding es el grosor del borde.
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius12),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AnythingsHubApp.bordeGradienteInicio,
            AnythingsHubApp.bordeGradienteFin,
          ],
        ),
      ),
      padding: const EdgeInsets.all(_borderWidth),
      child: Material(
        // Radio interior = exterior - grosor: las esquinas quedan concéntricas.
        color: AnythingsHubApp.elementoSecundarioGrisIndigo,
        borderRadius: BorderRadius.circular(radius12 - _borderWidth),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Center(child: _buildVisual()),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // El título usa todo el ancho y hasta 2 líneas: ya no se corta en "Mis Aplica..."
                    Text(
                      title,
                      style: const TextStyle(
                        color: AnythingsHubApp.textoPrincipalClaro,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        height: 1.15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AnythingsHubApp.textoSecundario,
                        fontSize: 10,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                // El indicador sale de la fila del título y pasa a la esquina.
                const Positioned(
                  top: 0,
                  right: 0,
                  child: Icon(
                    Icons.north_east_rounded,
                    size: 14,
                    color: AnythingsHubApp.textoSecundario,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
