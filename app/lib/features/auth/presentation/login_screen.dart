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

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(authControllerProvider.notifier)
        .signIn(email: _email.text.trim(), password: _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final isLoading = state.isLoading;
    final error = state.hasError && !isLoading
        ? authErrorMessage(context.l10n, state.error!)
        : null;

    return AuthLayout(
      subtitle: context.l10n.authLoginSubtitle,
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
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  validator: (value) =>
                      AuthValidators.requiredPassword(context.l10n, value),
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
                      : Text(context.l10n.authLoginButton),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () => context.go(AppRoutes.register),
                  child: Text(context.l10n.authGoToRegister),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
