import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:family_tree_mobile/config.dart';
import 'package:family_tree_mobile/main.dart';

import 'support/fake_backend.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'centers the root on first load and re-centers on "Center tree here"',
      (tester) async {
    // A persisted session makes the app start signed in (as staff) without
    // walking through the login screen.
    SharedPreferences.setMockInitialValues({
      'auth.cookies': jsonEncode({'sessionid': 'fake', 'csrftoken': 'fake'}),
    });

    // A wide/deep tree (5 generations, 5 children per person) so re-rooting
    // moves nodes to clearly different positions — a tiny tree could pass
    // the centering check by coincidence.
    final backend = FakeFamilyBackend.branching(childrenPerNode: 5);
    final auth = backend.authAsStaff();
    await auth.restore();

    await tester.pumpWidget(FamilyTreeApp(auth: auth));
    await pumpUntilFound(tester, find.text('Root'));
    await settleTree(tester); // GraphView ignores taps until layout settles

    final viewportCenter = tester.getCenter(find.byType(InteractiveViewer));

    // First load: the configured root should already be centered, exactly
    // like tapping a node centers it (tree_page.dart's _loadRootCentered).
    _expectCentered(nodeCenter(tester, AppConfig.rootPersonId), viewportCenter);

    // Long-press a grandchild that's still on screen in the root-centered
    // view but far from the viewport's center — and re-root the tree on it
    // via the actions sheet's "Center tree here".
    final target = backend.personsNamed('Grandchild 2-1').single;
    await tester.longPressAt(nodeCenter(tester, target.id));
    // Found by icon, not the (localized) "Center tree here" label — the app
    // currently forces the Arabic locale (see AppConfig.locale).
    final centerTreeHere = find.byIcon(Icons.center_focus_strong);
    await pumpUntilFound(tester, centerTreeHere);
    await tester.tap(centerTreeHere);

    // Wait for the re-root to land: a sibling from the old bootstrap is gone
    // and the new focal node is on screen (loadRoot resets the whole graph).
    await _pumpUntil(
      tester,
      () =>
          find.text('Grandchild 2-0').evaluate().isEmpty &&
          find.text('Grandchild 2-1').evaluate().isNotEmpty,
    );
    await settleTree(tester);

    _expectCentered(nodeCenter(tester, target.id), viewportCenter);
  });
}

void _expectCentered(Offset actual, Offset expected, {double tolerance = 2.0}) {
  expect(
    actual.dx,
    closeTo(expected.dx, tolerance),
    reason: 'expected $actual to be horizontally centered at $expected',
  );
  expect(
    actual.dy,
    closeTo(expected.dy, tolerance),
    reason: 'expected $actual to be vertically centered at $expected',
  );
}

/// Pumps frames until [condition] holds, for waits that `pumpUntilFound`
/// can't express (e.g. "X is gone and Y is present").
Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (condition()) return;
  }
  throw TestFailure('Timed out waiting for the tree to re-root');
}
