import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;

/// Web: browsers manage the session cookie themselves and disallow scripts
/// from reading `Set-Cookie` or setting the `Cookie` header, so
/// [GraphQLClient]'s manual cookie jar is a no-op here. Instead, send
/// requests with credentials so the browser attaches/stores the Django
/// session cookie for cross-origin calls to the API server.
http.Client createPlatformClient() => BrowserClient()..withCredentials = true;
