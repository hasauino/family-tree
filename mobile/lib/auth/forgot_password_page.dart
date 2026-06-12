import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../widgets/glass.dart';
import '../widgets/top_toast.dart';
import 'auth_errors.dart';
import 'auth_service.dart';

/// Which step of the reset flow is showing.
enum _Step { enterEmail, enterReset }

/// Password reset by emailed code: ask for the account email, send a 6-digit
/// code, then take that code plus a new password. Pops with `true` once the
/// password is reset and the user is signed in.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, required this.auth});

  final AuthService auth;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailForm = GlobalKey<FormState>();
  final _resetForm = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  _Step _step = _Step.enterEmail;
  bool _submitting = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  /// Step 1: request a reset code for the typed email.
  Future<void> _sendCode() async {
    if (!(_emailForm.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });
    final t = AppStrings.of(context);
    try {
      await widget.auth.requestPasswordReset(_email.text.trim());
      if (mounted) setState(() => _step = _Step.enterReset);
    } catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e, t));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Step 2: verify the code and set the new password (signs the user in).
  Future<void> _resetPassword() async {
    if (!(_resetForm.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });
    final t = AppStrings.of(context);
    try {
      await widget.auth.resetPassword(
        _email.text.trim(),
        _code.text.trim(),
        _password.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e, t));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    final t = AppStrings.of(context);
    try {
      await widget.auth.requestPasswordReset(_email.text.trim());
      if (mounted) showTopToast(context, t.codeResent);
    } catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e, t));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.forgotPasswordTitle)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: GlassPanel(
              borderRadius: BorderRadius.circular(28),
              opacity: 0.5,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _step == _Step.enterEmail
                    ? _buildEmailStep(t)
                    : _buildResetStep(t),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailStep(AppStrings t) {
    return Form(
      key: _emailForm,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.lock_reset_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(t.resetEmailPrompt, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          TextFormField(
            controller: _email,
            autofillHints: const [AutofillHints.email],
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _sendCode(),
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
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submitting ? null : _sendCode,
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(t.sendResetCode),
          ),
        ],
      ),
    );
  }

  Widget _buildResetStep(AppStrings t) {
    return Form(
      key: _resetForm,
      child: Column(
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
            t.resetCodeSentBody(_email.text.trim()),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _code,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            style: const TextStyle(fontSize: 24, letterSpacing: 8),
            decoration: const InputDecoration(counterText: '', hintText: '••••••'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? t.fieldRequired : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _password,
            autofillHints: const [AutofillHints.newPassword],
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: t.newPasswordLabel,
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) => (v == null || v.isEmpty) ? t.fieldRequired : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirm,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _resetPassword(),
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
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submitting ? null : _resetPassword,
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(t.resetPasswordButton),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _submitting ? null : _resend,
            child: Text(t.codeResend),
          ),
        ],
      ),
    );
  }
}
