/// Documentación local on-device del módulo de proyectos.
class LocalDocs {
  static const String moduleOverview = '''
# Gestión de Proyectos – Anythings Hub

Módulo opcional orientado a desarrolladores.

## Principios
- Soberanía del archivo local
- Cero telemetría
- Aislamiento total cuando está desactivado
- Tokens OAuth cifrados on-device (Keystore)

## Activación
La tarjeta «Carpetas del Proyecto» está desactivada por defecto.
Al primer toque aparece un aviso. Solo tras aceptar se crea .anythinghub/.

## Estructura
.anythinghub/
├── cache/
├── config/editors.json
├── logs/
└── projects/<nombre>/
    ├── project.md
    └── .gitignore

## Editores (cascada)
1. Editor local preferido (Acode, Markor, Termux…)
2. Cualquier editor de la lista blanca instalado
3. Fallback seguro: vscode.dev (sin token en URL)

## Termux
Intent com.termux.RUN_COMMAND o esquema termux://.

## Desinstalación
Menú ⋮ → Desinstalar módulo (confirmación doble).
''';

  static const String securityChecklist = '''
## Checklist de seguridad
- [x] Tokens solo en Keystore
- [x] PKCE obligatorio (S256)
- [x] Cero logging de código fuente
- [x] Conexiones HTTPS/TLS
- [x] Revocación inmediata de tokens
- [x] Scoped storage
- [x] Borrado completo del módulo
- [x] Módulo desactivado = cero rastro

## Configurar GitHub OAuth
1. GitHub → Settings → Developer settings → OAuth Apps
2. New OAuth App (Public client)
3. Callback: anythings-hub://oauth/callback
4. Client ID en github_oauth_service.dart
''';
}
