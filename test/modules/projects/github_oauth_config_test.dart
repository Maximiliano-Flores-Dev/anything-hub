import 'package:flutter_test/flutter_test.dart';
import 'package:anything_hub/modules/projects/services/github_oauth_service.dart';

void main() {
  test('isConfigured is false while clientId is placeholder', () {
    expect(GitHubOAuthService.isConfigured, isFalse);
    expect(GitHubOAuthService.clientId, 'YOUR_GITHUB_OAUTH_CLIENT_ID');
  });

  test('redirect URI and scopes match plan', () {
    expect(GitHubOAuthService.redirectUri, 'anythings-hub://oauth/callback');
    expect(GitHubOAuthService.scopes, containsAll(['repo', 'read:user']));
  });
}
