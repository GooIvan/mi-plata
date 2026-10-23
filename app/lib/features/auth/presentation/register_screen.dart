import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../l10n/l10n.dart';
import '../domain/auth_validators.dart';
import 'auth_error_message.dart';
import 'auth_providers.dart';
import '../../../core/widgets/error_banner.dart';
import 'widgets/auth_layout.dart';
import 'widgets/password_field.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final outcome = await ref
        .read(authControllerProvider.notifier)
        .signUp(email: _email.text.trim(), password: _password.text);
    if (!mounted) return;

    // Si no hace falta confirmar el correo, la sesión ya está abierta y el
    // router lleva al panel por su cuenta.
    if (outcome == SignUpOutcome.confirmationRequired) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.authConfirmEmailSent)),
      );
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final isLoading = state.isLoading;
    final error = state.hasError && !isLoading
        ? authErrorMessage(context.l10n, state.error!)
        : null;

    return AuthLayout(
      subtitle: context.l10n.authRegisterSubtitle,
      children: [
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _email,
                  enabled: !isLoading,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: (value) => AuthValidators.email(context.l10n, value),
                  decoration: InputDecoration(
                    labelText: context.l10n.authEmailLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                PasswordField(
                  controller: _password,
                  label: context.l10n.authPasswordLabel,
                  enabled: !isLoading,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.next,
                  validator: (value) =>
                      AuthValidators.newPassword(context.l10n, value),
                ),
                const SizedBox(height: 16),
                PasswordField(
                  controller: _confirmation,
                  label: context.l10n.authPasswordRepeatLabel,
                  enabled: !isLoading,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.done,
                  validator: (value) => AuthValidators.passwordConfirmation(
                    context.l10n,
                    value,
                    _password.text,
                  ),
                  onFieldSubmitted: (_) => _submit(),
                ),
                if (error != null) ...[
                  const SizedBox(height: 16),
                  ErrorBanner(error),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: isLoading ? null : _submit,
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(context.l10n.authRegisterButton),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: isLoading ? null : () => context.go(AppRoutes.login),
                  child: Text(context.l10n.authGoToLogin),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
