import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/hub_colors.dart';

/// Celda compacta de la grilla: solo icono + nombre (+ categoría).
/// Sin botones de acción — el tap abre AppGestionScreen.
class AppIconCell extends StatelessWidget {
  const AppIconCell({
    super.key,
    required this.name,
    required this.category,
    this.iconBytes,
    this.bookmarked = false,
    required this.onTap,
  });

  final String name;
  final String category;
  final Uint8List? iconBytes;
  final bool bookmarked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                _buildIcon(),
                if (bookmarked)
                  const Positioned(
                    top: -4,
                    right: -4,
                    child: Icon(
                      Icons.star_rounded,
                      size: 16,
                      color: HubColors.amarillo,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: HubColors.textoPrincipal,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              category,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: HubColors.textoSecundario,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    if (iconBytes != null && iconBytes!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          iconBytes!,
          width: 52,
          height: 52,
          fit: BoxFit.cover,
        ),
      );
    }
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: HubColors.fondoSidebar,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HubColors.linea),
      ),
      child: const Icon(Icons.android, color: HubColors.textoSecundario),
    );
  }
}
