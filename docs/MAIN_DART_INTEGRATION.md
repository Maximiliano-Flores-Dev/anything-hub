# Integracion en lib/main.dart

## 1. Imports (despues de url_launcher)
```dart
import 'modules/projects/services/project_activation_service.dart';
import 'modules/projects/services/project_fs_service.dart';
import 'modules/projects/services/oauth_deep_link_handler.dart';
import 'modules/projects/ui/advisement_modal.dart';
import 'modules/projects/ui/projects_screen.dart';
```

## 2. En main() despues de SystemChrome:
```dart
  OAuthDeepLinkHandler.init();
```

## 3. Metodo (dentro de _MainLayoutScreenState):
```dart
  Future<void> _openProjectsModule() async {
    await ProjectActivationService.incrementAttempts();
    final activated = await ProjectActivationService.isActivated();
    if (activated) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const ProjectsScreen()),
      );
      return;
    }

    final shouldShow = await ProjectActivationService.shouldShowAdvisement();
    if (!shouldShow) {
      SystemLogger.log('Projects module: advisement dismissed permanently');
      return;
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ProjectAdvisementModal(
        onAccepted: () async {
          Navigator.of(ctx).pop();
          try {
            await ProjectFsService.ensureStructure();
          } catch (e) {
            SystemLogger.log('Error creando .anythinghub/: $e');
          }
          if (!mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const ProjectsScreen()),
          );
        },
        onCancelled: () => Navigator.of(ctx).pop(),
      ),
    );
  }
```

## 4. En el onTap de las cards:
```dart
                  } else if (i == 1) {
                    _openProjectsModule(); // Carpetas del Proyecto
```
