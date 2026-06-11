import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../graphql/family_api.dart';
import '../graphql/graphql_client.dart';
import 'social_sign_in.dart';

/// Holds the signed-in user and brokers login/logout for the whole app.
///
/// The Django session is cookie-based, so we persist the client's cookies to
/// `SharedPreferences` and restore them on launch — the user stays logged in
/// across restarts until the session expires. Staff-only actions are gated on
/// [isStaff], which comes from the backend `me` query.
class AuthService extends ChangeNotifier {
  AuthService({GraphQLClient? client, SocialSignIn? social})
      : _client = client ?? GraphQLClient(),
        _social = social ?? NativeSocialSignIn() {
    _api = FamilyApi(_client);
  }

  static const _cookiesKey = 'auth.cookies';

  final GraphQLClient _client;
  final SocialSignIn _social;
  late final FamilyApi _api;

  /// The shared client/api so the rest of the app sends the same session.
  GraphQLClient get client => _client;
  FamilyApi get api => _api;

  String? _username;
  bool _isStaff = false;
  bool _ready = false;

  String? get username => _username;
  bool get isStaff => _isStaff;
  bool get isAuthenticated => _username != null;

  /// True once [restore] has finished, so the UI can avoid flashing the
  /// signed-out state on launch.
  bool get ready => _ready;

  /// Reloads any persisted cookies and re-validates them against the server.
  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_cookiesKey);
    if (stored != null) {
      final decoded = (jsonDecode(stored) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v as String));
      _client.restoreCookies(decoded);
      await _refreshMe();
    }
    _ready = true;
    notifyListeners();
  }

  /// The cached config of which sign-in methods the backend offers. Null until
  /// [loadAuthConfig] resolves; callers should fall back to [AuthConfig.fallback].
  AuthConfig? _authConfig;
  AuthConfig? get authConfig => _authConfig;

  /// Fetches (and caches) which sign-in methods the backend has enabled. Safe to
  /// call repeatedly; returns the fallback (email-only) if the server can't be
  /// reached so the UI still renders.
  Future<AuthConfig> loadAuthConfig({bool force = false}) async {
    if (_authConfig != null && !force) return _authConfig!;
    try {
      _authConfig = await _api.authConfig();
    } catch (_) {
      _authConfig = AuthConfig.fallback;
    }
    notifyListeners();
    return _authConfig!;
  }

  /// Signs in with an email or username plus [password]; throws on failure
  /// ([AuthFailedException] carries a user-facing message).
  Future<void> loginWithPassword(String identifier, String password) async {
    await _api.passwordLogin(identifier, password);
    await _afterSignIn();
  }

  /// Registers a new email account. Returns whether the user was signed in
  /// immediately or an activation email was sent; throws [AuthFailedException]
  /// on validation errors.
  Future<RegisterResult> register(
    String email,
    String password, {
    String? firstName,
    String? lastName,
  }) async {
    final result = await _api.registerEmail(
      email,
      password,
      firstName: firstName,
      lastName: lastName,
    );
    if (result.outcome == RegisterOutcome.signedIn) {
      await _afterSignIn();
    }
    return result;
  }

  /// Confirms a freshly-registered account with the 6-digit [code] emailed to
  /// [email] and signs the user straight in. Throws [AuthFailedException]
  /// carrying the backend message (`code_invalid` / `code_expired` /
  /// `too_many_attempts`) on failure.
  Future<void> verifyEmailCode(String email, String code) async {
    await _api.verifyEmailCode(email, code);
    await _afterSignIn();
  }

  /// Asks the backend to email a fresh verification code to [email]. Throws
  /// [AuthFailedException] (`resend_too_soon`) while the cooldown is active.
  Future<void> resendCode(String email) => _api.resendCode(email);

  /// Asks the backend to email a password-reset code to [email] (also used to
  /// resend). Throws [AuthFailedException] (`resend_too_soon`) during cooldown.
  Future<void> requestPasswordReset(String email) =>
      _api.requestPasswordReset(email);

  /// Verifies the reset [code] and sets [newPassword], then signs the user in.
  /// Throws [AuthFailedException] (`code_invalid` / `code_expired` /
  /// `too_many_attempts`, or a password-policy message) on failure.
  Future<void> resetPassword(String email, String code, String newPassword) async {
    await _api.resetPassword(email, code, newPassword);
    await _afterSignIn();
  }

  /// Runs the native flow for [provider], exchanges the token for a session, and
  /// signs in. Throws [SocialSignInCancelled] if the user backs out.
  Future<void> loginWithProvider(SocialProvider provider) async {
    final credential = await _social.authenticate(provider);
    await _api.socialLogin(
      provider.wireName,
      credential.token,
      firstName: credential.firstName,
      lastName: credential.lastName,
    );
    await _afterSignIn();
  }

  /// Shared tail of every successful sign-in: persist the new session cookies
  /// and refresh who we are.
  Future<void> _afterSignIn() async {
    await _persistCookies();
    await _refreshMe();
    notifyListeners();
  }

  Future<void> logout() async {
    _client.clearSession();
    _username = null;
    _isStaff = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cookiesKey);
    notifyListeners();
  }

  /// Asks the backend who we are; clears state if the session is no longer
  /// valid (e.g. it expired server-side).
  Future<void> _refreshMe() async {
    try {
      final me = await _api.me();
      if (me != null && me.isAuthenticated) {
        _username = me.username;
        _isStaff = me.isStaff;
      } else {
        _username = null;
        _isStaff = false;
      }
    } catch (_) {
      _username = null;
      _isStaff = false;
    }
  }

  Future<void> _persistCookies() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cookiesKey, jsonEncode(_client.cookies));
  }

  @override
  void dispose() {
    _client.dispose();
    super.dispose();
  }
}
