part of 'collapsible_sidebar.dart';

class _SidebarGroupTile extends StatelessWidget {
  const _SidebarGroupTile({
    required this.group,
    required this.progress,
    required this.width,
    required this.onAppTap,
    required this.onExpand,
    this.onEdit,
  });

  final AppGroup group;
  final double progress;
  final double width;
  final void Function(HubApp) onAppTap;
  final VoidCallback onExpand;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final expanded = progress > 0.55;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: expanded ? null : onExpand,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Color(group.colorArgb),
                    shape: BoxShape.circle,
                  ),
                ),
                if (expanded) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      group.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: HubColors.textoPrincipal.withOpacity(progress),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (onEdit != null)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: onEdit,
                      icon: Icon(Icons.edit_outlined,
                          size: 16,
                          color: HubColors.textoSecundario.withOpacity(progress)),
                    ),
                ],
              ],
            ),
          ),
        ),
        if (expanded)
          ...group.apps.map(
            (app) => _SidebarAppTile(
              app: app,
              progress: progress,
              onTap: () => onAppTap(app),
            ),
          ),
      ],
    );
  }
}

class _SidebarAppTile extends StatelessWidget {
  const _SidebarAppTile({
    required this.app,
    required this.progress,
    required this.onTap,
  });

  final HubApp app;
  final double progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(left: 18, right: 8, top: 4, bottom: 4),
        child: Row(
          children: [
            _MiniAvatar(app: app),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                app.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: HubColors.textoPrincipal.withOpacity(progress),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniAvatar extends StatelessWidget {
  const _MiniAvatar({required this.app});
  final HubApp app;

  @override
  Widget build(BuildContext context) {
    final bytes = app.iconBytes;
    if (bytes != null && bytes.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.memory(bytes, width: 22, height: 22, fit: BoxFit.cover),
      );
    }
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: app.background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        (app.letter ?? (app.name.isNotEmpty ? app.name[0] : '?')).toUpperCase(),
        style: TextStyle(
          color: app.foreground,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
