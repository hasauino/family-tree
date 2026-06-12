import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:family_tree_mobile/auth/auth_service.dart';
import 'package:family_tree_mobile/auth/login_page.dart';
import 'package:family_tree_mobile/auth/social_sign_in.dart';
import 'package:family_tree_mobile/graphql/graphql_client.dart';
import 'package:family_tree_mobile/l10n/app_strings.dart';

import '../integration_test/support/fake_backend.dart';

/// A stand-in for the native provider SDKs: records the provider asked for and
/// returns a canned token so the app can call the backend `socialLogin`.
class _FakeSocial implements SocialSignIn {
  SocialProvider? lastProvider;

  @override
  Future<SocialCredential> authenticate(SocialProvider provider) async {
    lastProvider = provider;
    return const SocialCredential(token: 'fake-token', firstName: 'Soc');
  }
}

/// Pumps [LoginPage] inside a minimal English MaterialApp.
Future<void> _pumpLogin(WidgetTester tester, AuthService auth) async {
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
      home: LoginPage(auth: auth),
    ),
  );
  await tester.pumpAndSettle(); // let authConfig resolve and the form build
}

void main() {
  // AuthService persists session cookies after sign-in; back it with an
  // in-memory store so the widget tests don't hit the platform channel.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('email sign-in signs the user in', (tester) async {
    final backend = FakeFamilyBackend();
    final auth = backend.authWith();
    await _pumpLogin(tester, auth);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'tester'); // email or username
    await tester.enterText(fields.at(1), 'pw'); // password
    await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
    await tester.pumpAndSettle();

    expect(auth.isAuthenticated, isTrue);
    expect(auth.username, 'tester');
  });

  testWidgets('wrong password shows an inline error', (tester) async {
    final backend = FakeFamilyBackend();
    final auth = backend.authWith();
    await _pumpLogin(tester, auth);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'tester');
    await tester.enterText(fields.at(1), 'nope');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
    await tester.pumpAndSettle();

    expect(auth.isAuthenticated, isFalse);
    expect(find.text('Invalid credentials'), findsOneWidget);
  });

  testWidgets('only backend-enabled social providers are shown', (tester) async {
    final backend = FakeFamilyBackend()
      ..googleEnabled = true
      ..facebookEnabled = true
      ..appleEnabled = false;
    await _pumpLogin(tester, backend.authWith(social: _FakeSocial()));

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Facebook'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsNothing);
  });

  testWidgets('tapping a social button signs in through that provider',
      (tester) async {
    final backend = FakeFamilyBackend()..googleEnabled = true;
    final social = _FakeSocial();
    final auth = backend.authWith(social: social);
    await _pumpLogin(tester, auth);

    await tester.tap(find.widgetWithText(FilledButton, 'Continue with Google'));
    await tester.pumpAndSettle();

    expect(social.lastProvider, SocialProvider.google);
    expect(auth.isAuthenticated, isTrue);
  });

  testWidgets('sign-up with mismatched passwords is blocked', (tester) async {
    final backend = FakeFamilyBackend();
    final auth = backend.authWith();
    await _pumpLogin(tester, auth);

    await tester.tap(find.text('Sign up')); // segmented toggle
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'new@example.com'); // email
    await tester.enterText(fields.at(3), 's3curePass!42'); // password
    await tester.enterText(fields.at(4), 'different'); // confirm
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(auth.isAuthenticated, isFalse);
  });

  testWidgets('sign-up that needs verification shows the code-entry screen',
      (tester) async {
    final backend = FakeFamilyBackend()..requireActivation = true;
    final auth = backend.authWith();
    await _pumpLogin(tester, auth);

    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'new@example.com');
    await tester.enterText(fields.at(3), 's3curePass!42');
    await tester.enterText(fields.at(4), 's3curePass!42');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Enter the code'), findsOneWidget);
    expect(auth.isAuthenticated, isFalse);

    // Typing the right code verifies and pops the page (signed in).
    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.widgetWithText(FilledButton, 'Verify'));
    await tester.pumpAndSettle();
    expect(auth.isAuthenticated, isTrue);
  });

  test('verifyEmailCode with the right code signs the user in', () async {
    final auth = FakeFamilyBackend().authWith();
    expect(auth.isAuthenticated, isFalse);
    await auth.verifyEmailCode('new@example.com', '123456');
    expect(auth.isAuthenticated, isTrue);
  });

  test('verifyEmailCode with a wrong code throws and stays signed out',
      () async {
    final auth = FakeFamilyBackend().authWith();
    await expectLater(
      auth.verifyEmailCode('new@example.com', '000000'),
      throwsA(
        isA<AuthFailedException>().having(
          (e) => e.message,
          'message',
          'code_invalid',
        ),
      ),
    );
    expect(auth.isAuthenticated, isFalse);
  });

  testWidgets('forgot-password resets and signs in via the emailed code',
      (tester) async {
    final auth = FakeFamilyBackend().authWith();
    await _pumpLogin(tester, auth);

    // Open the reset flow from the sign-in form.
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.text('Reset password'), findsWidgets);

    // Step 1: enter the account email and request a code.
    await tester.enterText(find.byType(TextFormField), 'me@example.com');
    await tester.tap(find.widgetWithText(FilledButton, 'Send code'));
    await tester.pumpAndSettle();

    // Step 2: enter the code + a new password and submit.
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '123456'); // code
    await tester.enterText(fields.at(1), 'BrandNew!pass77'); // new password
    await tester.enterText(fields.at(2), 'BrandNew!pass77'); // confirm
    await tester.tap(find.widgetWithText(FilledButton, 'Reset password'));
    await tester.pumpAndSettle();

    expect(auth.isAuthenticated, isTrue);
  });

  test('resetPassword with a wrong code throws and stays signed out', () async {
    final auth = FakeFamilyBackend().authWith();
    await expectLater(
      auth.resetPassword('me@example.com', '000000', 'BrandNew!pass77'),
      throwsA(
        isA<AuthFailedException>().having(
          (e) => e.message,
          'message',
          'code_invalid',
        ),
      ),
    );
    expect(auth.isAuthenticated, isFalse);
  });
}
