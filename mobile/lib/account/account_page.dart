import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../config.dart';
import '../graphql/graphql_client.dart';
import '../l10n/app_strings.dart';
import '../widgets/glass.dart';
import '../widgets/top_toast.dart';
import '../auth/auth_service.dart';

/// Lets the signed-in user edit their profile, change their photo, log out,
/// or delete their account — the frosted-glass replacement for the old
/// "username + logout" popup menu.
class AccountPage extends StatefulWidget {
  const AccountPage({super.key, required this.auth});

  final AuthService auth;

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _fatherName;
  late final TextEditingController _grandfatherName;
  late final TextEditingController _email;
  late final TextEditingController _birthPlace;

  DateTime? _birthDate;
  bool _saving = false;
  bool _imageBusy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.auth.profile;
    _firstName = TextEditingController(text: p?.firstName ?? '');
    _lastName = TextEditingController(text: p?.lastName ?? '');
    _fatherName = TextEditingController(text: p?.fatherName ?? '');
    _grandfatherName = TextEditingController(text: p?.grandfatherName ?? '');
    _email = TextEditingController(text: p?.email ?? '');
    _birthPlace = TextEditingController(text: p?.birthPlace ?? '');
    final birthDate = p?.birthDate;
    if (birthDate != null && birthDate.isNotEmpty) {
      _birthDate = DateTime.tryParse(birthDate);
    }
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _fatherName.dispose();
    _grandfatherName.dispose();
    _email.dispose();
    _birthPlace.dispose();
    super.dispose();
  }

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    final t = AppStrings.of(context);
    final overlay = Overlay.of(context, rootOverlay: true);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.auth.updateProfile(
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        fatherName: _fatherName.text.trim(),
        grandfatherName: _grandfatherName.text.trim(),
        email: _email.text.trim(),
        birthPlace: _birthPlace.text.trim(),
        birthDate: _birthDate == null ? null : _isoDate(_birthDate!),
      );
      if (!mounted) return;
      showTopToastOn(overlay, t.profileUpdated);
    } on GraphQLException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = t.errorConnection);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 30),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _pickImage(ImageSource source) async {
    final t = AppStrings.of(context);
    final overlay = Overlay.of(context, rootOverlay: true);
    final file = await ImagePicker().pickImage(
      source: source,
      imageQuality: 90,
    );
    if (file == null) return;
    setState(() => _imageBusy = true);
    try {
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) throw Exception('Could not decode image');
      final square = img.copyResizeCropSquare(decoded, size: 128);
      final jpg = img.encodeJpg(square, quality: 85);
      await widget.auth.uploadProfileImage(Uint8List.fromList(jpg));
      if (mounted) showTopToastOn(overlay, t.profileUpdated);
    } catch (_) {
      if (mounted) showTopToastOn(overlay, t.imageUpdateError);
    } finally {
      if (mounted) setState(() => _imageBusy = false);
    }
  }

  Future<void> _removeImage() async {
    final t = AppStrings.of(context);
    final overlay = Overlay.of(context, rootOverlay: true);
    setState(() => _imageBusy = true);
    try {
      await widget.auth.removeProfileImage();
      if (mounted) showTopToastOn(overlay, t.profileUpdated);
    } catch (_) {
      if (mounted) showTopToastOn(overlay, t.imageUpdateError);
    } finally {
      if (mounted) setState(() => _imageBusy = false);
    }
  }

  Future<void> _showPhotoOptions() async {
    final t = AppStrings.of(context);
    final hasImage = widget.auth.profile?.profileImageUrl != null;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: GlassPanel(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          opacity: 0.6,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(t.chooseFromGallery),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text(t.takePhoto),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              if (hasImage)
                ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: Theme.of(ctx).colorScheme.error,
                  ),
                  title: Text(
                    t.removePhoto,
                    style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _removeImage();
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await widget.auth.logout();
    if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
  }

  Future<void> _confirmDelete() async {
    final t = AppStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => GlassDialog(
        title: t.deleteAccountTitle,
        content: Text(t.deleteAccountConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.cancel),
          ),
          FilledButton(
            style: glassButtonStyle(Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final t2 = AppStrings.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.auth.deleteAccount();
      if (mounted) {
        showTopToast(context, t2.accountDeleted);
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } on GraphQLException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = t2.errorConnection);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _avatar() {
    final scheme = Theme.of(context).colorScheme;
    final url = widget.auth.profile?.profileImageUrl;
    return Stack(
      children: [
        CircleAvatar(
          radius: 48,
          backgroundColor: scheme.primary.withValues(alpha: 0.12),
          backgroundImage: url != null
              ? NetworkImage('${AppConfig.baseUrl}$url')
              : null,
          child: url == null
              ? Icon(Icons.account_circle, size: 56, color: scheme.primary)
              : null,
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: GestureDetector(
            onTap: _imageBusy ? null : _showPhotoOptions,
            child: CircleAvatar(
              radius: 16,
              backgroundColor: scheme.primary,
              child: _imageBusy
                  ? const SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.edit, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.account)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
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
                  Center(child: _avatar()),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _firstName,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: glassFieldDecoration(
                            context,
                            InputDecoration(labelText: t.firstNameLabel),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _lastName,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: glassFieldDecoration(
                            context,
                            InputDecoration(labelText: t.lastNameLabel),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _fatherName,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: glassFieldDecoration(
                      context,
                      InputDecoration(labelText: t.fatherNameLabel),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _grandfatherName,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: glassFieldDecoration(
                      context,
                      InputDecoration(labelText: t.grandfatherNameLabel),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: glassFieldDecoration(
                      context,
                      InputDecoration(labelText: t.emailLabel),
                    ),
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) return t.fieldRequired;
                      if (!value.contains('@')) return t.invalidEmail;
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _birthPlace,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    decoration: glassFieldDecoration(
                      context,
                      InputDecoration(labelText: t.birthPlaceLabel),
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _pickBirthDate,
                    child: InputDecorator(
                      decoration: glassFieldDecoration(
                        context,
                        InputDecoration(
                          labelText: t.birthDateLabel,
                          suffixIcon: const Icon(Icons.calendar_today_outlined),
                        ),
                      ),
                      child: Text(
                        _birthDate == null ? '' : _isoDate(_birthDate!),
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
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _logout,
                    icon: const Icon(Icons.logout),
                    label: Text(t.logout),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    style: glassButtonStyle(Theme.of(context).colorScheme.error),
                    onPressed: _saving ? null : _confirmDelete,
                    icon: const Icon(Icons.delete_forever_outlined),
                    label: Text(t.deleteAccount),
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
