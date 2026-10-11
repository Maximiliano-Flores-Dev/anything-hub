import 'package:flutter/material.dart';

import '../../core/hub_colors.dart';

class GradientPillButton extends StatelessWidget {
  const GradientPillButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(999);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: HubColors.degradado,
        borderRadius: shape,
        boxShadow: [
          BoxShadow(
            color: HubColors.pomelo.withOpacity(0.28),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: shape,
          onTap: onPressed,
          child: SizedBox(
            height: 44,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 19, color: HubColors.fondoPrincipal),
                SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: HubColors.fondoPrincipal,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
