part of 'group_editor_sheet.dart';

class _GroupColorChips extends StatelessWidget {
  const _GroupColorChips({required this.selected, required this.onSelect});
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final c in kGroupColorOptions)
          GestureDetector(
            onTap: () => onSelect(c),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Color(c),
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected == c ? Colors.white : Colors.transparent,
                  width: 2.5,
                ),
                boxShadow: selected == c
                    ? [
                        BoxShadow(
                            color: Color(c).withOpacity(0.55), blurRadius: 8)
                      ]
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

class _GroupAppPickTile extends StatelessWidget {
  const _GroupAppPickTile({
    required this.app,
    required this.selected,
    required this.accent,
    required this.onTap,
  });
  final HubApp app;
  final bool selected;
  final int accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      onTap: onTap,
      leading: AppAvatar(app: app, size: 36, radius: 10),
      title: Text(
        app.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: HubColors.textoPrincipal, fontSize: 14),
      ),
      trailing: Icon(
        selected ? Icons.check_circle_rounded : Icons.circle_outlined,
        color: selected ? Color(accent) : HubColors.textoSecundario,
        size: 22,
      ),
    );
  }
}
