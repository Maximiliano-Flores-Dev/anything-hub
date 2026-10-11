import 'package:flutter/material.dart';

import '../utils/local_docs.dart';
import 'hub_colors_local.dart';

/// Documentación local on-device (Hito 4). Sin dependencia de red.
class LocalDocsScreen extends StatelessWidget {
  const LocalDocsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HubColors.fondoPrincipal,
      appBar: AppBar(
        backgroundColor: HubColors.fondoSidebar,
        elevation: 0,
        title: Text(
          'Documentación del módulo',
          style: TextStyle(color: HubColors.textoPrincipal),
        ),
        iconTheme: IconThemeData(color: HubColors.textoPrincipal),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          _section('Resumen', LocalDocs.moduleOverview),
          SizedBox(height: 20),
          _section('Seguridad', LocalDocs.securityChecklist),
        ],
      ),
    );
  }

  Widget _section(String title, String body) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HubColors.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HubColors.linea.withOpacity(0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: HubColors.pomelo,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 10),
          Text(
            body.trim(),
            style: TextStyle(
              color: HubColors.textoSecundario,
              fontSize: 13.2,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
