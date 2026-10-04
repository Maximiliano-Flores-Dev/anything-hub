import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class GitHubOAuthService {
  static const String clientId = 'YOUR_GITHUB_OAUTH_CLIENT_ID';
  static const String redirectUri = 'anythings-hub://oauth/callback';
  static const String authEndpoint =
      'https://github.com/login/oauth/authorize';
  static const String tokenEndpoint =
      'https://github.com/login/oauth/access_token';
  static const List<String> scopes = ['repo', 'read:user'];

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String _keyAccess = 'gh_access_token';
  static const String _keyRefresh = 'gh_refresh_token';
  static const String _keyExpires = 'gh_expires_at';
  static const String _keyVerifier = 'gh_code_verifier';

  static bool get isConfigured =>
      clientId.isNotEmpty && clientId != 'YOUR_GITHUB_OAUTH_CLIENT_ID';

  static String _generateCodeVerifier({int length = 64}) {
    const charset =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final rand = Random.secure();
    return List.generate(
      length,
      (_) => charset[rand.nextInt(charset.length)],
    ).join();
  }

  static String _generateCodeChallenge(String verifier) {
    final digest = sha256.convert(utf8.encode(verifier));
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  static Future<bool> startAuthFlow() async {
    if (!isConfigured) {
      debugPrint('[GitHubOAuth] Client ID no configurado.');
      return false;
    }

    final verifier = _generateCodeVerifier();
    final challenge = _generateCodeChallenge(verifier);
    await _storage.write(key: _keyVerifier, value: verifier);

    final params = <String, String>{
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'scope': scopes.join(' '),
      'response_type': 'code',
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'state': _generateCodeVerifier(length: 16),
    };

    final uri = Uri.parse(authEndpoint).replace(queryParameters: params);
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  static Future<bool> exchangeCode(String code) async {
    if (!isConfigured) return false;

    final verifier = await _storage.read(key: _keyVerifier);
    if (verifier == null) {
      debugPrint('[GitHubOAuth] No code_verifier stored');
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse(tokenEndpoint),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'client_id': clientId,
          'code': code,
          'redirect_uri': redirectUri,
          'code_verifier': verifier,
          'grant_type': 'authorization_code',
        },
      );

      if (response.statusCode != 200) {
        debugPrint(
          '[GitHubOAuth] Token exchange failed: '
          '${response.statusCode} ${response.body}',
        );
        return false;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final accessToken = data['access_token'] as String?;
      final refreshToken = data['refresh_token'] as String?;
      final expiresIn = data['expires_in'] as int?;

      if (accessToken == null || accessToken.isEmpty) return false;

      await _storage.write(key: _keyAccess, value: accessToken);
      if (refreshToken != null) {
        await _storage.write(key: _keyRefresh, value: refreshToken);
      }
      if (expiresIn != null) {
        final expiresAt = DateTime.now().add(Duration(seconds: expiresIn));
        await _storage.write(
          key: _keyExpires,
          value: expiresAt.toIso8601String(),
        );
      }
      await _storage.delete(key: _keyVerifier);
      return true;
    } catch (e) {
      debugPrint('[GitHubOAuth] exchangeCode error: $e');
      return false;
    }
  }

  static Future<String?> getAccessToken() async {
    return _storage.read(key: _keyAccess);
  }

  static Future<bool> isAuthenticated() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  static Future<void> revokeAndClear() async {
    await _storage.delete(key: _keyAccess);
    await _storage.delete(key: _keyRefresh);
    await _storage.delete(key: _keyExpires);
    await _storage.delete(key: _keyVerifier);
  }

  static Future<bool> openVscodeDev({String? folderPath}) async {
    final uri = Uri.parse('https://vscode.dev');
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }
}
