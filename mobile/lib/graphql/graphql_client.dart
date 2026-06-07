import 'dart:convert';

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

/// Minimal GraphQL-over-HTTP client for the Django `graphene` endpoint.
///
/// Kept dependency-light on purpose: a single POST with `query` + `variables`,
/// `credentials: same-origin`-style cookie reuse is not needed for the
/// read-only tree (public persons are visible anonymously).
class GraphQLClient {
  GraphQLClient({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final http.Client _http;

  Future<Map<String, dynamic>> query(
    String document, {
    Map<String, dynamic> variables = const {},
  }) async {
    final http.Response response;
    try {
      response = await _http.post(
        Uri.parse(AppConfig.graphqlUrl),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'query': document, 'variables': variables}),
      );
    } catch (e) {
      throw GraphQLException(
        'Could not reach the server at ${AppConfig.graphqlUrl}. '
        'Is the Django dev server running?',
      );
    }

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

  void dispose() => _http.close();
}
