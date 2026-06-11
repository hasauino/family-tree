import 'package:flutter/material.dart';

import '../account/account_page.dart';
import '../auth/auth_service.dart';
import '../auth/login_page.dart';
import '../config.dart';
import '../l10n/app_strings.dart';

/// The login button (signed out) or an avatar that opens [AccountPage]
/// (signed in) — shared by the home screen and tree screen action bars.
class AccountMenuButton extends StatelessWidget {
  const AccountMenuButton({super.key, required this.auth});

  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    if (!auth.isAuthenticated) {
      return IconButton(
        tooltip: t.login,
        icon: const Icon(Icons.login),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => LoginPage(auth: auth)),
        ),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final url = auth.profile?.profileImageUrl;
    return IconButton(
      tooltip: auth.username ?? t.account,
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AccountPage(auth: auth)),
      ),
      icon: CircleAvatar(
        radius: 14,
        backgroundColor: scheme.primary.withValues(alpha: 0.12),
        backgroundImage: url != null
            ? NetworkImage('${AppConfig.baseUrl}$url')
            : null,
        child: url == null
            ? Icon(
                auth.isStaff ? Icons.shield_outlined : Icons.account_circle,
                size: 18,
                color: scheme.primary,
              )
            : null,
      ),
    );
  }
}
