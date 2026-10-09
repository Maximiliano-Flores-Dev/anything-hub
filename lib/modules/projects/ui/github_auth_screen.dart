import 'package:flutter/material.dart';

import '../services/github_oauth_service.dart';
import 'hub_colors_local.dart';

class GitHubAuthScreen extends StatefulWidget {
  const GitHubAuthScreen({super.key});

  @override
  State<GitHubAuthScreen> createState() => _GitHubAuthScreenState();
}

class _GitHubAuthScreenState extends State<GitHubAuthScreen> {
  bool _loading = false;
  bool _authenticated = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final ok = await GitHubOAuthService.isAuthenticated();
    if (!mounted) return;
    setState(() => _authenticated = ok);
  }

  Future<void> _startAuth() async {
    if (!GitHubOAuthService.isConfigured) {
      setState(() {
        _error =
            'Client ID no configurado.\n\n'
            '1. GitHub → Settings → Developer settings → OAuth Apps\n'
            '2. New OAuth App (Public client)\n'
            '3. Callback: anythings-hub://oauth/callback\n'
            '4. Pega el Client ID en github_oauth_service.dart';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final opened = await GitHubOAuthService.startAuthFlow();
      if (!opened) {
        setState(() => _error = 'No se pudo abrir el navegador de autorización.');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _revoke() async {
    await GitHubOAuthService.revokeAndClear();
    if (!mounted) return;
    setState(() => _authenticated = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tokens revocados y eliminados del dispositivo'),
        backgroundColor: HubColors.panel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HubColors.fondoPrincipal,
      appBar: AppBar(
        backgroundColor: HubColors.fondoSidebar,
        elevation: 0,
        title: Text(
          'GitHub · OAuth 2.0 + PKCE',
          style: TextStyle(color: HubColors.textoPrincipal),
        ),
        iconTheme: IconThemeData(color: HubColors.textoPrincipal),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: HubColors.panel,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: HubColors.linea.withOpacity(0.6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _authenticated ? Icons.verified_rounded : Icons.lock_outline_rounded,
                      color: _authenticated ? Colors.greenAccent : HubColors.pomelo,
                      size: 28,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _authenticated ? 'Cuenta vinculada' : 'No autenticado',
                        style: TextStyle(
                          color: HubColors.textoPrincipal,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 14),
                Text(
                  'Los tokens se almacenan únicamente en el Keystore del sistema. '
                  'Nunca se envían a servidores de Anythings Hub ni se incluyen en la URL de vscode.dev.\n\n'
                  'Scope: repo + read:user.',
                  style: TextStyle(color: HubColors.textoSecundario, fontSize: 13.5, height: 1.4),
                ),
              ],
            ),
          ),
          SizedBox(height: 24),
          if (_error != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(_error!, style: TextStyle(color: Colors.redAccent, fontSize: 13, height: 1.35)),
            ),
            SizedBox(height: 12),
          ],
          if (_authenticated)
            OutlinedButton.icon(
              onPressed: _revoke,
              icon: const Icon(Icons.link_off_rounded, color: Colors.redAccent),
              label: Text('Desvincular y revocar tokens',
                  style: TextStyle(color: Colors.redAccent)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.redAccent),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: _loading ? null : _startAuth,
              icon: _loading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: HubColors.fondoPrincipal),
                    )
                  : const Icon(Icons.login_rounded),
              label: Text(_loading ? 'Abriendo GitHub…' : 'Continuar con GitHub'),
              style: ElevatedButton.styleFrom(
                backgroundColor: HubColors.pomelo,
                foregroundColor: HubColors.fondoPrincipal,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
        ],
      ),
    );
  }
}
