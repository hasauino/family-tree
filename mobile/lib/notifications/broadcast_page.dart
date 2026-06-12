import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../l10n/app_strings.dart';
import '../widgets/glass.dart';
import '../widgets/top_toast.dart';

/// Admin-only composer for a custom notification broadcast to all users — e.g.
/// an Eid greeting or an important announcement. Sends one notification (and a
/// push, where configured) to every other user.
class BroadcastPage extends StatefulWidget {
  const BroadcastPage({super.key, required this.auth});

  final AuthService auth;

  @override
  State<BroadcastPage> createState() => _BroadcastPageState();
}

class _BroadcastPageState extends State<BroadcastPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final t = AppStrings.of(context);
    if (!_formKey.currentState!.validate()) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.broadcastConfirmTitle),
        content: Text(t.broadcastConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t.broadcastSend)),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _sending = true);
    try {
      final result = await widget.auth.api
          .broadcastNotification(_title.text.trim(), _body.text.trim());
      if (!mounted) return;
      if (result.ok) {
        showTopToast(context, t.broadcastDone(result.sent));
        Navigator.of(context).pop();
      } else {
        showTopToast(context, result.message ?? t.errorConnection);
      }
    } catch (_) {
      if (mounted) showTopToast(context, t.errorConnection);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.broadcastTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: GlassPanel(
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(t.broadcastIntro,
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _title,
                    decoration: InputDecoration(labelText: t.broadcastTitleLabel),
                    maxLength: 120,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? t.broadcastTitleRequired : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _body,
                    decoration: InputDecoration(labelText: t.broadcastBodyLabel),
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 500,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? t.broadcastBodyRequired : null,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.campaign),
                    label: Text(t.broadcastSend),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
