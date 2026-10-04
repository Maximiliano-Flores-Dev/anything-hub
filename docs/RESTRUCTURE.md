# Reestructuración de main.dart

## Estado

El monolito `lib/main.dart` (~146 KB / 4289 líneas) se dividió en módulos.

## Nueva estructura

```
lib/
├── main.dart                          # entry point (~1.5 KB)
├── core/
│   ├── hub_colors.dart                # HubColors + radius12
│   ├── logger.dart                    # SystemLogger
│   └── models.dart                    # HubApp, AppGroup, categorías, RadialAction
├── services/
│   ├── device_apps_service.dart
│   └── device_files_service.dart      # FileEntry, StorageInfo, FileFilter
├── ui/
│   ├── widgets/
│   │   ├── gradient_pill_button.dart
│   │   ├── dashboard_card.dart
│   │   └── card_arts.dart             # AppsArt, SheetsArt, etc.
│   └── sidebar/
│       └── collapsible_sidebar.dart   # sidebar + FAB radial + avatars
├── screens/
│   ├── main_layout_screen.dart        # pantalla principal + integración proyectos
│   ├── web_links_screen.dart
│   └── file_explorer_screen.dart
└── modules/projects/                  # feature Gestión de Proyectos (completo)
```

## Integración del módulo de proyectos

`MainLayoutScreen._openProjectsModule()` conecta:
1. Opt-in via `ProjectActivationService`
2. Modal de asesoramiento (`ProjectAdvisementModal`)
3. Navegación a `ProjectsScreen`
4. Card "Carpetas del Proyecto" en el dashboard
