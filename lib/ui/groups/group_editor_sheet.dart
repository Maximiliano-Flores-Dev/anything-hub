import 'package:flutter/material.dart';

import '../../core/hub_colors.dart';
import '../../core/models.dart';
import '../../ui/sidebar/collapsible_sidebar.dart' show AppAvatar;

/// Resultado del editor de grupos personalizados.
class GroupEditorResult {
  const GroupEditorResult.save({
    required this.label,
    required this.packages,
    required this.colorArgb,
  }) : delete = false;

  const GroupEditorResult.delete()
      : label = null,
        packages = null,
        colorArgb = null,
        delete = true;

  final String? label;
  final List<String>? packages;
  final int? colorArgb;
  final bool delete;
}

/// Bottom sheet: crear / editar grupo (nombre, color, apps).
Future<GroupEditorResult?> showGroupEditorSheet({
  required BuildContext context,
  required Map<String, HubApp> catalog,
  AppGroup? existing,
  String title = 'Nuevo grupo',
}) {
  return showModalBottomSheet<GroupEditorResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: HubColors.panel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _GroupEditorBody(
      catalog: catalog,
      existing: existing,
      title: title,
    ),
  );
}

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
            (a.packageName?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  void _submit() {
    final name = _nameCtl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Escribe un nombre para el grupo'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: HubColors.panel,
        ),
      );
      return;
    }
    Navigator.pop(
      context,
      GroupEditorResult.save(
        label: name,
        packages: _selected.toList(),
        colorArgb: _colorArgb,
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HubColors.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Eliminar grupo', style: TextStyle(color: HubColors.textoPrincipal)),
        content: Text(
          '¿Eliminar "${widget.existing?.label}"? Las apps no se desinstalan.',
          style: TextStyle(color: HubColors.textoSecundario, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: HubColors.textoSecundario)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      Navigator.pop(context, const GroupEditorResult.delete());
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final maxH = MediaQuery.sizeOf(context).height * 0.88;
    final apps = _filtered;
    final isEdit = widget.existing != null;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: HubColors.linea,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        color: HubColors.textoPrincipal,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (isEdit)
                    TextButton(
                      onPressed: _confirmDelete,
                      child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
                    ),
                  TextButton(
                    onPressed: _submit,
                    child: Text(
                      isEdit ? 'Guardar' : 'Crear',
                      style: TextStyle(color: HubColors.pomelo, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: TextField(
                controller: _nameCtl,
                autofocus: !isEdit,
                style: TextStyle(color: HubColors.textoPrincipal),
                decoration: InputDecoration(
                  labelText: 'Nombre',
                  hintText: 'Nombre del grupo',
                  labelStyle: TextStyle(color: HubColors.textoSecundario),
                  floatingLabelStyle: TextStyle(color: HubColors.pomelo),
                  hintStyle: TextStyle(color: HubColors.textoSecundario.withOpacity(0.6)),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: HubColors.linea)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: HubColors.pomelo)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Color',
                  style: TextStyle(color: HubColors.textoSecundario, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                itemCount: kGroupColorOptions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final c = kGroupColorOptions[i];
                  final selected = c == _colorArgb;
                  return GestureDetector(
                    onTap: () => setState(() => _colorArgb = c),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? HubColors.textoPrincipal : Colors.transparent,
                          width: 2.5,
                        ),
                        boxShadow: selected
                            ? [BoxShadow(color: Color(c).withOpacity(0.45), blurRadius: 8)]
                            : null,
                      ),
                      child: selected
                          ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                          : null,
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: TextField(
                controller: _searchCtl,
                onChanged: (v) => setState(() => _query = v),
                style: TextStyle(color: HubColors.textoPrincipal, fontSize: 14),
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded, color: HubColors.textoSecundario, size: 20),
                  hintText: 'Buscar apps…',
                  hintStyle: TextStyle(color: HubColors.textoSecundario.withOpacity(0.6), fontSize: 13),
                  isDense: true,
                  filled: true,
                  fillColor: HubColors.fondoPrincipal,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
              child: Row(
                children: [
                  Text(
                    'Apps',
                    style: TextStyle(color: HubColors.textoSecundario, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Text(
                    '${_selected.length} seleccionadas',
                    style: TextStyle(color: HubColors.textoAcento, fontSize: 12),
                  ),
                ],
              ),
            ),
            Flexible(
              child: widget.catalog.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No hay apps escaneadas. Usa «Escanear Apps» en el FAB primero.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: HubColors.textoSecundario, fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                      itemCount: apps.length,
                      itemBuilder: (_, i) {
                        final app = apps[i];
                        final pkg = app.packageName ?? '';
                        final on = _selected.contains(pkg);
                        return ListTile(
                          dense: true,
                          leading: AppAvatar(app: app, size: 36, radius: 10),
                          title: Text(
                            app.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: HubColors.textoPrincipal, fontSize: 14),
                          ),
                          trailing: Icon(
                            on ? Icons.check_circle_rounded : Icons.circle_outlined,
                            color: on ? Color(_colorArgb) : HubColors.textoSecundario,
                            size: 22,
                          ),
                          onTap: () {
                            if (pkg.isEmpty) return;
                            setState(() {
                              if (on) {
                                _selected.remove(pkg);
                              } else {
                                _selected.add(pkg);
                              }
                            });
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
