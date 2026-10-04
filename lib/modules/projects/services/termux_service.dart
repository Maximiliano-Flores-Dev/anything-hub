import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Integración con Termux (Hito 3.3).
class TermuxService {
  static const MethodChannel _ch = MethodChannel('anythings.hub/device_apps');

  static Future<bool> runCommand({
    required String projectPath,
    required String command,
    String workingDirectory = '',
  }) async {
    final wd = workingDirectory.isNotEmpty ? workingDirectory : projectPath;

    try {
      final result = await _ch.invokeMethod<bool>('termuxRunCommand', {
        'command': command,
        'workdir': wd,
        'background': false,
      });
      if (result == true) return true;
    } on MissingPluginException {
    } on PlatformException {
    }

    final uri = Uri.parse(
      'termux://run?command=${Uri.encodeComponent(command)}&workdir=${Uri.encodeComponent(wd)}',
    );
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    final openUri = Uri.parse('termux://open?path=${Uri.encodeComponent(wd)}');
    if (await canLaunchUrl(openUri)) {
      await launchUrl(openUri, mode: LaunchMode.externalApplication);
      return false;
    }

    return false;
  }

  static Future<bool> openInFolder(String projectPath) async {
    final uri = Uri.parse('termux://open?path=${Uri.encodeComponent(projectPath)}');
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    try {
      final result = await _ch.invokeMethod<bool>('launchApp', {
        'package': 'com.termux',
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}
