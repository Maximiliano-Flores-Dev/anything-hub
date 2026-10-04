import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import 'github_oauth_service.dart';

/// Escucha el deep-link anythings-hub://oauth/callback y completa el flujo PKCE.
class OAuthDeepLinkHandler {
  static final AppLinks _appLinks = AppLinks();
  static StreamSubscription<Uri>? _sub;

  static Future<void> init() async {
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) await _handle(initial);
    } catch (e) {
      debugPrint('[OAuthDeepLink] initial link error: $e');
    }

    _sub?.cancel();
    _sub = _appLinks.uriLinkStream.listen(
      (uri) => _handle(uri),
      onError: (e) => debugPrint('[OAuthDeepLink] stream error: $e'),
    );
  }

  static Future<void> _handle(Uri uri) async {
    if (uri.scheme != 'anythings-hub' || uri.host != 'oauth') return;
    if (!uri.path.startsWith('/callback')) return;

    final code = uri.queryParameters['code'];
    final error = uri.queryParameters['error'];

    if (error != null) {
      debugPrint('[OAuthDeepLink] GitHub error: $error');
      return;
    }
    if (code == null || code.isEmpty) {
      debugPrint('[OAuthDeepLink] No code in callback');
      return;
    }

    final ok = await GitHubOAuthService.exchangeCode(code);
    debugPrint('[OAuthDeepLink] Token exchange ${ok ? "OK" : "FAILED"}');
  }

  static void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
