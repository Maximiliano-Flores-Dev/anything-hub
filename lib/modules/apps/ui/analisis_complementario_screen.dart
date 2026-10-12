import 'package:flutter/material.dart';

import '../../../core/hub_colors.dart';

/// Pantalla auxiliar de análisis (placeholder endurecido).
class AnalisisComplementarioScreen extends StatelessWidget {
  const AnalisisComplementarioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HubColors.fondoPrincipal,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: HubColors.textoPrincipal),
        title: Text(
          'Análisis complementario',
          style: TextStyle(
            color: HubColors.textoPrincipal,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: HubColors.panel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: HubColors.linea),
          ),
          child: Text(
            'Herramientas de análisis complementario. Esta vista no debe tumbar el build.',
            style: TextStyle(color: HubColors.textoSecundario, fontSize: 13),
          ),
        ),
      ),
    );
  }
}
