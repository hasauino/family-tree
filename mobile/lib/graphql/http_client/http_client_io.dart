import 'package:http/http.dart' as http;

/// Non-web platforms: a plain client. [GraphQLClient] manages the session
/// cookie itself by echoing it back on the `Cookie` header.
http.Client createPlatformClient() => http.Client();
