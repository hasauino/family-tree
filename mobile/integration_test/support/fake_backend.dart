import 'dart:convert';

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphview/GraphView.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:family_tree_mobile/auth/auth_service.dart';
import 'package:family_tree_mobile/auth/social_sign_in.dart';
import 'package:family_tree_mobile/config.dart';
import 'package:family_tree_mobile/graphql/graphql_client.dart';

/// A single person held by the [FakeFamilyBackend] in memory.
class FakePerson {
  FakePerson({
    required this.id,
    required this.name,
    this.parentId,
    this.designation = '',
    this.history = '',
    this.published = true,
    this.bookmarked = false,
  });

  final int id;
  final int? parentId;
  String name;
  String designation;
  String history;
  bool published;
  bool bookmarked;
}

/// An in-memory stand-in for the Django GraphQL backend, used by the GUI tests.
///
/// It plugs into the *real* app through the existing transport seam
/// (`GraphQLClient(httpClient: ...)`): every GraphQL call the app makes is
/// served from this store, and mutations (add child, edit, delete, …) really
/// change it — so "add a child then search for it" is a genuine round-trip,
/// just without a server. The entire Dart stack (widgets → controller →
/// `FamilyApi` → GraphQL document parsing) runs unmodified.
class FakeFamilyBackend {
  FakeFamilyBackend() {
    // Seed a tiny tree rooted at the id the app opens on launch.
    _people[AppConfig.rootPersonId] =
        FakePerson(id: AppConfig.rootPersonId, name: 'Grandfather');
    _seed('Father', parentId: AppConfig.rootPersonId);
  }

  FakeFamilyBackend._empty();

  /// Builds a backend whose tree is wide and deep enough that re-rooting
  /// moves nodes to very different on-screen positions — for testing the
  /// "center on load" / "Center tree here" behaviors, where a too-small tree
  /// could pass by coincidence. [AppConfig.rootPersonId] ("Root") sits two
  /// generations below the top ancestor and branches into [childrenPerNode]
  /// children, each with [childrenPerNode] children of its own, so its
  /// bootstrap view spans the full five generations the app loads
  /// (great-grandparent through grandchildren).
  factory FakeFamilyBackend.branching({int childrenPerNode = 5}) {
    final backend = FakeFamilyBackend._empty();
    final greatGrandparent = backend._seed('Great-Grandparent');
    final grandparent =
        backend._seed('Grandparent', parentId: greatGrandparent);
    backend._people[AppConfig.rootPersonId] = FakePerson(
      id: AppConfig.rootPersonId,
      name: 'Root',
      parentId: grandparent,
    );
    for (var i = 0; i < childrenPerNode; i++) {
      final child =
          backend._seed('Child $i', parentId: AppConfig.rootPersonId);
      for (var j = 0; j < childrenPerNode; j++) {
        backend._seed('Grandchild $i-$j', parentId: child);
      }
    }
    return backend;
  }

  final Map<int, FakePerson> _people = {};
  int _nextId = 1;

  // --- auth config the fake reports (tests can flip these before building an
  // AuthService to exercise the sign-in UI for different provider mixes).
  bool emailEnabled = true;
  bool googleEnabled = false;
  bool appleEnabled = false;
  bool facebookEnabled = false;
  bool requireActivation = true;

  /// Adds a person named [name] (optionally under [parentId]) and returns
  /// their id.
  int _seed(String name, {int? parentId}) {
    final id = _nextId++;
    _people[id] = FakePerson(id: id, name: name, parentId: parentId);
    return id;
  }

  /// An [AuthService] that talks only to this fake and is seen as a staff user
  /// (so every action — add/edit/publish/bookmark/delete — is available).
  AuthService authAsStaff() => authWith();

  /// An [AuthService] wired to this fake, optionally with a fake [social]
  /// provider so the social sign-in buttons can be exercised in tests.
  AuthService authWith({SocialSignIn? social}) => AuthService(
        client: GraphQLClient(httpClient: MockClient(_handle)),
        social: social,
      );

  /// All people currently stored with exactly [name] (for assertions).
  List<FakePerson> personsNamed(String name) =>
      _people.values.where((p) => p.name == name).toList();

  Iterable<FakePerson> _childrenOf(int id) =>
      _people.values.where((p) => p.parentId == id);

  // --- request routing ----------------------------------------------------

