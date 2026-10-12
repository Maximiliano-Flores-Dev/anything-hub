part of 'group_editor_sheet.dart';

class _GroupEditorBody extends StatefulWidget {
  const _GroupEditorBody({
    required this.catalog,
    required this.existing,
    required this.title,
  });
  final Map<String, HubApp> catalog;
  final AppGroup? existing;
  final String title;

  @override
  State<_GroupEditorBody> createState() => _GroupEditorBodyState();
}

class _GroupEditorBodyState extends State<_GroupEditorBody> {
  late final TextEditingController _nameCtl;
  late final TextEditingController _searchCtl;
  late final Set<String> _selected;
  late int _colorArgb;
  String _query = '';

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _nameCtl = TextEditingController(text: ex?.label ?? '');
    _searchCtl = TextEditingController();
    _selected = {...?ex?.packages};
    _colorArgb = ex?.colorArgb ?? kGroupColorOptions.first;
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _searchCtl.dispose();
    super.dispose();
  }

  List<HubApp> get _filtered {
    final all = widget.catalog.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where((a) =>
            a.name.toLowerCase().contains(q) ||
            (a.packageName ?? '').toLowerCase().contains(q))
        .toList();
  }

  void _toggle(String pkg) {
    setState(() {
      if (_selected.contains(pkg)) {
        _selected.remove(pkg);
      } else {
        _selected.add(pkg);
      }
    });
  }

  void _save() {
    final name = _nameCtl.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(
      context,
      GroupEditorResult.save(
        label: name,
        packages: _selected.toList(),
        colorArgb: _colorArgb,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final apps = _filtered;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: HubColors.linea,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: HubColors.textoPrincipal,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  if (widget.existing != null)
                    TextButton(
                      onPressed: () => Navigator.pop(
                        context,
                        const GroupEditorResult.delete(),
                      ),
                      child: const Text('Eliminar',
                          style: TextStyle(color: Colors.redAccent)),
                    ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close,
                        color: HubColors.textoSecundario),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _nameCtl,
                style: const TextStyle(color: HubColors.textoPrincipal),
                decoration: InputDecoration(
                  labelText: 'Nombre del grupo',
                  labelStyle: const TextStyle(color: HubColors.textoSecundario),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: HubColors.linea),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Color(_colorArgb)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Color',
                style: TextStyle(
                    color: HubColors.textoSecundario,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _GroupColorChips(
                selected: _colorArgb,
                onSelect: (c) => setState(() => _colorArgb = c),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtl,
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(color: HubColors.textoPrincipal),
                decoration: InputDecoration(
                  hintText: 'Buscar apps…',
                  hintStyle: const TextStyle(color: HubColors.textoSecundario),
                  prefixIcon: const Icon(Icons.search,
                      color: HubColors.textoSecundario),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: HubColors.linea),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: HubColors.pomelo),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: widget.catalog.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No hay apps escaneadas. Usa «Escanear Apps» en el FAB primero.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: HubColors.textoSecundario, fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                      itemCount: apps.length,
                      itemBuilder: (_, i) {
                        final app = apps[i];
                        final pkg = app.packageName ?? '';
                        final on = _selected.contains(pkg);
                        return _GroupAppPickTile(
                          app: app,
                          selected: on,
                          accent: _colorArgb,
                          onTap: () => _toggle(pkg),
                        );
                      },
                    ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(_colorArgb),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _save,
                  child: Text(
                    'Guardar (${_selected.length})',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
