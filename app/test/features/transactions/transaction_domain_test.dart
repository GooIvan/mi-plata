import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/features/transactions/domain/transaction.dart';
import 'package:mi_plata/features/transactions/domain/transaction_draft.dart';
import 'package:mi_plata/features/transactions/domain/transaction_type.dart';
import 'package:mi_plata/features/transactions/domain/transaction_validators.dart';
import 'package:mi_plata/features/transactions/presentation/transaction_error_message.dart';
import 'package:mi_plata/l10n/l10n.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/test_app.dart';

late AppLocalizations l10n;

void main() {
  setUpAll(() async {
    l10n = await loadL10n();
    await initDates();
  });

  group('Transaction.fromJson', () {
    test('lee una transferencia', () {
      final transaction = Transaction.fromJson({
        'id': 't1',
        'user_id': 'u1',
        'type': 'transfer',
        'account_id': 'a1',
        'destination_account_id': 'a2',
        'category_id': null,
        'amount': 200000.5,
        'transaction_date': '2026-10-22',
        'description': null,
        'created_at': '2026-10-22T10:00:00Z',
      });

      expect(transaction.type, TransactionType.transfer);
      expect(transaction.destinationAccountId, 'a2');
      expect(transaction.categoryId, isNull);
      expect(transaction.amount, 200000.5);
      expect(transaction.destinationAmount, isNull);
      expect(transaction.date, DateTime(2026, 10, 22));
      expect(transaction.description, isNull);
    });

    test('lee lo que llega en una transferencia entre monedas', () {
      final transaction = Transaction.fromJson({
        'id': 't2',
        'type': 'transfer',
        'account_id': 'a1',
        'destination_account_id': 'a2',
        'category_id': null,
        'amount': 400000,
        'destination_amount': 99.5,
        'transaction_date': '2026-10-22',
        'description': null,
      });

      expect(transaction.amount, 400000);
      expect(transaction.destinationAmount, 99.5);
    });

    test('conoce los tres tipos de movimiento', () {
      for (final type in ['income', 'expense', 'transfer']) {
        expect(TransactionType.fromDb(type).dbValue, type);
      }
    });
  });

  group('TransactionDraft.toJson', () {
    test('envía la fecha sin hora, con ceros y los nulos explícitos', () {
      final json = TransactionDraft(
        type: TransactionType.expense,
        accountId: 'a1',
        amount: '1500.50',
        date: DateTime(2026, 3, 5, 23, 59),
      ).toJson();

      expect(json, {
        'type': 'expense',
        'account_id': 'a1',
        'destination_account_id': null,
        'category_id': null,
        'amount': '1500.50',
        'destination_amount': null,
        'transaction_date': '2026-03-05',
        'description': null,
      });
    });

    test('una transferencia entre monedas manda lo que llega', () {
      final json = TransactionDraft(
        type: TransactionType.transfer,
        accountId: 'a1',
        destinationAccountId: 'a2',
        amount: '400000',
        destinationAmount: '99.50',
        date: DateTime(2026, 3, 5),
      ).toJson();

      expect(json['amount'], '400000');
      expect(json['destination_amount'], '99.50');
    });
  });

  group('TransactionValidators', () {
    test('el monto debe existir, ser válido y positivo', () {
      expect(TransactionValidators.amount(l10n, '150.000'), isNull);
      expect(TransactionValidators.amount(l10n, '0,50'), isNull);
      expect(TransactionValidators.amount(l10n, null), 'Ingresa el monto');
      expect(TransactionValidators.amount(l10n, '  '), 'Ingresa el monto');
      expect(
        TransactionValidators.amount(l10n, '0'),
        'El monto debe ser mayor que cero',
      );
      expect(
        TransactionValidators.amount(l10n, '0,00'),
        'El monto debe ser mayor que cero',
      );
      expect(
        TransactionValidators.amount(l10n, '-10'),
        'El monto no puede ser negativo',
      );
      expect(TransactionValidators.amount(l10n, 'abc'), startsWith('Monto no válido'));
    });

    test('la descripción tiene un máximo', () {
      expect(TransactionValidators.description(l10n, null), isNull);
      expect(TransactionValidators.description(l10n, 'x' * 200), isNull);
      expect(
        TransactionValidators.description(l10n, 'x' * 201),
        'Usa 200 caracteres o menos',
      );
    });
  });

  group('transactionErrorMessage', () {
    String message(String? code, [String text = 'x']) =>
        transactionErrorMessage(
          l10n,
          PostgrestException(message: text, code: code),
        );

    test('oculta los mensajes técnicos de las restricciones CHECK', () {
      expect(
        message(
          '23514',
          'new row for relation "transactions" violates check constraint "x"',
        ),
        startsWith('Revisa los datos del movimiento'),
      );
    });

    test('muestra tal cual los mensajes en español de nuestros triggers', () {
      const trigger = 'Una transferencia requiere cuentas de la misma moneda';
      expect(message('23514', trigger), trigger);
    });

    test('traduce otros códigos y da un mensaje genérico para el resto', () {
      expect(message('23503'), startsWith('La cuenta o la categoría ya no existe'));
      expect(message('PGRST301'), startsWith('Tu sesión expiró'));
      expect(message('XX000'), startsWith('No se pudo completar'));
      expect(transactionErrorMessage(l10n, StateError('x')), startsWith('No se pudo'));
    });
  });
}