  Future<http.Response> _handle(http.Request request) async {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    final doc = body['query'] as String;
    final vars = ((body['variables'] as Map?) ?? const {}).cast<String, dynamic>();

    if (doc.contains('me {')) {
      return _ok({
        'me': {'username': 'tester', 'isStaff': true, 'isAuthenticated': true},
      });
    }

    // --- auth: config query + sign-in/up mutations ------------------------
    if (doc.contains('authConfig')) {
      return _ok({
        'authConfig': {
          'emailEnabled': emailEnabled,
          'googleEnabled': googleEnabled,
          'appleEnabled': appleEnabled,
          'facebookEnabled': facebookEnabled,
          'requireActivation': requireActivation,
        },
      });
    }
    if (doc.contains('passwordLogin(')) {
      // Accept the canned password "pw"; reject anything else.
      if (vars['password'] == 'pw') {
        return _ok({'passwordLogin': _authReplyUser('tester')});
      }
      return _ok({'passwordLogin': _authReplyFail('Invalid credentials')});
    }
    if (doc.contains('socialLogin(')) {
      return _ok({'socialLogin': _authReplyUser('social-user')});
    }
    if (doc.contains('registerEmail(')) {
      if (requireActivation) {
        return _ok({
          'registerEmail': {'ok': true, 'message': 'activation_sent', 'user': null},
        });
      }
      return _ok({'registerEmail': _authReplyUser('newbie')});
    }
    if (doc.contains('verifyEmailCode(')) {
      // Accept the canned code "123456" (verifies + signs in); reject the rest.
      if (vars['code'] == '123456') {
        return _ok({'verifyEmailCode': _authReplyUser('newbie')});
      }
      return _ok({'verifyEmailCode': _authReplyFail('code_invalid')});
    }
    if (doc.contains('resendCode(')) {
      return _ok({
        'resendCode': {'ok': true, 'message': 'code_sent', 'user': null},
      });
    }
    if (doc.contains('requestPasswordReset(')) {
      return _ok({
        'requestPasswordReset': {'ok': true, 'message': 'code_sent', 'user': null},
      });
    }
    if (doc.contains('resetPassword(')) {
      // Accept the canned code "123456" (resets + signs in); reject the rest.
      if (vars['code'] == '123456') {
        return _ok({'resetPassword': _authReplyUser('tester')});
      }
      return _ok({'resetPassword': _authReplyFail('code_invalid')});
    }

    // Mutations (checked before the matching read fields to avoid substring
    // collisions like publish/publishStatus and bookmark/unbookmark).
    if (doc.contains('addPerson(')) {
      final child = FakePerson(
        id: _nextId++,
        name: vars['childName'] as String,
        parentId: (vars['id'] as num).toInt(),
      );
      _people[child.id] = child;
      return _ok({'addPerson': _resultNode(child)});
    }
    if (doc.contains('editPerson(')) {
      final p = _people[(vars['id'] as num).toInt()]!;
      if (vars['name'] != null) p.name = vars['name'] as String;
      if (vars['designation'] != null) p.designation = vars['designation'] as String;
      if (vars['history'] != null) p.history = vars['history'] as String;
      return _ok({'editPerson': _resultNode(p)});
    }
    if (doc.contains('deletePerson(')) {
      _people.remove((vars['id'] as num).toInt());
      return _ok({'deletePerson': _status()});
    }
    if (doc.contains('unpublishPerson(')) {
      _people[(vars['id'] as num).toInt()]?.published = false;
      return _ok({'unpublishPerson': _status()});
    }
    if (doc.contains('publishPerson(')) {
      _people[(vars['id'] as num).toInt()]?.published = true;
      return _ok({'publishPerson': _status()});
    }
    if (doc.contains('unbookmarkPerson(')) {
      _people[(vars['id'] as num).toInt()]?.bookmarked = false;
      return _ok({'unbookmarkPerson': _status()});
    }
    if (doc.contains('bookmarkPerson(')) {
      _people[(vars['id'] as num).toInt()]?.bookmarked = true;
      return _ok({'bookmarkPerson': _status()});
    }

    // Reads.
    if (doc.contains('searchPersons(')) {
      final q = (vars['query'] as String).toLowerCase();
      final matches = _people.values
          .where((p) => p.name.toLowerCase().contains(q))
          .toList();
      return _ok({
        'searchPersons': [
          for (final p in matches) {'id': p.id, 'name': p.name},
        ],
      });
    }
    if (doc.contains('canDelete(')) {
      return _ok({'canDelete': true});
    }
    if (doc.contains('connectedNodes(')) {
      final id = (vars['id'] as num).toInt();
      final p = _people[id];
      final parent = p?.parentId == null ? null : _people[p!.parentId];
      return _ok({
        'connectedNodes': {
          'parent': parent == null ? null : _node(parent),
          'children': [for (final c in _childrenOf(id)) _node(c)],
        },
      });
    }
    if (doc.contains('person(id:')) {
      final id = int.parse(vars['id'].toString());
      final p = _people[id];
      if (p == null) return _ok({'person': null});
      if (doc.contains('published')) {
        return _ok({
          'person': {'published': p.published, 'bookmarked': p.bookmarked},
        });
      }
      if (doc.contains('parent {') || doc.contains('children {')) {
        return _ok({'person': _bootstrapPerson(p)});
      }
      return _ok({'person': _personJson(p)}); // personDetails
    }

    return _ok(const {});
  }

