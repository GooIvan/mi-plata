import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/formats.dart';
import '../../../../core/widgets/error_banner.dart';
import '../../../../l10n/l10n.dart';
import '../../../accounts/domain/account.dart';
import '../../../accounts/domain/amount_parser.dart';
import '../../../accounts/presentation/accounts_providers.dart';
import '../../../accounts/presentation/widgets/account_dropdown.dart';
import '../../../budgets/presentation/budget_expense_alert.dart';
import '../../../currency/domain/currency.dart';
import '../../../transactions/domain/negative_balance_check.dart';
import '../../../transactions/domain/transaction_draft.dart';
import '../../../transactions/domain/transaction_type.dart';
import '../../../transactions/domain/transaction_validators.dart';
import '../../../transactions/presentation/negative_balance_dialog.dart';
import '../../domain/recurring_payment.dart';
import '../recurring_error_message.dart';
import '../recurring_providers.dart';
import '../recurring_ui.dart';

/// Abre la hoja para confirmar que se pagó [payment] (o para omitir ese pago).
Future<void> showConfirmPaymentSheet(
  BuildContext context,
  RecurringPayment payment,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => ConfirmPaymentSheet(payment: payment),
  );
}

/// Confirmar crea el gasto de verdad (en la cuenta, el monto y la fecha que se
/// diga: el precio pudo cambiar o el pago salir de otra cuenta) y la regla pasa
/// al siguiente pago. Hasta entonces no se había descontado nada.
class ConfirmPaymentSheet extends ConsumerStatefulWidget {
  const ConfirmPaymentSheet({super.key, required this.payment});

  final RecurringPayment payment;

  @override
  ConsumerState<ConfirmPaymentSheet> createState() =>
      _ConfirmPaymentSheetState();
}

class _ConfirmPaymentSheetState extends ConsumerState<ConfirmPaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _description = TextEditingController();
  String? _accountId;
  DateTime _date = DateTime.now();
  bool _saving = false;
  bool _filled = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // El monto se escribe según el idioma, así que el texto inicial espera a
    // tener el contexto.
    if (!_filled) {
      _filled = true;
      // En un plan de cuotas, la última puede ser menor: lo que falte.
      _amount.text = AmountParser.toInput(
        widget.payment.nextAmount,
        context.formats,
      );
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: context.l10n.recurringConfirmDateHelp,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _confirm() async {
    if (!_formKey.currentState!.validate()) return;

    final formats = context.formats;
    final l10n = context.l10n;
    final description = _description.text.trim();
    final draft = TransactionDraft(
      type: TransactionType.expense,
      accountId: _accountId!,
      categoryId: widget.payment.categoryId,
      amount: AmountParser.parse(_amount.text, formats)!,
      date: _date,
      description: description.isEmpty ? null : description,
    );

    // Es un gasto como cualquiera: si deja la cuenta en negativo, se avisa.
    final warnings = NegativeBalanceCheck.after(
      accounts: ref.read(accountsProvider).value ?? const <Account>[],
      draft: draft,
    );
    if (warnings.isNotEmpty &&
        !await confirmNegativeBalance(
          context,
          warnings,
          title: l10n.negativeBalanceRecordTitle,
          confirmLabel: l10n.negativeBalanceRecordAnyway,
        )) {
      return;
    }
    if (!mounted) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Antes de guardar: después, el gasto ya estaría sumado en el mes.
      final budgetAlert = await budgetAlertBeforeSaving(
        ref,
        l10n,
        draft: draft,
      );
      await ref
          .read(recurringPaymentsProvider.notifier)
          .confirm(
            id: widget.payment.id,
            accountId: draft.accountId,
            amount: draft.amount,
            date: _date,
            description: draft.description,
          );
      if (mounted) Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            [l10n.recurringConfirmedMessage, ?budgetAlert].join('\n'),
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = recurringErrorMessage(l10n, error);
      });
    }
  }

  Future<void> _skip() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(recurringPaymentsProvider.notifier).skip(widget.payment.id);
      if (mounted) Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.recurringSkippedMessage)),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = recurringErrorMessage(l10n, error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final payment = widget.payment;
    final today = DateTime.now();
    final status = payment.statusOn(today);
    final statusColor =
        recurringStatusColor(status, theme.colorScheme) ??
        theme.colorScheme.onSurfaceVariant;

    final allAccounts = ref.watch(accountsProvider).value ?? const <Account>[];
    // Las cuotas de una deuda se pagan en la moneda de la deuda, que es la de la
    // cuenta del plan.
    final planCurrency = payment.isInstallmentPlan
        ? allAccounts
              .where((account) => account.id == payment.accountId)
              .map((account) => account.currency)
              .firstOrNull
        : null;
    final accounts = allAccounts
        .where(
          (account) =>
              !account.isArchived &&
              (planCurrency == null || account.currency == planCurrency),
        )
        .toList();
    // La cuenta de siempre, si sigue activa; si no, se elige otra.
    _accountId ??= accounts.any((a) => a.id == payment.accountId)
        ? payment.accountId
        : (accounts.length == 1 ? accounts.single.id : null);
    final currency =
        accounts.where((a) => a.id == _accountId).firstOrNull?.currency ??
        defaultCurrency;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.recurringConfirmTitle(payment.name),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(recurringStatusIcon(status), size: 16, color: statusColor),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    recurringStatusText(l10n, payment, today),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            if (payment.currentInstallment != null) ...[
              const SizedBox(height: 2),
              Text(
                [
                  l10n.installmentNumber(
                    payment.currentInstallment!,
                    payment.installments!,
                  ),
                  if (payment.debtRemaining != null)
                    l10n.recurringDebtRemaining(
                      context.formats.money(
                        payment.debtRemaining!,
                        currency: currency,
                      ),
                    ),
                ].join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 20),
            TextFormField(
              controller: _amount,
              enabled: !_saving,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              validator: (value) => TransactionValidators.amount(l10n, value),
              decoration: InputDecoration(
                labelText: l10n.commonAmount,
                hintText: l10n.transactionsAmountHint,
                prefixText: '${currencySymbol(currency)} ',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (accounts.isEmpty)
              Text(
                l10n.transactionsNeedAccountFirst,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              )
            else
              AccountDropdown(
                accounts: accounts,
                value: _accountId,
                label: l10n.recurringAccountLabel,
                enabled: !_saving,
                onChanged: (id) => setState(() => _accountId = id),
              ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _saving ? null : _pickDate,
              borderRadius: BorderRadius.circular(4),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l10n.commonDate,
                  border: const OutlineInputBorder(),
                  suffixIcon: const Icon(Icons.calendar_today_outlined),
                ),
                child: Text(context.formats.fullDate(_date)),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _description,
              enabled: !_saving,
              textCapitalization: TextCapitalization.sentences,
              validator: (value) =>
                  TransactionValidators.description(l10n, value),
              decoration: InputDecoration(
                labelText: l10n.transactionsDescriptionLabel,
                hintText: payment.name,
                border: const OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              ErrorBanner(_error!),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving || accounts.isEmpty ? null : _confirm,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.recurringConfirmButton),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _saving ? null : _skip,
              child: Text(l10n.recurringSkipAction),
            ),
          ],
        ),
      ),
    );
  }
}
