import 'config.dart';

/// A link target the app can open from outside the running UI: a tapped
/// share link, an Android App Link / iOS Universal Link, or the web address
/// bar. Parsing is kept free of Flutter/plugin imports so it can be unit
/// tested directly; the actual navigation lives in [DeepLinkService].
sealed class DeepLink {
  const DeepLink();

  /// Parses a person or path link out of [uri], or returns null when [uri]
  /// is not a recognised app link.
  ///
  /// Both path- and query-based shapes are accepted so the *same* URL works
  /// as a native App/Universal Link (matched on path) and in the plain web
  /// address bar:
  ///
  ///   `/person/<id>`          `?person=<id>`
  ///   `/path/<from>/<to>`     `?from=<id>&to=<id>`
  static DeepLink? parse(Uri uri) {
    final segments =
        uri.pathSegments.where((s) => s.isNotEmpty).toList(growable: false);

    if (segments.length == 2 && segments[0] == 'person') {
      final id = int.tryParse(segments[1]);
      if (id != null && id > 0) return PersonLink(id);
    }
    if (segments.length == 3 && segments[0] == 'path') {
      final from = int.tryParse(segments[1]);
      final to = int.tryParse(segments[2]);
      if (from != null && to != null && from > 0 && to > 0) {
        return PathLink(from: from, to: to);
      }
    }

    final person = int.tryParse(uri.queryParameters['person'] ?? '');
    if (person != null && person > 0) return PersonLink(person);
    final from = int.tryParse(uri.queryParameters['from'] ?? '');
    final to = int.tryParse(uri.queryParameters['to'] ?? '');
    if (from != null && to != null && from > 0 && to > 0) {
      return PathLink(from: from, to: to);
    }

    return null;
  }
}

/// Opens a single person's tree, centered on [id] — mirrors
/// `TreePage.initialPersonId`.
class PersonLink extends DeepLink {
  const PersonLink(this.id);

  final int id;
}

/// Opens the "from ancestor → to descendant" path view — mirrors
/// `TreePage.initialPath`.
class PathLink extends DeepLink {
  const PathLink({required this.from, required this.to});

  final int from;
  final int to;
}

/// The public, shareable URL for a person's tree (e.g.
/// `https://omaritree.com/person/4356`). The host comes from
/// [AppConfig.shareBaseUrl], so on the web it self-configures to whatever
/// origin the app is served from.
Uri personShareUri(int id) => Uri.parse('${AppConfig.shareBaseUrl}/person/$id');

/// The public, shareable URL for a from→to path view (e.g.
/// `https://omaritree.com/path/12/4356`).
Uri pathShareUri(int from, int to) =>
    Uri.parse('${AppConfig.shareBaseUrl}/path/$from/$to');
