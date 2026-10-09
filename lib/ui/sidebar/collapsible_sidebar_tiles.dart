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
  final void Function(AppItem) onAppTap;
  final VoidCallback onExpand;

  static const double _gap = 6;

  @override
  Widget build(BuildContext context) {
    final top = group.apps.take(4).toList();
    final hidden = group.apps.length - top.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  group.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: HubColors.textoSecundario.withOpacity(0.55 + 0.45 * progress),
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
                    color: HubColors.pomelo.withOpacity(0.7 + 0.3 * progress),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          if (top.isEmpty)
            const Padding(
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

  Widget cell(int i) {
    if (i >= group.apps.length) return const SizedBox.shrink();
    final app = group.apps[i];
    final size = (width - 16 - _gap) / 2;
    return SizedBox(
      width: size,
      height: size,
      child: _AppIconButton(
        app: app,
        size: size,
        onTap: () {
          if (progress < 0.5) {
            onExpand();
          } else {
            onAppTap(app);
          }
        },
      ),
    );
  }
}

class _AppIconButton extends StatelessWidget {
  const _AppIconButton({
    required this.app,
    required this.size,
    required this.onTap,
  });

  final AppItem app;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: app.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: HubColors.linea.withOpacity(0.5)),
          ),
          child: Icon(app.icon, color: app.foreground, size: size * 0.48),
        ),
      ),
    );
  }
}
