import 'package:flutter/material.dart';

import '../graphql/family_api.dart';
import '../l10n/app_strings.dart';
import 'social_sign_in.dart';

/// The stack of "Continue with …" provider buttons shown under the email form.
///
/// Only renders providers the backend reports enabled in [config] *and* that are
/// supported on the current platform (Apple is hidden off Apple devices). When
/// none qualify it renders nothing, so the email form stands alone.
class SocialButtons extends StatelessWidget {
  const SocialButtons({
    super.key,
    required this.config,
    required this.onPressed,
    required this.busyProvider,
    required this.enabled,
  });

  final AuthConfig config;

  /// Invoked with the chosen provider; the parent runs the sign-in flow.
  final ValueChanged<SocialProvider> onPressed;

  /// The provider whose flow is currently running (shows a spinner), or null.
  final SocialProvider? busyProvider;

  /// False while any auth request is in flight, to disable all buttons.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final buttons = <_SocialButton>[
      if (config.googleEnabled && socialProviderSupported(SocialProvider.google))
        _SocialButton(
          provider: SocialProvider.google,
          label: t.continueWithGoogle,
          brand: const Color(0xFF4285F4),
          icon: const _GoogleMark(),
        ),
      if (config.appleEnabled && socialProviderSupported(SocialProvider.apple))
        _SocialButton(
          provider: SocialProvider.apple,
          label: t.continueWithApple,
          brand: Theme.of(context).colorScheme.onSurface,
          icon: const Icon(Icons.apple, size: 22),
        ),
      if (config.facebookEnabled &&
          socialProviderSupported(SocialProvider.facebook))
        _SocialButton(
          provider: SocialProvider.facebook,
          label: t.continueWithFacebook,
          brand: const Color(0xFF1877F2),
          icon: const Icon(Icons.facebook, size: 22),
        ),
    ];
    if (buttons.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, button) in buttons.indexed) ...[
          if (i > 0) const SizedBox(height: 12),
          _wire(button),
        ],
      ],
    );
  }

  /// Binds a [_SocialButton]'s press/busy/enabled state to this widget's props.
  Widget _wire(_SocialButton button) => _SocialButton(
    provider: button.provider,
    label: button.label,
    brand: button.brand,
    icon: button.icon,
    busy: busyProvider == button.provider,
    onPressed: enabled ? () => onPressed(button.provider) : null,
  );
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.provider,
    required this.label,
    required this.brand,
    required this.icon,
    this.busy = false,
    this.onPressed,
  });

  final SocialProvider provider;
  final String label;
  final Color brand;
  final Widget icon;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    // Glass-pill look matching the app's FilledButton theme, tinted with the
    // provider's brand colour so each reads as that provider without breaking
    // the frosted design language.
    return FilledButton.tonalIcon(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: brand.withValues(alpha: 0.12),
        foregroundColor: brand,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      icon: busy
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : icon,
      label: Text(label),
    );
  }
}

/// A minimal "G" mark for the Google button (the brand glyph without shipping a
/// logo asset), tinted in Google blue to match the button.
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 22,
      height: 22,
      child: Center(
        child: Text(
          'G',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}
