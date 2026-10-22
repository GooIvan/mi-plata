import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/features/transactions/domain/transaction.dart';
import 'package:mi_plata/features/transactions/domain/transaction_draft.dart';
import 'package:mi_plata/features/transactions/domain/transaction_type.dart';
import 'package:mi_plata/features/transactions/domain/transaction_validators.dart';
import 'package:mi_plata/features/transactions/presentation/transaction_error_message.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
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
      expect(transaction.date, DateTime(2026, 10, 22));
      expect(transaction.description, isNull);
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
        'transaction_date': '2026-03-05',
        'description': null,
      });
    });
  });

  group('TransactionValidators', () {
    test('el monto debe existir, ser válido y positivo', () {
      expect(TransactionValidators.amount('150.000'), isNull);
      expect(TransactionValidators.amount('0,50'), isNull);
      expect(TransactionValidators.amount(null), 'Ingresa el monto');
      expect(TransactionValidators.amount('  '), 'Ingresa el monto');
      expect(
        TransactionValidators.amount('0'),
        'El monto debe ser mayor que cero',
      );
      expect(
        TransactionValidators.amount('0,00'),
        'El monto debe ser mayor que cero',
      );
      expect(
        TransactionValidators.amount('-10'),
        'El monto no puede ser negativo',
      );
      expect(TransactionValidators.amount('abc'), startsWith('Monto no válido'));
    });

    test('la descripción tiene un máximo', () {
      expect(TransactionValidators.description(null), isNull);
      expect(TransactionValidators.description('x' * 200), isNull);
      expect(
        TransactionValidators.description('x' * 201),
        'Usa 200 caracteres o menos',
      );
    });
  });

  group('transactionErrorMessage', () {
    String message(String? code, [String text = 'x']) => transactionErrorMessage(
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
      expect(transactionErrorMessage(StateError('x')), startsWith('No se pudo'));
    });
  });
}
