import 'package:flutter/material.dart';

import '../graphql/family_api.dart';
import '../graphql/graphql_client.dart';
import '../l10n/app_strings.dart';
import '../widgets/glass.dart';
import 'tree_controller.dart';

/// A native form for editing a person's name / designation / history — the
/// in-app replacement for the web "edit" page. Pops with `true` after a
/// successful save so the caller can react.
class EditPersonPage extends StatefulWidget {
  const EditPersonPage({
    super.key,
    required this.controller,
    required this.personId,
  });

  final TreeController controller;
  final int personId;

  @override
  State<EditPersonPage> createState() => _EditPersonPageState();
}

class _EditPersonPageState extends State<EditPersonPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _designation = TextEditingController();
  final _history = TextEditingController();

  late Future<PersonDetails> _details;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _details = _load();
  }

  Future<PersonDetails> _load() async {
    final details = await widget.controller.personDetails(widget.personId);
    _name.text = details.name;
    _designation.text = details.designation;
    _history.text = details.history;
    return details;
  }

  @override
  void dispose() {
    _name.dispose();
    _designation.dispose();
    _history.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    final t = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.controller.editPerson(
        widget.personId,
        name: _name.text.trim(),
        designation: _designation.text.trim(),
        history: _history.text.trim(),
      );
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(t.personUpdated)));
      Navigator.pop(context, true);
    } on GraphQLException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = t.errorConnection);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.editPersonTitle),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(t.save),
          ),
        ],
      ),
      body: FutureBuilder<PersonDetails>(
        future: _details,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(t.errorConnection, textAlign: TextAlign.center),
              ),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            // The same frosted-glass card every floating panel in the app
            // uses, so this form reads as part of one design rather than a
            // plain form dropped on the gradient backdrop. Field borders are
            // left to the app-wide [InputDecorationTheme].
            child: GlassPanel(
              borderRadius: BorderRadius.circular(28),
              opacity: 0.5,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _name,
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.words,
                        decoration: glassFieldDecoration(
                          context,
                          InputDecoration(labelText: t.nameLabel),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? t.fieldRequired
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _designation,
                        minLines: 1,
                        maxLines: 3,
                        decoration: glassFieldDecoration(
                          context,
                          InputDecoration(labelText: t.designationLabel),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _history,
                        minLines: 3,
                        maxLines: 8,
                        decoration: glassFieldDecoration(
                          context,
                          InputDecoration(
                            labelText: t.historyLabel,
                            alignLabelWithHint: true,
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save),
                        label: Text(t.save),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
