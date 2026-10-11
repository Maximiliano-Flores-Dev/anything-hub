import 'package:flutter/material.dart';

import '../../core/hub_colors.dart';

class AppsArt extends StatelessWidget {
  const AppsArt();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 68,
      child: Stack(
        children: [
          Positioned(left: 0, top: 12, child: _miniIcon(Icons.chat_bubble_outline, const Color(0xFF10A37F))),
          Positioned(left: 28, top: 0, child: _miniIcon(Icons.auto_awesome, const Color(0xFF6C8CFF))),
          Positioned(left: 56, top: 14, child: _miniIcon(Icons.smart_toy_outlined, const Color(0xFFD9774F))),
          Positioned(left: 18, top: 36, child: _miniIcon(Icons.apps, HubColors.pomelo)),
        ],
      ),
    );
  }

  Widget _miniIcon(IconData icon, Color color) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }
}

class SheetsArt extends StatelessWidget {
  const SheetsArt();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 64,
      child: Stack(
        children: [
          Positioned(
            left: 8,
            top: 8,
            child: _folder(const Color(0xFFF2B531), 48),
          ),
          Positioned(
            left: 22,
            top: 18,
            child: _folder(const Color(0xFFF05A3C), 44),
          ),
        ],
      ),
    );
  }

  Widget _folder(Color color, double size) {
    return Container(
      width: size,
      height: size * 0.78,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.7), width: 1.4),
      ),
      child: Align(
        alignment: Alignment.topLeft,
        child: Container(
          width: size * 0.42,
          height: 8,
          margin: const EdgeInsets.only(left: 4, top: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.55),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}

class WebArt extends StatelessWidget {
  const WebArt();

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.public_rounded, size: 48, color: HubColors.pomelo);
  }
}

class FavoritesArt extends StatelessWidget {
  const FavoritesArt();

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.star_rounded, size: 48, color: HubColors.amarillo);
  }
}

class FilesArt extends StatelessWidget {
  const FilesArt();

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.folder_open_rounded, size: 48, color: HubColors.textoAcento);
  }
}

class PerformanceArt extends StatelessWidget {
  const PerformanceArt();

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.speed_rounded, size: 48, color: HubColors.pomelo);
  }
}
