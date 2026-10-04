# Restaurar lib/main.dart integrado

El archivo completo está fragmentado en base64+gzip por límites de la API.

## Opción A (recomendada): desde el commit bueno

```bash
git fetch origin
git checkout 708596b3b42c1d02f47a61677eef76187860e2ef -- lib/main.dart
```

Luego aplica los 4 cambios de `docs/MAIN_DART_INTEGRATION.md` (imports, OAuthDeepLinkHandler.init, _openProjectsModule, onTap i==1).

## Opción B: reconstruir desde partes base64

```bash
cat docs/main_b64_part0.txt docs/main_b64_part1.txt docs/main_b64_part2.txt docs/main_b64_part3.txt | base64 -d | gzip -d > lib/main.dart
```

Esto deja `lib/main.dart` con la integración completa del módulo de proyectos.
