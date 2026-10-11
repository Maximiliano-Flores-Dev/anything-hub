import 'package:flutter_test/flutter_test.dart';
import 'package:anything_hub/modules/projects/services/github_oauth_service.dart';

void main() {
  test('isConfigured is true when clientId is set', () {
    expect(GitHubOAuthService.clientId, isNotEmpty);
    expect(GitHubOAuthService.clientId, isNot(equals('YOUR_GITHUB_OAUTH_CLIENT_ID')));
    expect(GitHubOAuthService.isConfigured, isTrue);
  });

  test('redirect URI and scopes match plan', () {
    expect(GitHubOAuthService.redirectUri, 'anythings-hub://oauth/callback');
    expect(GitHubOAuthService.scopes, containsAll(['repo', 'read:user']));
  });
}
