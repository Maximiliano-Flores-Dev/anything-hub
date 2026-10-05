import 'package:flutter/material.dart';

import '../../../core/hub_colors.dart';

/// Contenedor estándar de panel oscuro del Hub.
class HubPanel extends StatelessWidget {
  const HubPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: HubColors.panel,
        borderRadius: BorderRadius.circular(radius12),
        border: Border.all(color: HubColors.linea.withOpacity(0.85)),
      ),
      child: child,
    );
  }
}
