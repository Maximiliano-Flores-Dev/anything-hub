import 'package:flutter/material.dart';

import '../services/editor_service.dart';
import 'hub_colors_local.dart';

class EditorSettingsSheet extends StatefulWidget {
  const EditorSettingsSheet({super.key});

  @override
  State<EditorSettingsSheet> createState() => _EditorSettingsSheetState();
}

class _EditorSettingsSheetState extends State<EditorSettingsSheet> {
  EditorPreferences? _prefs;
  List<InstalledEditor> _installed = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final prefs = await EditorService.loadPreferences();
    final installed = await EditorService.detectInstalledEditors();
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _installed = installed;
      _loading = false;
    });
  }

  Future<void> _setPreferred(String id) async {
    if (_prefs == null) return;
    setState(() => _prefs!.preferred = id);
    await EditorService.savePreferences(_prefs!);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: HubColors.panel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          const SizedBox(height: 16),
          const Text(
            'Editor predeterminado',
            style: TextStyle(
              color: HubColors.textoPrincipal,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Prioridad: editor local instalado → vscode.dev',
            style: TextStyle(color: HubColors.textoSecundario, fontSize: 13),
          ),
          const SizedBox(height: 18),
          if (_loading)
            const Center(child: CircularProgressIndicator(color: HubColors.pomelo))
          else ...[
            _tile('vscode.dev', 'vscode.dev (web)', 'Fallback seguro', _prefs?.preferred == 'vscode.dev',
                () => _setPreferred('vscode.dev')),
            const SizedBox(height: 8),
            if (_installed.isEmpty)
              const Text(
                'No se detectaron editores locales de la lista blanca.\n'
                'Instala Acode, Markor o Termux para usar editores nativos.',
                style: TextStyle(color: HubColors.textoSecundario, fontSize: 13, height: 1.35),
              )
            else
              ..._installed.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _tile(e.id, e.label, e.packageName, _prefs?.preferred == e.id,
                        () => _setPreferred(e.id)),
                  )),
          ],
        ],
      ),
    );
  }

  Widget _tile(String id, String label, String subtitle, bool selected, VoidCallback onTap) {
    return Material(
      color: selected ? HubColors.pomelo.withOpacity(0.12) : HubColors.fondoPrincipal,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? HubColors.pomelo : HubColors.linea.withOpacity(0.5),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                id == 'vscode.dev' ? Icons.language_rounded : Icons.code_rounded,
                color: selected ? HubColors.pomelo : HubColors.textoSecundario,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                          color: HubColors.textoPrincipal,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                          fontSize: 14.5,
                        )),
                    Text(subtitle,
                        style: const TextStyle(color: HubColors.textoSecundario, fontSize: 12)),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded, color: HubColors.pomelo, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
