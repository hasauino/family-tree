import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:http/http.dart' as http;

import '../config.dart';

/// Thrown when the GraphQL server responds with an `errors` array or a
/// non-200 status. The message is the first error returned by the backend
/// (e.g. "Access Denied!" from the auth decorators).
class GraphQLException implements Exception {
  GraphQLException(this.message);
  final String message;
  @override
  String toString() => 'GraphQLException: $message';
}

/// Thrown when a requested person id does not exist. Carries the id so the UI
/// can show a localized "person not found" message.
class PersonNotFoundException extends GraphQLException {
  PersonNotFoundException(this.personId)
      : super('Person #$personId was not found.');
  final int personId;
}

/// Thrown when no ancestor→descendant chain exists between the two requested
/// persons (or either is not visible to the current user).
class NoTreePathException extends GraphQLException {
  NoTreePathException() : super('No path exists between these two people.');
}

/// Thrown when login credentials are rejected by the Django backend.
class InvalidCredentialsException extends GraphQLException {
  InvalidCredentialsException() : super('Invalid username or password.');
}

/// Thrown when a sign-in/sign-up mutation returns `ok: false`; [message] is the
/// backend's reason (e.g. "An account with this email already exists"), already
/// suitable to surface to the user.
class AuthFailedException extends GraphQLException {
  AuthFailedException(super.message);
}

/// Thrown when a native social sign-in (Google/Apple/Facebook) is dismissed by
/// the user before a token is obtained, so the UI can stay silent rather than
/// showing an error.
class SocialSignInCancelled implements Exception {
  const SocialSignInCancelled();
}

/// Minimal GraphQL-over-HTTP client for the Django `graphene` endpoint, with
/// just enough Django session support to drive the authenticated mutations
/// (add child / delete / publish / bookmark).
///
/// Cookie handling is deliberately tiny: we only track the two cookies Django
/// uses — `sessionid` (the login session) and `csrftoken`. The `/graphql`
/// endpoint is `csrf_exempt` on the server, so once we hold a `sessionid`
/// cookie the mutations authenticate purely from it.
class GraphQLClient {
  GraphQLClient({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final http.Client _http;

  /// The cookies we echo back to the server (`sessionid`, `csrftoken`).
  final Map<String, String> _cookies = {};

  /// Restore a previously persisted session (see `AuthService`).
  void restoreCookies(Map<String, String> cookies) {
    _cookies
      ..clear()
      ..addAll(cookies);
  }

  /// A snapshot of the current cookies, for persistence.
  Map<String, String> get cookies => Map.unmodifiable(_cookies);

  bool get hasSession => _cookies.containsKey('sessionid');

  /// The app's active language code, sent to Django so server-rendered content
  /// (e.g. the verification email) matches the UI language. Mirrors the
  /// resolution in [AppConfig]: a forced locale wins, otherwise the device
  /// language when supported, else the first supported locale.
  static String get _languageCode {
    final forced = AppConfig.locale?.languageCode;
    if (forced != null) return forced;
    final device = PlatformDispatcher.instance.locale.languageCode;
    final supported = AppConfig.supportedLocales.map((l) => l.languageCode);
    return supported.contains(device)
        ? device
        : AppConfig.supportedLocales.first.languageCode;
  }

  /// Cookies echoed to the server. We always include `language` (which Django's
  /// `force_language_cookie`/`LocaleMiddleware` reads to pick the language)
  /// alongside the session cookies.
  String get _cookieHeader {
    final all = {..._cookies, 'language': _languageCode};
    return all.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  /// Captures `sessionid` / `csrftoken` from a response's `Set-Cookie` header.
  /// Django emits each cookie in its own directive but Dart's http client folds
  /// them into one comma-joined string; rather than parse that (cookie expiry
  /// dates contain commas), we just pluck the two values we care about.
  void _captureCookies(http.Response response) {
    final raw = response.headers['set-cookie'];
    if (raw == null) return;
    for (final name in const ['sessionid', 'csrftoken']) {
      final match = RegExp('$name=([^;]+)').firstMatch(raw);
      if (match != null) _cookies[name] = match.group(1)!;
    }
  }

  Future<Map<String, dynamic>> query(
    String document, {
    Map<String, dynamic> variables = const {},
  }) async {
    final http.Response response;
    try {
      response = await _http.post(
        Uri.parse(AppConfig.graphqlUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Accept-Language': _languageCode,
          'Cookie': _cookieHeader,
        },
        body: jsonEncode({'query': document, 'variables': variables}),
      );
    } catch (e) {
      // ignore: avoid_print
      print('GRAPHQL_DEBUG url=${AppConfig.graphqlUrl} error=$e');
      throw GraphQLException(
        'Could not reach the server at ${AppConfig.graphqlUrl}. '
        'Is the Django dev server running?',
      );
    }

    _captureCookies(response);

    if (response.statusCode != 200) {
      throw GraphQLException('Server returned HTTP ${response.statusCode}.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final errors = body['errors'] as List<dynamic>?;
    if (errors != null && errors.isNotEmpty) {
      final first = errors.first as Map<String, dynamic>;
      throw GraphQLException((first['message'] as String?) ?? 'Unknown error');
    }
    return (body['data'] as Map<String, dynamic>?) ?? const {};
  }

  /// Logs in against Django's session auth at `/accounts/login/`.
  ///
  /// Django's CSRF protection accepts the raw `csrftoken` cookie value as the
  /// form's `csrfmiddlewaretoken`, so we GET the login page to obtain that
  /// cookie, then POST the credentials with it. On success Django replies with
  /// a 302 redirect and a `sessionid` cookie.
  Future<void> login(String username, String password) async {
    final loginUrl = Uri.parse('${AppConfig.baseUrl}/accounts/login/');

    final http.Response getResponse;
    try {
      getResponse = await _http.get(loginUrl);
    } catch (e) {
      throw GraphQLException(
        'Could not reach the server at ${AppConfig.baseUrl}.',
      );
    }
    _captureCookies(getResponse);
    final csrf = _cookies['csrftoken'];
    if (csrf == null) {
      throw GraphQLException('Server did not issue a CSRF token.');
    }

    final request = http.Request('POST', loginUrl)
      ..followRedirects = false
      ..headers.addAll({
        'Content-Type': 'application/x-www-form-urlencoded',
        'Cookie': _cookieHeader,
        'Referer': loginUrl.toString(),
      })
      ..bodyFields = {
        'username': username,
        'password': password,
        'csrfmiddlewaretoken': csrf,
      };

    final http.Response response;
    try {
      response = await http.Response.fromStream(await _http.send(request));
    } catch (e) {
      throw GraphQLException(
        'Could not reach the server at ${AppConfig.baseUrl}.',
      );
    }
    _captureCookies(response);

    // A 302 redirect with a fresh sessionid means success; a 200 means Django
    // re-rendered the login form, i.e. the credentials were rejected.
    if (response.statusCode != 302 || !hasSession) {
      throw InvalidCredentialsException();
    }
  }

  /// Drops the local session. (The server session lingers until it expires,
  /// which is fine — without the cookie we are anonymous again.)
  void clearSession() {
    _cookies.remove('sessionid');
  }

  void dispose() => _http.close();
}
