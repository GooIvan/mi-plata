import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/error_banner.dart';
import '../../../../l10n/l10n.dart';
import '../../../auth/domain/auth_validators.dart';
import '../../../auth/presentation/auth_error_message.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../../auth/presentation/widgets/password_field.dart';
import '../profile_providers.dart';

/// Cambiar la contraseña y eliminar la cuenta con todos sus datos.
class AccountSecurity extends ConsumerWidget {
  const AccountSecurity({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(l10n.profileSecurity, style: theme.textTheme.titleMedium),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: Text(l10n.profileChangePassword),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (_) => const _ChangePasswordDialog(),
                ),
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_forever_outlined,
                  color: theme.colorScheme.error,
                ),
                title: Text(
                  l10n.profileDeleteAccount,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (_) => const _DeleteAccountDialog(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();

  @override
  ConsumerState<_ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).updatePassword(_password.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.profilePasswordChanged)),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = authErrorMessage(l10n, error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.profileChangePassword),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PasswordField(
                controller: _password,
                label: l10n.profileNewPasswordLabel,
                enabled: !_saving,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                validator: (value) => AuthValidators.newPassword(l10n, value),
              ),
              const SizedBox(height: 16),
              PasswordField(
                controller: _confirmation,
                label: l10n.authPasswordRepeatLabel,
                enabled: !_saving,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                validator: (value) => AuthValidators.passwordConfirmation(
                  l10n,
                  value,
                  _password.text,
                ),
                onFieldSubmitted: (_) => _save(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                ErrorBanner(_error!),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}

class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog();

  @override
  ConsumerState<_DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  bool _deleting = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  /// Pide la contraseña otra vez (borrar no se puede deshacer), borra la cuenta
  /// y cierra la sesión: el router lleva al inicio de sesión.
  Future<void> _delete() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = context.l10n;
    final auth = ref.read(authRepositoryProvider);
    final email = auth.currentUser?.email;
    setState(() {
      _deleting = true;
      _error = null;
    });

    try {
      if (email != null) {
        try {
          await auth.signIn(email: email, password: _password.text);
        } catch (error) {
          if (!mounted) return;
          setState(() {
            _deleting = false;
            _error = authErrorMessage(l10n, error);
          });
          return;
        }
      }
      await ref.read(profileRepositoryProvider).deleteAccount();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = l10n.profileDeleteError;
      });
      return;
    }

    // La cuenta ya no existe: la sesión que quedó no sirve. Si cerrarla falla
    // (el servidor ya no conoce al usuario) no importa.
    try {
      await auth.signOut();
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(l10n.profileDeleteTitle),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.profileDeleteBody),
              const SizedBox(height: 16),
              PasswordField(
                controller: _password,
                label: l10n.profileDeletePasswordLabel,
                enabled: !_deleting,
                textInputAction: TextInputAction.done,
                validator: (value) => AuthValidators.requiredPassword(l10n, value),
                onFieldSubmitted: (_) => _delete(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                ErrorBanner(_error!),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _deleting ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          onPressed: _deleting ? null : _delete,
          child: Text(l10n.profileDeleteConfirm),
        ),
      ],
    );
  }
}
