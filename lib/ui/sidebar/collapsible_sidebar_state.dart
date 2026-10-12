part of 'collapsible_sidebar.dart';

class _CollapsibleSidebarState extends State<CollapsibleSidebar>
    with SingleTickerProviderStateMixin {
  static const double _minWidth = 64;
  static const double _maxWidthFactor = 0.72;

  static const double _dragSlop = 4;
  static const double _flingVelocity = 250;
  static const double _openThreshold = 0.35;

  late final AnimationController _controller;
  bool _isOpen = false;

  OverlayEntry? _overlayEntry;
  bool _menuOpen = false;
  int? _hoveredIndex;

  double get _maxWidth => widget.screenWidth * _maxWidthFactor;
  double get _travel => _maxWidth - _minWidth;
  double get _currentWidth => _minWidth + _travel * _controller.value;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
  }

  @override
  void dispose() {
    _removeOverlay();
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    _settle(open: !_isOpen);
  }

  void _settle({required bool open, double velocityPxPerSec = 0}) {
    _isOpen = open;
    final spring = SpringDescription.withDampingRatio(
      mass: 1,
      stiffness: 520,
      ratio: 1.0,
    );
    _controller.animateWith(
      SpringSimulation(
        spring,
        _controller.value,
        open ? 1.0 : 0.0,
        velocityPxPerSec /
            _travel, // px/s -> unidades del controller por segundo
      ),
    );
  }

  void _onDragStart(DragStartDetails d) {
    _controller.stop();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    final delta = d.primaryDelta;
    if (delta == null) return;
    _controller.value = (_controller.value + delta / _travel).clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    final bool open = v.abs() > _flingVelocity
        ? v > 0
        : _controller.value > _openThreshold;
    _settle(open: open, velocityPxPerSec: v);
  }

  void _openMenu(Offset globalPos) {
    if (_menuOpen) return;
    _menuOpen = true;
    _hoveredIndex = null;
    _overlayEntry = OverlayEntry(builder: (ctx) => _buildOverlay());
    Overlay.of(context).insert(_overlayEntry!);
    setState(() {});
  }

  void _updatePointer(Offset globalPos) {
    if (!_menuOpen) return;
    _hoveredIndex = _closestActionIndex(globalPos);
    _overlayEntry?.markNeedsBuild();
  }

  void _closeMenu({bool execute = false}) {
    if (!_menuOpen) return;
    final idx = _hoveredIndex;
    _removeOverlay();
    _menuOpen = false;
    _hoveredIndex = null;
    setState(() {});
    if (execute && idx != null) {
      widget.onActionSelected(kFabActions[idx]);
    }
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  int? _closestActionIndex(Offset globalPos) {
    final fabCenter = _fabGlobalCenter();
    if (fabCenter == null) return null;
    double bestDist = double.infinity;
    int? best;
    for (var i = 0; i < kFabActions.length; i++) {
      final pos = _actionPosition(fabCenter, i);
      final d = (pos - globalPos).distance;
      if (d < bestDist && d < 56) {
        bestDist = d;
        best = i;
      }
    }
    return best;
  }

  Offset? _fabGlobalCenter() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final origin = box.localToGlobal(Offset.zero);
    return Offset(origin.dx + _currentWidth / 2, origin.dy + box.size.height - 18 - 28);
  }

  Offset _actionPosition(Offset center, int index) {
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

  Widget _buildOverlay() {
    final fabCenter = _fabGlobalCenter() ?? Offset.zero;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => _closeMenu(),
              behavior: HitTestBehavior.opaque,
              child: const ColoredBox(color: Color(0x66000000)),
            ),
          ),
          ...List.generate(kFabActions.length, (i) {
            final pos = _actionPosition(fabCenter, i);
            final selected = _hoveredIndex == i;
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final w = _currentWidth;
        final progress = _controller.value;
        return RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: <Type, GestureRecognizerFactory>{
            HorizontalDragGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<
                    HorizontalDragGestureRecognizer>(
              () => HorizontalDragGestureRecognizer(),
              (r) => r
                ..gestureSettings =
                    const DeviceGestureSettings(touchSlop: _dragSlop)
                ..dragStartBehavior = DragStartBehavior.down
                ..onStart = _onDragStart
                ..onUpdate = _onDragUpdate
                ..onEnd = _onDragEnd
                ..onCancel =
                    () => _settle(open: _controller.value > _openThreshold),
            ),
          },
          child: Container(
            width: w,
            color: HubColors.fondoSidebar,
            child: Column(
              children: [
                SizedBox(
                  height: 52,
                  child: progress > 0.55
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              Icon(Icons.grid_view_rounded,
                                  color: HubColors.pomelo, size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Aplicaciones',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: HubColors.textoPrincipal
                                        .withOpacity(progress),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: _toggle,
                                icon: Icon(
                                  Icons.chevron_left_rounded,
                                  color: HubColors.textoSecundario
                                      .withOpacity(progress),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Center(
                          child: IconButton(
                            onPressed: _toggle,
                            icon: Icon(Icons.menu_rounded,
                                color: HubColors.textoSecundario),
                          ),
                  ),
                  Divider(height: 1, color: HubColors.linea.withOpacity(0.6)),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: widget.appGroups.length,
                      itemBuilder: (context, gi) {
                        final group = widget.appGroups[gi];
                        return _SidebarGroupTile(
                          group: group,
                          progress: progress,
                          width: w,
                          onAppTap: widget.onAppTap,
                          onExpand: () => _settle(open: true),
                          onEdit: group.isCustom && widget.onEditGroup != null
                              ? () => widget.onEditGroup!(group)
                              : null,
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18, top: 8),
                    child: _buildFab(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFab() {
    return _SidebarFabButton(
      onPointerDown: (e) => _openMenu(e.position),
      onPointerMove: (e) => _updatePointer(e.position),
      onPointerUp: (e) => _closeMenu(execute: true),
      onPointerCancel: () => _closeMenu(),
    );
  }
}