  // --- response shaping ---------------------------------------------------

  http.Response _ok(Map<String, dynamic> data) => http.Response(
        jsonEncode({'data': data}),
        200,
        headers: const {'content-type': 'application/json'},
      );

  Map<String, dynamic> _status() => {'ok': true, 'message': null};

  /// An `{ok, message, user}` auth reply for a signed-in [username].
  Map<String, dynamic> _authReplyUser(String username) => {
        'ok': true,
        'message': null,
        'user': {
          'username': username,
          'isStaff': true,
          'isAuthenticated': true,
        },
      };

  Map<String, dynamic> _authReplyFail(String message) =>
      {'ok': false, 'message': message, 'user': null};

  /// A `connectedNodes`-shaped node (also used as the base of mutation results).
  Map<String, dynamic> _node(FakePerson p) => {
        'id': p.id,
        'label': p.name,
        'group': 'g${(p.parentId ?? 0) % 11}',
        'opacity': p.published ? 1.0 : 0.3,
        'title': _title(p),
        'font': {'strokeWidth': 0},
      };

  Map<String, dynamic> _resultNode(FakePerson p) => {..._node(p), ..._status()};

  String? _title(FakePerson p) {
    final t = '${p.designation}\n${p.history}'.trim();
    return t.isEmpty ? null : t;
  }

  /// A `PersonType`-shaped json (id/name/designation/history).
  Map<String, dynamic> _personJson(FakePerson p) => {
        'id': p.id.toString(),
        'name': p.name,
        'designation': p.designation,
        'history': p.history,
      };

  /// The nested person used by the bootstrap query: ancestors up two levels and
  /// descendants down two levels, matching `FamilyApi.bootstrap`.
  Map<String, dynamic> _bootstrapPerson(FakePerson p) {
    final m = _personJson(p);
    final parent = p.parentId == null ? null : _people[p.parentId];
    m['parent'] = parent == null
        ? null
        : () {
            final pm = _personJson(parent);
            final gp = parent.parentId == null ? null : _people[parent.parentId];
            pm['parent'] = gp == null
                ? null
                : {
                    ..._personJson(gp),
                    'parent': gp.parentId == null
                        ? null
                        : {'id': gp.parentId.toString()},
                  };
            return pm;
          }();
    m['children'] = [
      for (final c in _childrenOf(p.id))
        {
          ..._personJson(c),
          'children': [for (final g in _childrenOf(c.id)) _personJson(g)],
        },
    ];
    return m;
  }
}

/// The on-screen center of the tree node for person [id].
///
/// GraphView paints all node widgets through one custom layout box and keeps
/// each node's position in the graph *model* (`node.position`), not in the
/// render tree — so `localToGlobal`/`parentData` on the child widgets are
/// useless for locating a node. We read the model position and add the graph's
/// global origin to get a point that hit-tests onto the node.
///
/// Note: GraphView refuses all hit tests while its layout animation is running
/// (`hitTestChildren` returns false), so let the tree settle (see
/// [settleTree]) before tapping.
Offset nodeCenter(WidgetTester tester, int id) {
  final graphOrigin =
      tester.renderObject<RenderBox>(find.byType(GraphView)).localToGlobal(Offset.zero);
  final node =
      tester.widget<GraphView>(find.byType(GraphView)).graph.nodes.firstWhere(
            (n) => n.key?.value == id,
          );
  return graphOrigin + node.position + node.size.center(Offset.zero);
}

/// Pumps long enough for GraphView's layout animation to finish, after which
/// node positions are final and nodes become hit-testable.
Future<void> settleTree(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 1));

/// Pumps frames until [finder] matches or [timeout] elapses.
///
/// Use this instead of `pumpAndSettle` whenever a `CircularProgressIndicator`
/// may be on screen — its animation never settles, so `pumpAndSettle` would
/// hang. This drives real frames so taps/layout still happen.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for: $finder');
}
