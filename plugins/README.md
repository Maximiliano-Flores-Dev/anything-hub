# Plugins de Anythings Hub

Esta carpeta es el **catálogo oficial** de plugins del repositorio.

## Cómo funciona

1. El archivo `catalog.json` lista plugins disponibles (solo metadatos).
2. La app (pantalla **Configuración → Plugins**) descarga ese JSON desde GitHub raw.
3. Al instalar, se copia el `manifest.json` a:

   ```
   /storage/emulated/0/Documents/.anythinghub/plugins/<id>/
   ```

4. **No se ejecuta código remoto.** Los plugins son JSON de configuración / etiquetas / plantillas.

## Añadir un plugin al catálogo

1. Añade una entrada en `catalog.json` con `id`, `name`, `version`, `description`.
2. (Opcional) Sube un `bundle.json` y pon su URL raw en el campo futuro `bundleUrl`.
3. Abre un PR. Al mergearse en `main`, el catálogo se actualiza para todos.

## Seguridad

- Sin carga de `.dex`, `.so` ni scripts ejecutables.
- El File Manager y el análisis de APK siguen en modo **solo visualización** salvo acciones explícitas del usuario.
