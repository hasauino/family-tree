import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:family_tree_mobile/account/account_page.dart';
import 'package:family_tree_mobile/auth/auth_service.dart';
import 'package:family_tree_mobile/l10n/app_strings.dart';
import 'package:family_tree_mobile/theme_controller.dart';

import '../integration_test/support/fake_backend.dart';

/// Pumps [AccountPage] inside a minimal English MaterialApp for an
/// already-signed-in [auth].
Future<void> _pumpAccount(WidgetTester tester, AuthService auth) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const [Locale('en')],
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: AccountPage(auth: auth, theme: ThemeController()),
    ),
  );
  await tester.pumpAndSettle();
}

/// The text currently held by the [n]th `TextFormField` on screen.
String _fieldText(WidgetTester tester, int n) => tester
    .widget<EditableText>(
      find.descendant(
        of: find.byType(TextFormField).at(n),
        matching: find.byType(EditableText),
      ),
    )
    .controller
    .text;

void main() {
  // AuthService persists session cookies after sign-in; back it with an
  // in-memory store so the widget tests don't hit the platform channel.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows the signed-in user\'s profile fields', (tester) async {
    final backend = FakeFamilyBackend()
      ..email = 'ada@example.com'
      ..firstName = 'Ada'
      ..lastName = 'Lovelace'
      ..birthPlace = 'London';
    final auth = backend.authWith();
    await auth.loginWithPassword('tester', 'pw');
    await _pumpAccount(tester, auth);

    expect(_fieldText(tester, 0), 'Ada'); // first name
    expect(_fieldText(tester, 1), 'Lovelace'); // last name
    expect(_fieldText(tester, 4), 'ada@example.com'); // email
    expect(_fieldText(tester, 5), 'London'); // birth place
  });

  testWidgets('editing and saving updates the profile', (tester) async {
    final backend = FakeFamilyBackend();
    final auth = backend.authWith();
    await auth.loginWithPassword('tester', 'pw');
    await _pumpAccount(tester, auth);

    await tester.enterText(find.byType(TextFormField).at(0), 'NewFirst');
    final save = find.widgetWithText(FilledButton, 'Save');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(backend.firstName, 'NewFirst');
    expect(find.text('Profile updated.'), findsOneWidget);

    // Let the toast's auto-dismiss timer fire so it doesn't leak past the
    // end of the test.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('an invalid email blocks saving', (tester) async {
    final backend = FakeFamilyBackend();
    final auth = backend.authWith();
    await auth.loginWithPassword('tester', 'pw');
    await _pumpAccount(tester, auth);

    await tester.enterText(find.byType(TextFormField).at(4), 'not-an-email');
    final save = find.widgetWithText(FilledButton, 'Save');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(backend.email, isNot('not-an-email'));
  });

  testWidgets('logging out clears the session', (tester) async {
    final backend = FakeFamilyBackend();
    final auth = backend.authWith();
    await auth.loginWithPassword('tester', 'pw');
    await _pumpAccount(tester, auth);

    final logout = find.widgetWithText(OutlinedButton, 'Logout');
    await tester.ensureVisible(logout);
    await tester.tap(logout);
    await tester.pumpAndSettle();

    expect(auth.isAuthenticated, isFalse);
  });

  testWidgets('deleting the account requires confirmation', (tester) async {
    final backend = FakeFamilyBackend();
    final auth = backend.authWith();
    await auth.loginWithPassword('tester', 'pw');
    await _pumpAccount(tester, auth);

    final deleteAccount = find.widgetWithText(FilledButton, 'Delete account');
    await tester.ensureVisible(deleteAccount);
    await tester.tap(deleteAccount);
    await tester.pumpAndSettle();

    // Confirmation dialog is up; backing out leaves the account intact.
    expect(find.text('Delete account'), findsWidgets); // title + button
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(backend.accountDeleted, isFalse);
    expect(auth.isAuthenticated, isTrue);
  });

  testWidgets('confirming account deletion signs the user out', (tester) async {
    final backend = FakeFamilyBackend();
    final auth = backend.authWith();
    await auth.loginWithPassword('tester', 'pw');
    await _pumpAccount(tester, auth);

    final deleteAccount = find.widgetWithText(FilledButton, 'Delete account');
    await tester.ensureVisible(deleteAccount);
    await tester.tap(deleteAccount);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(backend.accountDeleted, isTrue);
    expect(auth.isAuthenticated, isFalse);
    expect(find.text('Your account has been deleted.'), findsOneWidget);

    // Let the toast's auto-dismiss timer fire so it doesn't leak past the
    // end of the test.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
