import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/formats.dart';
import '../../../core/router/app_routes.dart';
import '../../../l10n/l10n.dart';
import '../../accounts/domain/amount_parser.dart';
import '../../currency/domain/currency.dart';
import '../../profile/domain/profile_data.dart';
import '../../profile/domain/profile_validators.dart';
import '../../profile/presentation/widgets/birth_date_field.dart';
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
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _profession = TextEditingController();
  final _income = TextEditingController();
  DateTime? _birthDate;
  String? _birthDateError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _profession.dispose();
    _income.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState!.validate();
    final birthDateError = ProfileValidators.birthDate(context.l10n, _birthDate);
    setState(() => _birthDateError = birthDateError);
    if (!valid || birthDateError != null) return;

    final formats = context.formats;
    final income = _income.text.trim().isEmpty
        ? null
        : AmountParser.parse(_income.text, formats);

    final outcome = await ref
        .read(authControllerProvider.notifier)
        .signUp(
          email: _email.text.trim(),
          password: _password.text,
          // Las categorías con que empieza se crean en el idioma que se ve.
          language: Localizations.localeOf(context).languageCode,
          profile: ProfileData(
            firstName: _firstName.text.trim(),
            lastName: _lastName.text.trim(),
            birthDate: _birthDate,
            profession: _profession.text.trim().isEmpty
                ? null
                : _profession.text.trim(),
            monthlyIncome: income,
            // Al registrarse todavía no hay moneda base elegida: la de siempre.
            monthlyIncomeCurrency: income == null ? null : defaultCurrency,
          ),
        );
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
                  textInputAction: TextInputAction.next,
                  validator: (value) => AuthValidators.passwordConfirmation(
                    context.l10n,
                    value,
                    _password.text,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  context.l10n.profileSection,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.profileSectionHelp,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _firstName,
                  enabled: !isLoading,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.givenName],
                  validator: (value) =>
                      ProfileValidators.firstName(context.l10n, value),
                  decoration: InputDecoration(
                    labelText: context.l10n.profileFirstNameLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _lastName,
                  enabled: !isLoading,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.familyName],
                  validator: (value) =>
                      ProfileValidators.lastName(context.l10n, value),
                  decoration: InputDecoration(
                    labelText: context.l10n.profileLastNameLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                BirthDateField(
                  value: _birthDate,
                  enabled: !isLoading,
                  errorText: _birthDateError,
                  onChanged: (date) => setState(() {
                    _birthDate = date;
                    _birthDateError = null;
                  }),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _profession,
                  enabled: !isLoading,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  validator: (value) =>
                      ProfileValidators.profession(context.l10n, value),
                  decoration: InputDecoration(
                    labelText: context.l10n.profileProfessionLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _income,
                  enabled: !isLoading,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.done,
                  validator: (value) =>
                      ProfileValidators.monthlyIncome(context.l10n, value),
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: context.l10n.profileIncomeLabel,
                    helperText: context.l10n.profileIncomeHelper,
                    helperMaxLines: 3,
                    prefixText: '${currencySymbol(defaultCurrency)} ',
                    border: const OutlineInputBorder(),
                  ),
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
