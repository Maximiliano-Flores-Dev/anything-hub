import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/hub_colors.dart';
import '../models/app_models.dart';
import '../widgets/hub_panel.dart';

class AnalisisComplementarioScreen extends StatelessWidget {
  const AnalisisComplementarioScreen({super.key, required this.report});

  final ApkRiskReport report;

  @override
  Widget build(BuildContext context) {
    final hash = report.sha256 ?? '— (pendiente de calcular)';

    return Scaffold(
      backgroundColor: HubColors.fondoPrincipal,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: HubColors.textoPrincipal),
        title: Text(
          'Análisis complementario',
          style: TextStyle(
              color: HubColors.textoPrincipal, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            'Verifica la integridad y seguridad del APK de forma adicional.',
            style: TextStyle(color: HubColors.textoSecundario, fontSize: 14),
          ),
          const SizedBox(height: 20),
          HubPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.fingerprint,
                        color: HubColors.textoSecundario, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Resumen del archivo',
                      style: TextStyle(
                        color: HubColors.textoPrincipal,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Identificador único del APK analizado.',
                  style:
                      TextStyle(color: HubColors.textoSecundario, fontSize: 12),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: HubColors.fondoPrincipal,
                    borderRadius: BorderRadius.circular(radius12),
                    border: Border.all(color: HubColors.linea),
                  ),
                  child: SelectableText(
                    hash,
                    style: TextStyle(
                      color: HubColors.textoPrincipal,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: HubColors.pomelo,
                          foregroundColor: HubColors.fondoPrincipal,
                        ),
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: hash));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Hash copiado')),
                            );
                          }
                        },
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text('Copiar hash'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: HubColors.textoPrincipal,
                          side: BorderSide(color: HubColors.linea),
                        ),
                        onPressed: () {},
                        icon: const Icon(Icons.ios_share, size: 18),
                        label: const Text('Exportar APK'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          HubPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.security,
                        color: HubColors.textoSecundario, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Verificación externa',
                      style: TextStyle(
                        color: HubColors.textoPrincipal,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Este análisis es opcional y no afecta la instalación. '
                  'Puedes verificar el APK manualmente para mayor confianza:',
                  style:
                      TextStyle(color: HubColors.textoSecundario, fontSize: 13),
                ),
                const SizedBox(height: 12),
                _step('1',
                    'Sube el APK a VirusTotal (virustotal.com) para escanearlo en la nube.'),
                _step('2',
                    'O escanea el APK con tu antivirus local de confianza.'),
                _step('3',
                    'Revisa los resultados y decide si deseas instalarlo.'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          HubPanel(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    color: HubColors.textoAcento, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Opcional, no bloquea la instalación',
                    style:
                        TextStyle(color: HubColors.textoAcento, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _step(String n, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: HubColors.pomelo.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              n,
              style: TextStyle(
                color: HubColors.pomelo,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: HubColors.textoSecundario, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
