import 'package:flutter/material.dart';

import '../../core/models.dart';

/// Avatar de app para listas (ícono nativo, letra o icono Material).
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.app,
    this.size = 36,
    this.radius = 10,
  });

  final HubApp app;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final bytes = app.iconBytes;
    if (bytes != null && bytes.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: app.background,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: app.icon != null
          ? Icon(app.icon, color: app.foreground, size: size * 0.5)
          : Text(
              (app.letter ?? (app.name.isNotEmpty ? app.name[0] : '?'))
                  .toUpperCase(),
              style: TextStyle(
                color: app.foreground,
                fontWeight: FontWeight.w700,
                fontSize: size * 0.4,
              ),
            ),
    );
  }
}
