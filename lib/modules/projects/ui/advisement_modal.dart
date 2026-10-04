import 'package:flutter/material.dart';

import '../services/project_activation_service.dart';
import 'hub_colors_local.dart';
import 'local_docs_screen.dart';

class ProjectAdvisementModal extends StatefulWidget {
  const ProjectAdvisementModal({
    super.key,
    required this.onAccepted,
    required this.onCancelled,
  });

  final VoidCallback onAccepted;
  final VoidCallback onCancelled;

  @override
  State<ProjectAdvisementModal> createState() => _ProjectAdvisementModalState();
}

class _ProjectAdvisementModalState extends State<ProjectAdvisementModal> {
  bool _dontShowAgain = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: HubColors.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: HubColors.linea.withOpacity(0.6)),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: HubColors.degradado,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.folder_special_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Gestión de Proyectos',
                    style: TextStyle(
                      color: HubColors.textoPrincipal,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Esta función está dirigida a desarrolladores.',
              style: TextStyle(color: HubColors.textoPrincipal, fontSize: 14.5, height: 1.35),
            ),
            const SizedBox(height: 10),
            const Text(
              'Al activarla se creará la estructura local oculta .anythinghub/ '
              '(consumo mínimo de almacenamiento). Todo el procesamiento es 100 % on-device. '
              'No se envía telemetría ni código fuente a ningún servidor.',
              style: TextStyle(color: HubColors.textoSecundario, fontSize: 13.2, height: 1.4),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const LocalDocsScreen()),
                );
              },
              child: const Text(
                'Ver documentación local',
                style: TextStyle(color: HubColors.textoAcento, fontSize: 13),
              ),
            ),
            Row(
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: Checkbox(
                    value: _dontShowAgain,
                    activeColor: HubColors.pomelo,
                    side: const BorderSide(color: HubColors.linea),
                    onChanged: (v) => setState(() => _dontShowAgain = v ?? false),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'No volver a mostrar este aviso',
                    style: TextStyle(color: HubColors.textoSecundario, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      if (_dontShowAgain) {
                        await ProjectActivationService.setDontShowAgain(true);
                      }
                      widget.onCancelled();
                    },
                    style: TextButton.styleFrom(foregroundColor: HubColors.textoSecundario),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_dontShowAgain) {
                        await ProjectActivationService.setDontShowAgain(true);
                      }
                      await ProjectActivationService.activate();
                      widget.onAccepted();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HubColors.pomelo,
                      foregroundColor: HubColors.fondoPrincipal,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Activar módulo', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
