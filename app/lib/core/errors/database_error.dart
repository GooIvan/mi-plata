import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/l10n.dart';

/// El texto en el idioma del usuario de un error que la base de datos explica
/// con un código (el `detail` de sus validaciones, que llega en `details`).
///
/// Devuelve null si no trae código o no lo conocemos: quien llama decide qué
/// mostrar entonces (el mensaje en español de la base, o uno genérico).
String? databaseErrorMessage(AppLocalizations l10n, PostgrestException error) {
  final details = error.details;
  if (details is! String) return null;

  return switch (details) {
    'transaction_category_mismatch' => l10n.dbErrorTransactionCategoryMismatch,
    'transfer_currency_mismatch' => l10n.dbErrorTransferCurrencyMismatch,
    'budget_expense_only' => l10n.dbErrorBudgetExpenseOnly,
    'payment_direction_mismatch' => l10n.dbErrorPaymentDirectionMismatch,
    'payment_currency_mismatch' => l10n.dbErrorPaymentCurrencyMismatch,
    'payment_exceeds_remaining' => l10n.dbErrorPaymentExceedsRemaining,
    'payment_type_locked' => l10n.dbErrorPaymentTypeLocked,
    'debt_amount_below_paid' => l10n.dbErrorDebtAmountBelowPaid,
    'debt_direction_locked' => l10n.dbErrorDebtDirectionLocked,
    'debt_archived' => l10n.dbErrorDebtArchived,
    'rate_for_base_currency' => l10n.dbErrorRateForBaseCurrency,
    'base_rate_required' => l10n.dbErrorBaseRateRequired,
    'transfer_destination_amount_required' =>
      l10n.dbErrorTransferDestinationRequired,
    'recurring_finished' => l10n.dbErrorRecurringFinished,
    'recurring_category_mismatch' => l10n.dbErrorRecurringCategory,
    'recurring_end_before_due' => l10n.recurringEndBeforeNext,
    'recurring_not_found' => l10n.recurringErrorGone,
    'installment_debt_direction' => l10n.dbErrorInstallmentDirection,
    'installment_account_currency' => l10n.dbErrorInstallmentCurrency,
    'transfer_destination_amount_unexpected' =>
      l10n.dbErrorTransferDestinationUnexpected,
    'goal_account_card' => l10n.dbErrorGoalAccountCard,
    'profile_birth_date_future' => l10n.dbErrorProfileBirthDateFuture,
    'installment_purchase_not_card' => l10n.dbErrorInstallmentPurchaseNotCard,
    'installment_purchase_amounts' => l10n.dbErrorInstallmentPurchaseAmounts,
    'installment_purchase_locked' => l10n.dbErrorInstallmentPurchaseLocked,
    'debt_not_found' => l10n.debtsErrorMissingReference,
    'account_not_found' => l10n.debtsErrorMissingReference,
    _ => null,
  };
}
