import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/core/errors/database_error.dart';
import 'package:mi_plata/features/budgets/presentation/budget_error_message.dart';
import 'package:mi_plata/features/debts/presentation/debt_error_message.dart';
import 'package:mi_plata/features/transactions/presentation/transaction_error_message.dart';
import 'package:mi_plata/l10n/l10n.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/test_app.dart';

late AppLocalizations es;
late AppLocalizations en;

PostgrestException failure(String message, {String code = '23514', Object? details}) =>
    PostgrestException(message: message, code: code, details: details);

void main() {
  setUpAll(() async {
    es = await loadL10n('es');
    en = await loadL10n('en');
  });

  /// Cada código de la base, el mensaje en español que trae y su traducción.
  const known = {
    'transaction_category_mismatch': (
      'La categoría elegida no corresponde a este tipo de movimiento',
      'The chosen category does not match this type of transaction',
    ),
    'transfer_currency_mismatch': (
      'Una transferencia requiere cuentas de la misma moneda',
      'A transfer requires accounts in the same currency',
    ),
    'budget_expense_only': (
      'Solo las categorías de gasto pueden tener presupuesto',
      'Only expense categories can have a budget',
    ),
    'payment_direction_mismatch': (
      'El abono no corresponde al tipo de deuda',
      "The payment doesn't match the type of debt",
    ),
    'payment_currency_mismatch': (
      'El abono debe ser de una cuenta en la moneda de la deuda',
      "The payment must come from an account in the debt's currency",
    ),
    'payment_exceeds_remaining': (
      'El abono supera lo que falta por pagar',
      'The payment exceeds what is left to pay',
    ),
    'payment_type_locked': (
      'Este movimiento es el abono de una deuda: no se puede cambiar su tipo',
      "This transaction is a debt payment: its type can't be changed",
    ),
    'debt_amount_below_paid': (
      'El monto no puede ser menor a lo que ya se ha pagado',
      "The amount can't be less than what has already been paid",
    ),
    'debt_direction_locked': (
      'No se puede cambiar el sentido de una deuda que ya tiene abonos',
      "A debt's direction can't be changed once it has payments",
    ),
    'debt_archived': (
      'La deuda está archivada: restáurala para registrar abonos',
      'The debt is archived: restore it to record payments',
    ),
  };

  group('databaseErrorMessage', () {
    test('cada código sale en el idioma pedido', () {
      known.forEach((code, texts) {
        final error = failure('x', details: code);
        expect(databaseErrorMessage(es, error), texts.$1, reason: code);
        expect(databaseErrorMessage(en, error), texts.$2, reason: code);
      });
    });

    test('el español dice lo mismo que el mensaje de la base', () {
      // Así, quien use la base sin la app ve el mismo texto.
      known.forEach((code, texts) {
        expect(databaseErrorMessage(es, failure(texts.$1, details: code)), texts.$1);
      });
    });

    test('que algo ya no exista se dice igual para cuentas y deudas', () {
      for (final code in ['debt_not_found', 'account_not_found']) {
        expect(
          databaseErrorMessage(en, failure('x', code: '23503', details: code)),
          'The account or debt no longer exists. Reopen the screen.',
        );
      }
    });

    test('sin código, o con uno desconocido, no hay traducción', () {
      expect(databaseErrorMessage(en, failure('x')), isNull);
      expect(databaseErrorMessage(en, failure('x', details: 'otro_codigo')), isNull);
      expect(databaseErrorMessage(en, failure('x', details: 42)), isNull);
      expect(databaseErrorMessage(en, failure('x', details: 'Key (id)=(1) is not present')), isNull);
    });
  });

  group('los mensajes de cada pantalla', () {
    test('un error de validación sale en inglés', () {
      final error = failure('La categoría elegida no corresponde...', details: 'transaction_category_mismatch');
      expect(
        transactionErrorMessage(en, error),
        'The chosen category does not match this type of transaction',
      );
      expect(
        debtErrorMessage(en, failure('El abono supera lo que falta por pagar', details: 'payment_exceeds_remaining')),
        'The payment exceeds what is left to pay',
      );
      expect(
        budgetErrorMessage(en, failure('Solo las categorías...', details: 'budget_expense_only')),
        'Only expense categories can have a budget',
      );
    });

    test('sin código se muestra el mensaje que mande la base (servidor antiguo)', () {
      expect(
        transactionErrorMessage(en, failure('Mensaje de un servidor antiguo')),
        'Mensaje de un servidor antiguo',
      );
      expect(debtErrorMessage(en, failure('Otro mensaje')), 'Otro mensaje');
      expect(budgetErrorMessage(en, failure('Uno más')), 'Uno más');
    });

    test('las restricciones técnicas siguen dando el mensaje genérico', () {
      const technical = 'new row violates check constraint "x"';
      expect(transactionErrorMessage(en, failure(technical)),
          'Check the transaction data: the amount, accounts and category.');
      expect(debtErrorMessage(en, failure(technical)),
          'Check the debt data: the amount and dates.');
      expect(budgetErrorMessage(en, failure(technical)), 'Check the budget amount.');
    });

    test('una referencia que ya no existe', () {
      expect(
        debtErrorMessage(en, failure('x', code: '23503', details: 'account_not_found')),
        'The account or debt no longer exists. Reopen the screen.',
      );
      expect(
        debtErrorMessage(es, failure('x', code: '23503')),
        'La cuenta o la deuda ya no existe. Vuelve a abrir la pantalla.',
      );
    });
  });
}
