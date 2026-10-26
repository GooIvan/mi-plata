import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/features/debts/domain/installment_plan_draft.dart';
import 'package:mi_plata/features/recurring/domain/recurrence.dart';
import 'package:mi_plata/features/recurring/domain/recurring_payment.dart';
import 'package:mi_plata/features/recurring/presentation/recurring_error_message.dart';
import 'package:mi_plata/features/recurring/presentation/recurring_ui.dart';
import 'package:mi_plata/l10n/l10n.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/test_app.dart';

final today = DateTime(2026, 10, 23);

RecurringPayment plan({
  double amount = 200000,
  int? installments = 12,
  int paid = 0,
  double? remaining = 2400000,
  DateTime? next,
  bool noNext = false,
  bool paused = false,
  Recurrence recurrence = Recurrence.monthly,
}) => RecurringPayment(
  id: 'p1',
  name: 'TV Samsung',
  amount: amount,
  accountId: 'a1',
  recurrence: recurrence,
  nextDueDate: noNext ? null : (next ?? DateTime(2026, 11, 5)),
  anchorDay: 5,
  isPaused: paused,
  debtId: 'd1',
  installments: installments,
  installmentsPaid: paid,
  debtRemaining: remaining,
);

late AppLocalizations es;
late AppLocalizations en;

