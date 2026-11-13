import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/formats.dart';
import '../../../core/widgets/error_banner.dart';
import '../../../core/widgets/state_message.dart';
import '../../../l10n/l10n.dart';
import '../../accounts/domain/amount_parser.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../currency/domain/currency.dart';
import '../../currency/presentation/currency_providers.dart';
import '../domain/profile_data.dart';
import '../domain/profile_validators.dart';
import 'profile_error_message.dart';
import 'profile_providers.dart';
import 'widgets/account_security.dart';
import 'widgets/birth_date_field.dart';

/// Los datos personales del usuario: se ven y se cambian aquí. También el
/// cambio de contraseña y el borrado de la cuenta.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final profile = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => StateMessage(
          icon: Icons.cloud_off_outlined,
          text: l10n.profileLoadError,
          actionLabel: l10n.commonRetry,
          onAction: () => ref.invalidate(profileProvider),
        ),
        data: (data) => _ProfileForm(profile: data),
      ),
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({required this.profile});

  /// Null si el usuario todavía no tiene perfil.
  final ProfileData? profile;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final _firstName = TextEditingController(text: widget.profile?.firstName);
  late final _lastName = TextEditingController(text: widget.profile?.lastName);
  late final _profession = TextEditingController(
    text: widget.profile?.profession,
  );
  final _income = TextEditingController();
  late DateTime? _birthDate = widget.profile?.birthDate;
  String? _birthDateError;
  bool _incomeReady = false;
  bool _saving = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // El monto se escribe según el idioma: el texto inicial espera al contexto.
    if (!_incomeReady) {
      _incomeReady = true;
      final income = widget.profile?.monthlyIncome;
      if (income != null) {
        _income.text = AmountParser.toInput(double.parse(income), context.formats);
      }
    }
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _profession.dispose();
    _income.dispose();
    super.dispose();
  }

  /// La moneda del ingreso: la que ya tenía, o la moneda base del usuario.
  String get _currency =>
      widget.profile?.monthlyIncomeCurrency ??
      ref.read(currencyConverterProvider).value?.base ??
      defaultCurrency;

  Future<void> _save() async {
    final l10n = context.l10n;
    final valid = _formKey.currentState!.validate();
    final birthDateError = ProfileValidators.birthDate(l10n, _birthDate);
    setState(() => _birthDateError = birthDateError);
    if (!valid || birthDateError != null) return;

    final income = _income.text.trim().isEmpty
        ? null
        : AmountParser.parse(_income.text, context.formats);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(profileProvider.notifier)
          .save(
            ProfileData(
              firstName: _firstName.text.trim(),
              lastName: _lastName.text.trim(),
              birthDate: _birthDate,
              profession: _profession.text.trim().isEmpty
                  ? null
                  : _profession.text.trim(),
              monthlyIncome: income,
              monthlyIncomeCurrency: income == null ? null : _currency,
            ),
          );
      messenger.showSnackBar(SnackBar(content: Text(l10n.profileSaved)));
      if (mounted) setState(() => _saving = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = profileSaveErrorMessage(l10n, error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final email = ref.watch(authRepositoryProvider).currentUser?.email;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        if (widget.profile == null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              l10n.profileIncompleteHint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InputDecorator(
                decoration: InputDecoration(
                  labelText: l10n.authEmailLabel,
                  helperText: l10n.profileEmailLocked,
                  border: const OutlineInputBorder(),
                  enabled: false,
                ),
                child: Text(email ?? ''),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _firstName,
                enabled: !_saving,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                validator: (value) => ProfileValidators.firstName(l10n, value),
                decoration: InputDecoration(
                  labelText: l10n.profileFirstNameLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lastName,
                enabled: !_saving,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                validator: (value) => ProfileValidators.lastName(l10n, value),
                decoration: InputDecoration(
                  labelText: l10n.profileLastNameLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              BirthDateField(
                value: _birthDate,
                enabled: !_saving,
                errorText: _birthDateError,
                onChanged: (date) => setState(() {
                  _birthDate = date;
                  _birthDateError = null;
                }),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _profession,
                enabled: !_saving,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                validator: (value) => ProfileValidators.profession(l10n, value),
                decoration: InputDecoration(
                  labelText: l10n.profileProfessionLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _income,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
                validator: (value) => ProfileValidators.monthlyIncome(l10n, value),
                onFieldSubmitted: (_) => _save(),
                decoration: InputDecoration(
                  labelText: l10n.profileIncomeLabel,
                  helperText: l10n.profileIncomeHelper,
                  helperMaxLines: 3,
                  prefixText: '${currencySymbol(_currency)} ',
                  border: const OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                ErrorBanner(_error!),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.commonSave),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        const AccountSecurity(),
      ],
    );
  }
}
