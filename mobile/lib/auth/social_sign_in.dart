import 'package:flutter/foundation.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../config.dart';
import '../graphql/graphql_client.dart';

/// The third-party identity providers the app can sign in with. The string
/// [name] is exactly what the backend `socialLogin` mutation expects.
enum SocialProvider { google, apple, facebook }

/// The result of a native provider flow: the [token] to hand the backend, plus
/// any profile bits the provider only exposes client-side (Apple gives the name
/// once, in the credential, never in the token).
class SocialCredential {
  const SocialCredential({required this.token, this.firstName, this.lastName});
  final String token;
  final String? firstName;
  final String? lastName;
}

/// Runs the native Google/Apple/Facebook flows. Abstracted behind an interface
/// so [AuthService] depends only on this, and tests can supply a fake that
/// returns canned tokens without touching the platform SDKs.
abstract class SocialSignIn {
  /// Launches [provider]'s native sign-in and returns the credential to send to
  /// the backend. Throws [SocialSignInCancelled] if the user backs out, or a
  /// [GraphQLException] on a real failure.
  Future<SocialCredential> authenticate(SocialProvider provider);
}

/// The production [SocialSignIn] backed by the real platform SDKs.
class NativeSocialSignIn implements SocialSignIn {
  bool _googleReady = false;

  @override
  Future<SocialCredential> authenticate(SocialProvider provider) {
    return switch (provider) {
      SocialProvider.google => _google(),
      SocialProvider.apple => _apple(),
      SocialProvider.facebook => _facebook(),
    };
  }

  Future<SocialCredential> _google() async {
    final signIn = GoogleSignIn.instance;
    if (!_googleReady) {
      await signIn.initialize(
        serverClientId: AppConfig.googleServerClientId.isEmpty
            ? null
            : AppConfig.googleServerClientId,
      );
      _googleReady = true;
    }
    try {
      final account = await signIn.authenticate(scopeHint: const ['email']);
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw GraphQLException('Google did not return an identity token.');
      }
      return SocialCredential(
        token: idToken,
        firstName: account.displayName,
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const SocialSignInCancelled();
      }
      throw GraphQLException('Google sign-in failed: ${e.description ?? e.code}');
    }
  }

  Future<SocialCredential> _apple() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final token = credential.identityToken;
      if (token == null) {
        throw GraphQLException('Apple did not return an identity token.');
      }
      return SocialCredential(
        token: token,
        firstName: credential.givenName,
        lastName: credential.familyName,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw const SocialSignInCancelled();
      }
      throw GraphQLException('Apple sign-in failed: ${e.message}');
    }
  }

  Future<SocialCredential> _facebook() async {
    final result = await FacebookAuth.instance.login(
      permissions: const ['email', 'public_profile'],
    );
    switch (result.status) {
      case LoginStatus.success:
        final token = result.accessToken?.tokenString;
        if (token == null) {
          throw GraphQLException('Facebook did not return an access token.');
        }
        return SocialCredential(token: token);
      case LoginStatus.cancelled:
        throw const SocialSignInCancelled();
      case LoginStatus.failed:
      case LoginStatus.operationInProgress:
        throw GraphQLException(
          'Facebook sign-in failed: ${result.message ?? result.status.name}',
        );
    }
  }
}

extension SocialProviderName on SocialProvider {
  /// The identifier the backend `socialLogin` mutation matches on.
  String get wireName => switch (this) {
    SocialProvider.google => 'google',
    SocialProvider.apple => 'apple',
    SocialProvider.facebook => 'facebook',
  };
}

/// Whether [provider] can run natively on the current platform. Apple sign-in
/// only makes sense on Apple devices (and the web shim); the others are mobile.
bool socialProviderSupported(SocialProvider provider) {
  if (provider == SocialProvider.apple) {
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }
  return true;
}
