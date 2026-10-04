import 'dart:typed_data';

import 'package:flutter/material.dart';

class HubApp {
  HubApp(
    this.name, {
    required this.background,
    required this.foreground,
    this.icon,
    this.letter,
    this.iconBytes,
    this.packageName,
    this.category = 'other',
    this.usageScore = 0,
    this.isSystemScanned = false,
  });

  final String name;
  final Color background;
  final Color foreground;
  final IconData? icon;
  final String? letter;
  final Uint8List? iconBytes; // Ícono real de la app instalada (PNG)
  final String? packageName;
  final String category; // Id de categoría automática (ver kAutoCategories)
  int usageScore; // Minutos en primer plano dentro de la ventana analizada
  final bool isSystemScanned;
}

class AppGroup {
  AppGroup(this.label, this.apps, {this.isCustom = false, List<String>? packages})
      : packages = packages ?? <String>[];

  final String label;
  final List<HubApp> apps;
  final bool isCustom; // True si fue creado manualmente por el usuario
  final List<String> packages; // Membresía manual (solo grupos personalizados)

  void sortByUsage() {
    apps.sort((a, b) {
      final byUsage = b.usageScore.compareTo(a.usageScore);
      return byUsage != 0
          ? byUsage
          : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  }
}

// =============================================================================
// CATEGORÍAS AUTOMÁTICAS (PREESTABLECIDAS)
// =============================================================================
class AutoCategory {
  const AutoCategory(this.id, this.label);
  final String id;
  final String label;
}

const List<AutoCategory> kAutoCategories = [
  AutoCategory('ai', 'Agentes de IA'),
  AutoCategory('game', 'Gaming Hub'),
  AutoCategory('social', 'Social'),
  AutoCategory('media', 'Multimedia'),
  AutoCategory('productivity', 'Productividad'),
  AutoCategory('maps', 'Mapas y Navegación'),
  AutoCategory('news', 'Noticias'),
  AutoCategory('other', 'Otras apps'),
];

// Android no tiene una categoría "IA", así que se detecta por palabras clave
// en el package o el nombre. Edita esta lista a tu gusto.
const List<String> kAiKeywords = [
  'chatgpt', 'openai', 'claude', 'anthropic', 'gemini', 'copilot',
  'perplexity', 'deepseek', 'grok', 'mistral',
];

// =============================================================================
// PUENTE NATIVO ANDROID (MethodChannel propio, sin dependencias externas)
// =============================================================================
class DeviceAppInfo {
  const DeviceAppInfo({
    required this.packageName,
    required this.name,
    required this.category,
    required this.usageMinutes,
    this.icon,
  });

  final String packageName;
  final String name;
  final String category; // game, social, media, productivity, maps, news, undefined
  final int usageMinutes;
  final Uint8List? icon;
}


class RadialAction {
  const RadialAction(this.id, this.label, this.icon);
  final String id;
  final String label;
  final IconData icon;
}

const List<RadialAction> kFabActions = [
  RadialAction('folder', 'Nuevo Grupo', Icons.create_new_folder_outlined),
  RadialAction('add_app', 'Añadir App', Icons.add_to_photos_rounded),
  RadialAction('scan_device', 'Escanear Apps', Icons.radar_rounded),
  RadialAction('settings', 'Ajustes', Icons.settings_outlined),
];
