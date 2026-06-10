import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:family_tree_mobile/config.dart';
import 'package:family_tree_mobile/main.dart';
import 'package:family_tree_mobile/theme_controller.dart';

import 'support/fake_backend.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('add a child via the GUI, then confirm it through search',
      (tester) async {
    // A persisted session makes the app start signed in (as staff) without
    // walking through the login screen.
    SharedPreferences.setMockInitialValues({
      'auth.cookies': jsonEncode({'sessionid': 'fake', 'csrftoken': 'fake'}),
    });

    final backend = FakeFamilyBackend();
    final auth = backend.authAsStaff();
    await auth.restore();

    await tester.pumpWidget(
      FamilyTreeApp(auth: auth, theme: ThemeController()),
    );
    await pumpUntilFound(tester, find.text('Grandfather'));
    await settleTree(tester); // GraphView ignores taps until layout settles

    // Long-press the root node to open the actions sheet, then "Add child".
    await tester.longPressAt(nodeCenter(tester, AppConfig.rootPersonId));
    await pumpUntilFound(tester, find.text('Add child'));
    await tester.tap(find.text('Add child'));

    // Fill in the name and confirm in the dialog.
    await pumpUntilFound(tester, find.byType(TextField));
    await tester.enterText(find.byType(TextField).last, 'New Kid');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));

    // Back on the tree: open the blurred search overlay and look it up.
    await pumpUntilFound(tester, find.byIcon(Icons.search));
    await tester.tap(find.byIcon(Icons.search));
    await pumpUntilFound(tester, find.byType(TextField));
    await tester.enterText(find.byType(TextField).last, 'New Kid');
    await tester.pump(const Duration(milliseconds: 350)); // pass the debounce

    // The search results list shows the newly added child...
    await pumpUntilFound(tester, find.widgetWithText(ListTile, 'New Kid'));
    expect(find.widgetWithText(ListTile, 'New Kid'), findsOneWidget);

    // ...and it was really persisted in the (fake) backend.
    expect(backend.personsNamed('New Kid'), hasLength(1));
  });
}
