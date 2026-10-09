part of 'collapsible_sidebar.dart';

class _SidebarGroupTile extends StatelessWidget {
  const _SidebarGroupTile({
    required this.group,
    required this.progress,
    required this.width,
    required this.onAppTap,
    required this.onExpand,
  });

  final AppGroup group;
  final double progress;
  final double width;
  final ValueChanged<HubApp> onAppTap;
  final VoidCallback onExpand;

  static const int _maxShown = 4;
  // Tamaño fijo de cada logo en la cuadrícula (antes crecía con el sidebar).
  // Es el único valor que hay que tocar para hacerlos más grandes o pequeños.
  static const double _tileSize = 40;
  static const double _gap = 10;

  @override
  Widget build(BuildContext context) {
    // Las categorías automáticas vacías no se muestran; las personalizadas sí.
    if (group.apps.isEmpty && !group.isCustom) return const SizedBox.shrink();

    // group.apps ya llega ordenado por uso (AppGroup.sortByUsage): las cuatro
    // primeras son las más usadas y se recalculan solas en cada escaneo.
    final top = group.apps.take(_maxShown).toList();
    final expanded = progress > 0.5;

    // Fundido cruzado alrededor del punto medio: la pila se desvanece y la
    // cuadrícula aparece, sin saltos mientras el dedo arrastra el sidebar.
    final raw = expanded ? (progress - 0.5) * 2 : 1 - progress * 2;
    final opacity = math.max(0.0, math.min(1.0, raw));

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Opacity(
        opacity: opacity,
        child: expanded ? _buildGrid(context, top) : _buildStack(top),
      ),
    );
  }

  // Encogido: las apps no se pueden elegir una a una, así que tocar la pila
  // expande el sidebar.
  Widget _buildStack(List<HubApp> top) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onExpand,
      child: Center(child: _AppStackIcons(apps: top)),
    );
  }

  // Extendido: cuadrícula 2x2 alineada a la izquierda, con la etiqueta del
  // grupo ocupando todo el ancho. El tamaño del logo es fijo; solo se reduce si
  // el sidebar aún está tan estrecho (a mitad de la animación) que no cabría.
  Widget _buildGrid(BuildContext context, List<HubApp> top) {
    final tile = math.max(28.0, math.min(_tileSize, (width - 28 - _gap) / 2));
    final hidden = group.apps.length - top.length;

    Widget cell(int i) {
      if (i >= top.length) return SizedBox(width: tile, height: tile);
      final app = top[i];
      return Tooltip(
        message: app.name, // sin nombres en pantalla: mantén pulsado para verlo
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onAppTap(app),
          child: AppAvatar(app: app, size: tile, radius: tile * 0.26),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel(context, hidden),
          if (top.isEmpty)
            Padding(
              padding: EdgeInsets.only(left: 2, top: 2),
              child: Text(
                'Grupo vacío',
                style: TextStyle(color: HubColors.textoSecundario, fontSize: 12),
              ),
            )
          else ...[
            Row(children: [cell(0), const SizedBox(width: _gap), cell(1)]),
            if (top.length > 2) ...[
              const SizedBox(height: _gap),
              Row(children: [cell(2), const SizedBox(width: _gap), cell(3)]),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildLabel(BuildContext context, int hidden) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: hidden > 0 ? () => _showAll(context) : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 2, 0, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                group.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: HubColors.textoSecundario,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            if (group.isCustom)
              Icon(Icons.edit_outlined, size: 12, color: HubColors.textoSecundario),
            if (hidden > 0) ...[
              const SizedBox(width: 6),
              Text(
                '+$hidden',
                style: TextStyle(
                  color: HubColors.textoAcento,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 14, color: HubColors.textoAcento),
            ],
          ],
        ),
      ),
    );
  }

  // El sidebar solo muestra las 4 más usadas; el resto sigue accesible aquí.
  void _showAll(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: HubColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Text(
                  '${group.label} · ${group.apps.length}',
                  style: TextStyle(
                    color: HubColors.textoPrincipal,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Flexible(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: group.apps.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.78,
                  ),
                  itemBuilder: (_, i) {
                    final app = group.apps[i];
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        Navigator.pop(ctx);
                        onAppTap(app);
                      },
                      child: Column(
                        children: [
                          AppAvatar(app: app, size: 52, radius: 13),
                          const SizedBox(height: 6),
                          Text(
                            app.name,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: HubColors.textoSecundario,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pila de hasta 4 logos: el más usado al frente (abajo-izquierda) y los
/// demás detrás, asomando hacia arriba y la derecha, cada vez más oscuros.
class _AppStackIcons extends StatelessWidget {
  const _AppStackIcons({required this.apps, this.size = 36});

  final List<HubApp> apps;
  final double size;

  static const double _dx = 4; // cuánto asoma cada capa hacia la derecha
  static const double _dy = 4; // ...y hacia arriba
  static const List<double> _dim = [0, 0.28, 0.5, 0.68];

  @override
  Widget build(BuildContext context) {
    if (apps.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: HubColors.panel,
          borderRadius: BorderRadius.circular(size * 0.26),
          border: Border.all(color: HubColors.linea),
        ),
        child: Icon(Icons.folder_outlined, size: size * 0.5, color: HubColors.textoSecundario),
      );
    }

    final n = math.min(apps.length, _dim.length);
    final radius = size * 0.26;
    return SizedBox(
      width: size + (n - 1) * _dx,
      height: size + (n - 1) * _dy,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Del fondo al frente: la capa 0 (la más usada) se dibuja al final.
          for (var i = n - 1; i >= 0; i--)
            Positioned(
              left: i * _dx,
              top: (n - 1 - i) * _dy,
              child: Stack(
                children: [
                  AppAvatar(app: apps[i], size: size, radius: radius),
                  if (i > 0)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: HubColors.fondoSidebar.withOpacity(_dim[i]),
                          borderRadius: BorderRadius.circular(radius),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class AppAvatar extends StatelessWidget {
  const AppAvatar({required this.app, required this.size, this.radius = 10});

  final HubApp app;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final bytes = app.iconBytes;
    if (bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: app.background,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Center(
        child: app.letter != null
            ? Text(
                app.letter!,
                style: TextStyle(
                  color: app.foreground,
                  fontWeight: FontWeight.w800,
                  fontSize: size * 0.42,
                ),
              )
            : Icon(app.icon, color: app.foreground, size: size * 0.48),
      ),
    );
  }
}

