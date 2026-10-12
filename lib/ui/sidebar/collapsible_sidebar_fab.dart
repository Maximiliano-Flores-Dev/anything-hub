part of 'collapsible_sidebar.dart';

class _FabRadialOverlay extends StatelessWidget {
  const _FabRadialOverlay({
    required this.fabCenter,
    required this.hoveredIndex,
    required this.onDismiss,
  });

  final Offset fabCenter;
  final int? hoveredIndex;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: onDismiss,
              behavior: HitTestBehavior.opaque,
              child: const ColoredBox(color: Color(0x66000000)),
            ),
          ),
          ...List.generate(kFabActions.length, (i) {
            final pos = _actionPositionStatic(fabCenter, i);
            final selected = hoveredIndex == i;
            final action = kFabActions[i];
            return Positioned(
              left: pos.dx - 22,
              top: pos.dy - 22,
              child: AnimatedScale(
                scale: selected ? 1.18 : 1.0,
                duration: const Duration(milliseconds: 120),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? HubColors.pomelo : HubColors.panel,
                    border: Border.all(
                      color: selected
                          ? HubColors.pomelo
                          : HubColors.linea.withOpacity(0.8),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.45),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    action.icon,
                    size: 20,
                    color: selected
                        ? HubColors.fondoPrincipal
                        : HubColors.textoPrincipal,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  static Offset _actionPositionStatic(Offset center, int index) {
    const radius = 96.0;
    final n = kFabActions.length;
    final start = -2.4;
    final sweep = 2.0;
    final t = n == 1 ? 0.5 : index / (n - 1);
    final angle = start + sweep * t;
    return Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );
  }
}

class _SidebarFabButton extends StatelessWidget {
  const _SidebarFabButton({
    required this.onPointerDown,
    required this.onPointerMove,
    required this.onPointerUp,
    required this.onPointerCancel,
  });

  final void Function(PointerDownEvent) onPointerDown;
  final void Function(PointerMoveEvent) onPointerMove;
  final void Function(PointerUpEvent) onPointerUp;
  final VoidCallback onPointerCancel;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: onPointerDown,
      onPointerMove: onPointerMove,
      onPointerUp: onPointerUp,
      onPointerCancel: (_) => onPointerCancel(),
      child: SizedBox(
        width: 56,
        height: 56,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: HubColors.degradadoDiagonal,
            boxShadow: [
              BoxShadow(
                color: HubColors.pomelo.withOpacity(0.45),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.add_rounded, color: Colors.white, size: 30),
          ),
        ),
      ),
    );
  }
}