void main() {
  setUpAll(() async {
    await initDates();
    es = await loadL10n('es');
    en = await loadL10n('en');
  });

  group('RecurringPayment de un plan de cuotas', () {
    test('lee lo que trae la vista: la deuda, las cuotas y lo que falta', () {
      final parsed = RecurringPayment.fromJson({
        'id': 'r1',
        'name': 'TV Samsung',
        'amount': 200000,
        'account_id': 'a1',
        'category_id': null,
        'every': 1,
        'unit': 'month',
        'next_due_date': '2026-11-05',
        'anchor_day': 5,
        'end_date': null,
        'is_paused': false,
        'debt_id': 'd1',
        'installments': 12,
        'installments_paid': 3,
        'debt_remaining': 1800000.5,
      });

      expect(parsed.isInstallmentPlan, isTrue);
      expect(parsed.debtId, 'd1');
      expect(parsed.installments, 12);
      expect(parsed.installmentsPaid, 3);
      expect(parsed.debtRemaining, 1800000.5);
    });

    test('un pago normal no trae nada de eso', () {
      final parsed = RecurringPayment.fromJson({
        'id': 'r1',
        'name': 'Netflix',
        'amount': 30000,
        'account_id': 'a1',
        'every': 1,
        'unit': 'month',
        'next_due_date': '2026-11-05',
        'anchor_day': 5,
        'is_paused': false,
        'debt_id': null,
        'installments': null,
        'installments_paid': 0,
        'debt_remaining': null,
      });

      expect(parsed.isInstallmentPlan, isFalse);
      expect(parsed.currentInstallment, isNull);
      expect(parsed.isSettled, isFalse);
      expect(parsed.nextAmount, 30000);
    });

    test('cuál cuota toca: las pagadas más una, sin pasarse de las pactadas', () {
      expect(plan(paid: 0).currentInstallment, 1);
      expect(plan(paid: 3).currentInstallment, 4);
      expect(plan(paid: 11).currentInstallment, 12);
      expect(plan(paid: 12).currentInstallment, 12);
      expect(plan(paid: 15).currentInstallment, 12);
      expect(plan(installments: null).currentInstallment, isNull);
    });

    test('se propone la cuota; la última, lo que falte', () {
      expect(plan(remaining: 2400000).nextAmount, 200000);
      expect(plan(remaining: 200000).nextAmount, 200000);
      expect(plan(remaining: 150000.5).nextAmount, 150000.5);
    });

    test('con la deuda saldada, el plan terminó aunque tenga próxima fecha', () {
      final settled = plan(remaining: 0);
      expect(settled.isSettled, isTrue);
      expect(settled.isFinished, isTrue);
      expect(settled.canPay, isFalse);
      expect(settled.statusOn(today), RecurringStatus.finished);
      expect(settled.needsAttention(today), isFalse);
    });

    test('un resto de menos de un centavo cuenta como saldado', () {
      expect(plan(remaining: 0.004).isSettled, isTrue);
      expect(plan(remaining: 0.01).isSettled, isFalse);
    });

    test('mientras debe algo, sigue el estado de siempre', () {
      expect(plan(next: DateTime(2026, 10, 20)).statusOn(today), RecurringStatus.overdue);
      expect(plan(next: DateTime(2026, 10, 25)).statusOn(today), RecurringStatus.soon);
      expect(plan(next: DateTime(2026, 12, 25)).statusOn(today), RecurringStatus.later);
      expect(plan(paused: true).statusOn(today), RecurringStatus.paused);
      expect(plan(noNext: true).statusOn(today), RecurringStatus.finished);
    });
  });

  group('recurrenceSummary', () {
    test('un plan dice qué cuota toca y cada cuánto', () {
      expect(recurrenceSummary(es, plan(paid: 3)), 'Cuota 4 de 12 · Cada mes');
      expect(recurrenceSummary(en, plan(paid: 3)), 'Installment 4 of 12 · Every month');
      expect(
        recurrenceSummary(es, plan(paid: 0, recurrence: Recurrence.biweekly)),
        'Cuota 1 de 12 · Cada 2 semanas',
      );
    });

    test('un pago normal, solo cada cuánto', () {
      expect(recurrenceSummary(es, plan(installments: null)), 'Cada mes');
    });
  });

  group('InstallmentPlanDraft.toRpcParams', () {
    test('manda la deuda y el plan a create_installment_debt', () {
      final params = InstallmentPlanDraft(
        counterparty: 'TV Samsung',
        amount: '2400000',
        installments: 12,
        installmentAmount: '200000',
        recurrence: Recurrence.bimonthly,
        firstDue: DateTime(2026, 11, 5, 18),
        accountId: 'a1',
        startDate: DateTime(2026, 10, 23),
        notes: 'Con garantía',
      ).toRpcParams();

      expect(params, {
        'p_counterparty': 'TV Samsung',
        'p_amount': '2400000',
        'p_installments': 12,
        'p_installment_amount': '200000',
        'p_every': 2,
        'p_unit': 'month',
        'p_first_due': '2026-11-05',
        'p_account_id': 'a1',
        'p_category_id': null,
        'p_start_date': '2026-10-23',
        'p_notes': 'Con garantía',
      });
    });

    test('con categoría', () {
      final params = InstallmentPlanDraft(
        counterparty: 'Nevera',
        amount: '1000',
        installments: 2,
        installmentAmount: '500',
        recurrence: Recurrence.weekly,
        firstDue: DateTime(2026, 11, 1),
        accountId: 'a1',
        categoryId: 'c1',
        startDate: DateTime(2026, 10, 23),
      ).toRpcParams();

      expect(params['p_category_id'], 'c1');
      expect(params['p_unit'], 'week');
      expect(params['p_notes'], isNull);
    });
  });

  group('los errores del plan se traducen', () {
    PostgrestException failure(String details) =>
        PostgrestException(message: 'x', code: '23514', details: details);

    test('solo se pagan en cuotas las deudas que debo', () {
      expect(
        recurringErrorMessage(es, failure('installment_debt_direction')),
        'Solo las deudas que debes pueden pagarse en cuotas',
      );
      expect(
        recurringErrorMessage(en, failure('installment_debt_direction')),
        'Only debts you owe can be paid in installments',
      );
    });

    test('la cuenta tiene que ser de la moneda de la deuda', () {
      expect(
        recurringErrorMessage(es, failure('installment_account_currency')),
        'La cuenta de las cuotas tiene que ser de la moneda de la deuda',
      );
      expect(
        recurringErrorMessage(en, failure('installment_account_currency')),
        "The installments' account must be in the debt's currency",
      );
    });

    test('un abono que se pasa de lo que falta también se explica', () {
      expect(
        recurringErrorMessage(en, failure('payment_exceeds_remaining')),
        'The payment exceeds what is left to pay',
      );
    });
  });
}
