import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../graphql/family_api.dart';
import '../graphql/graphql_client.dart';

/// Holds the signed-in user and brokers login/logout for the whole app.
///
/// The Django session is cookie-based, so we persist the client's cookies to
/// `SharedPreferences` and restore them on launch — the user stays logged in
/// across restarts until the session expires. Staff-only actions are gated on
/// [isStaff], which comes from the backend `me` query.
class AuthService extends ChangeNotifier {
  AuthService({GraphQLClient? client})
      : _client = client ?? GraphQLClient() {
    _api = FamilyApi(_client);
  }

  static const _cookiesKey = 'auth.cookies';

  final GraphQLClient _client;
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

  /// Signs in with [username]/[password]; throws on failure (see
  /// [InvalidCredentialsException]).
  Future<void> login(String username, String password) async {
    await _client.login(username, password);
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
