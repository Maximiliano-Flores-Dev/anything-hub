import 'package:flutter/material.dart';

import '../../core/hub_colors.dart';
import '../../core/models.dart';
import '../../ui/widgets/app_avatar.dart';

part 'group_editor_widgets.dart';
part 'group_editor_body.dart';

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
