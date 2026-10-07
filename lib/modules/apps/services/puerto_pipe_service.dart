import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class PuertoPipeService {
  static const _method = MethodChannel('anythings.hub/puerto');
  static const _events = EventChannel('anythings.hub/puerto_events');
  static const _keyPref = 'virustotal_api_key';

  static Stream<Map<String, dynamic>> download(String url) {
    final controller = StreamController<Map<String, dynamic>>();
    late StreamSubscription sub;
    sub = _events.receiveBroadcastStream().listen(
      (event) {
        if (event is Map) {
          controller.add(event.map((k, v) => MapEntry(k.toString(), v)));
        }
      },
      onError: controller.addError,
      onDone: controller.close,
    );
    _method.invokeMethod<bool>('download', {'url': url}).catchError((e) {
      controller.addError(e);
      return false;
    });
    controller.onCancel = () async {
      await sub.cancel();
      await _method.invokeMethod('cancel');
    };
    return controller.stream;
  }

  static Future<void> saveVirusTotalKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPref, key.trim());
  }

  static Future<String?> virusTotalKey() async {
    final prefs = await SharedPreferences.getInstance();
    final k = prefs.getString(_keyPref);
    if (k == null || k.isEmpty) return null;
    return k;
  }

  /// Consulta el hash. No sube el APK salvo que [uploadIfMissing] sea true.
  static Future<Map<String, dynamic>> virusTotalLookup({
    required String sha256,
    required String apiKey,
    bool uploadIfMissing = false,
  }) async {
    final headers = {'x-apikey': apiKey, 'accept': 'application/json'};
    final report = await http.get(
      Uri.parse('https://www.virustotal.com/api/v3/files/$sha256'),
      headers: headers,
    );
    if (report.statusCode == 200) {
      return _parseReport(report.body);
    }
    if (report.statusCode == 404) {
      return {
        'found': false,
        'note': uploadIfMissing
            ? 'Hash desconocido. La subida del archivo no está activada en este paso.'
            : 'VirusTotal no tiene este hash. No se subió el APK.',
      };
    }
    return {
      'found': false,
      'note': 'VirusTotal respondió ${report.statusCode}',
    };
  }

  static Map<String, dynamic> _parseReport(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final attrs = (json['data'] as Map?)?['attributes'] as Map? ?? {};
    final stats = attrs['last_analysis_stats'] as Map? ?? {};
    return {
      'found': true,
      'malicious': stats['malicious'] ?? 0,
      'suspicious': stats['suspicious'] ?? 0,
      'harmless': stats['harmless'] ?? 0,
      'undetected': stats['undetected'] ?? 0,
    };
  }

  /// Último asset .apk de un release público de GitHub.
  static Future<String?> latestGithubApk(String ownerRepo) async {
    final res = await http.get(
      Uri.parse('https://api.github.com/repos/$ownerRepo/releases/latest'),
      headers: {'User-Agent': 'AnythingsHub', 'Accept': 'application/vnd.github+json'},
    );
    if (res.statusCode != 200) return null;
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final assets = json['assets'] as List? ?? [];
    for (final a in assets) {
      if (a is Map && (a['name'] as String? ?? '').toLowerCase().endsWith('.apk')) {
        final url = a['browser_download_url'] as String?;
        if (url != null && url.startsWith('https://')) return url;
      }
    }
    return null;
  }
}
