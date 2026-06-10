import 'package:flutter/material.dart';

import '../graphql/family_api.dart';
import '../graphql/graphql_client.dart';
import '../l10n/app_strings.dart';
import '../widgets/glass.dart';
import 'auth_service.dart';
import 'social_buttons.dart';
import 'social_sign_in.dart';

/// Which half of the auth page is showing.
enum _AuthMode { signIn, signUp }

/// Sign in / sign up against the Django backend, offering email + password and
/// any social providers the backend has enabled (Google / Apple / Facebook).
///
/// Pops with `true` once the user is signed in, so the caller can refresh any
/// permission-gated UI. (Email sign-up that needs activation shows a confirmation
/// instead and the page stays open.)
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.auth});

  final AuthService auth;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController(); // email or username (sign in)
  final _email = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  _AuthMode _mode = _AuthMode.signIn;
  bool _submitting = false;
  bool _obscure = true;
  SocialProvider? _busyProvider;
  String? _error;

  /// The email an activation link was just sent to, or null when not in that
  /// confirmation state.
  String? _activationSentTo;

  /// The backend's enabled-methods config; null until [loadAuthConfig] resolves.
  AuthConfig? _config;

  @override
  void initState() {
    super.initState();
    widget.auth.loadAuthConfig().then((cfg) {
      if (mounted) setState(() => _config = cfg);
    });
  }

  @override
  void dispose() {
    _identifier.dispose();
    _email.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _busy => _submitting || _busyProvider != null;

  void _switchMode(_AuthMode mode) {
    if (_busy) return;
    setState(() {
      _mode = mode;
      _error = null;
    });
  }

  /// Maps any thrown error to a user-facing message for the inline banner.
  String _messageFor(Object error, AppStrings t) => switch (error) {
    AuthFailedException e => e.message,
    GraphQLException e => e.message,
    _ => t.authGenericError,
  };

  Future<void> _submitEmail() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });
    final t = AppStrings.of(context);
    try {
      if (_mode == _AuthMode.signIn) {
        await widget.auth.loginWithPassword(
          _identifier.text.trim(),
          _password.text,
        );
        if (mounted) Navigator.pop(context, true);
      } else {
        final email = _email.text.trim();
        final result = await widget.auth.register(
          email,
          _password.text,
          firstName: _firstName.text.trim().isEmpty
              ? null
              : _firstName.text.trim(),
          lastName: _lastName.text.trim().isEmpty
              ? null
              : _lastName.text.trim(),
        );
        if (!mounted) return;
        if (result.outcome == RegisterOutcome.activationSent) {
          setState(() => _activationSentTo = email);
        } else {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = _messageFor(e, t));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _signInWith(SocialProvider provider) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busyProvider = provider;
      _error = null;
    });
    final t = AppStrings.of(context);
    try {
      await widget.auth.loginWithProvider(provider);
      if (mounted) Navigator.pop(context, true);
    } on SocialSignInCancelled {
      // User backed out of the provider sheet — stay silent.
    } catch (e) {
      if (mounted) setState(() => _error = _messageFor(e, t));
    } finally {
      if (mounted) setState(() => _busyProvider = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.loginTitle)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            // The same frosted-glass card every floating panel in the app uses,
            // so the auth form reads as part of one design rather than a plain
            // form dropped on the gradient backdrop.
            child: GlassPanel(
              borderRadius: BorderRadius.circular(28),
              opacity: 0.5,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _activationSentTo != null
                    ? _buildActivationSent(t)
                    : _buildForm(t),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActivationSent(AppStrings t) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.mark_email_read_outlined,
          size: 48,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          t.activationSentTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Text(
          t.activationSentBody(_activationSentTo!),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => setState(() {
            _activationSentTo = null;
            _mode = _AuthMode.signIn;
            _password.clear();
            _confirm.clear();
          }),
          child: Text(t.backToSignIn),
        ),
      ],
    );
  }

  Widget _buildForm(AppStrings t) {
    final config = _config ?? AuthConfig.fallback;
    final isSignUp = _mode == _AuthMode.signUp;
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (config.emailEnabled) ...[
            _ModeToggle(
              mode: _mode,
              onChanged: _switchMode,
              t: t,
            ),
            const SizedBox(height: 20),
            ..._emailFields(t, isSignUp),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (config.emailEnabled) ...[
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _submitEmail,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isSignUp ? t.createAccount : t.signIn),
            ),
          ],
          if (config.emailEnabled && config.anySocial) ...[
            const SizedBox(height: 20),
            _OrDivider(label: t.orDivider),
            const SizedBox(height: 20),
          ],
          SocialButtons(
            config: config,
            onPressed: _signInWith,
            busyProvider: _busyProvider,
            enabled: !_busy,
          ),
        ],
      ),
    );
  }

  List<Widget> _emailFields(AppStrings t, bool isSignUp) {
    return [
      if (isSignUp)
        TextFormField(
          controller: _email,
          autofillHints: const [AutofillHints.email],
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: t.emailLabel,
            prefixIcon: const Icon(Icons.mail_outline),
          ),
          validator: (v) {
            final value = (v ?? '').trim();
            if (value.isEmpty) return t.fieldRequired;
            if (!value.contains('@')) return t.invalidEmail;
            return null;
          },
        )
      else
        TextFormField(
          controller: _identifier,
          autofillHints: const [AutofillHints.username, AutofillHints.email],
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: t.emailOrUsernameLabel,
            prefixIcon: const Icon(Icons.person_outline),
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? t.fieldRequired : null,
        ),
      if (isSignUp) ...[
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _firstName,
                autofillHints: const [AutofillHints.givenName],
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: t.firstNameLabel),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _lastName,
                autofillHints: const [AutofillHints.familyName],
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: t.lastNameLabel),
              ),
            ),
          ],
        ),
      ],
      const SizedBox(height: 16),
      TextFormField(
        controller: _password,
        autofillHints: [
          isSignUp ? AutofillHints.newPassword : AutofillHints.password,
        ],
        obscureText: _obscure,
        textInputAction: isSignUp ? TextInputAction.next : TextInputAction.done,
        onFieldSubmitted: (_) => isSignUp ? null : _submitEmail(),
        decoration: InputDecoration(
          labelText: t.passwordLabel,
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
        validator: (v) => (v == null || v.isEmpty) ? t.fieldRequired : null,
      ),
      if (isSignUp) ...[
        const SizedBox(height: 16),
        TextFormField(
          controller: _confirm,
          obscureText: _obscure,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _submitEmail(),
          decoration: InputDecoration(
            labelText: t.confirmPasswordLabel,
            prefixIcon: const Icon(Icons.lock_outline),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return t.fieldRequired;
            if (v != _password.text) return t.passwordsDontMatch;
            return null;
          },
        ),
      ],
    ];
  }
}

/// The Sign in / Sign up segmented switch at the top of the email form.
class _ModeToggle extends StatelessWidget {
  const _ModeToggle({
    required this.mode,
    required this.onChanged,
    required this.t,
  });

  final _AuthMode mode;
  final ValueChanged<_AuthMode> onChanged;
  final AppStrings t;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_AuthMode>(
      segments: [
        ButtonSegment(value: _AuthMode.signIn, label: Text(t.signInTab)),
        ButtonSegment(value: _AuthMode.signUp, label: Text(t.signUpTab)),
      ],
      selected: {mode},
      showSelectedIcon: false,
      onSelectionChanged: (s) => onChanged(s.first),
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}

/// A horizontal rule with a centred "or" label separating the email form from
/// the social buttons.
class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4);
    return Row(
      children: [
        Expanded(child: Divider(color: color)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label, style: TextStyle(color: color)),
        ),
        Expanded(child: Divider(color: color)),
      ],
    );
  }
}
