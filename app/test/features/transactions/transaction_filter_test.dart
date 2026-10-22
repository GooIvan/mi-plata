import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/features/transactions/domain/transaction_filter.dart';
import 'package:mi_plata/features/transactions/domain/transaction_type.dart';

void main() {
  const empty = TransactionFilter.empty;

  group('vacío', () {
    test('no tiene criterios', () {
      expect(empty.isEmpty, isTrue);
      expect(empty.activeCount, 0);
    });
  });

  group('texto', () {
    test('se recorta', () {
      expect(empty.withText('  rappi ').text, 'rappi');
    });

    test('uno vacío o de espacios quita el criterio', () {
      final filter = empty.withText('rappi');

      expect(filter.withText('').text, isNull);
      expect(filter.withText('   ').text, isNull);
      expect(filter.withText(null).text, isNull);
      expect(filter.withText(null).isEmpty, isTrue);
    });
  });

  group('criterios', () {
    test('cada uno cuenta una vez', () {
      expect(empty.withType(TransactionType.expense).activeCount, 1);
      expect(empty.withAccount('a1').activeCount, 1);
      expect(empty.withCategory('c1').activeCount, 1);
      expect(empty.withText('x').activeCount, 1);
    });

    test('el rango de fechas cuenta como uno, aunque tenga un solo extremo', () {
      expect(empty.withRange(DateTime(2026, 10, 1), DateTime(2026, 10, 31)).activeCount, 1);
      expect(empty.withRange(DateTime(2026, 10, 1), null).activeCount, 1);
      expect(empty.withRange(null, DateTime(2026, 10, 31)).activeCount, 1);
    });

    test('se combinan', () {
      final filter = empty
          .withText('mercado')
          .withType(TransactionType.expense)
          .withAccount('a1')
          .withCategory('c1')
          .withRange(DateTime(2026, 10, 1), DateTime(2026, 10, 31));

      expect(filter.activeCount, 5);
      expect(filter.isEmpty, isFalse);
    });

    test('quitar un criterio no toca a los demás', () {
      final filter = empty
          .withType(TransactionType.income)
          .withAccount('a1')
          .withAccount(null);

      expect(filter.accountId, isNull);
      expect(filter.type, TransactionType.income);
    });
  });

  group('categoría', () {
    test('"sin categoría" reemplaza a una categoría concreta, y al revés', () {
      final concrete = empty.withCategory('c1');
      final none = concrete.withUncategorized();

      expect(none.uncategorized, isTrue);
      expect(none.categoryId, isNull);
      expect(none.activeCount, 1);

      final back = none.withCategory('c2');
      expect(back.uncategorized, isFalse);
      expect(back.categoryId, 'c2');
    });

    test('quitar la categoría también quita "sin categoría"', () {
      expect(empty.withUncategorized().withCategory(null).isEmpty, isTrue);
    });
  });

  group('fechas', () {
    test('se guardan sin hora', () {
      final filter = empty.withRange(
        DateTime(2026, 10, 1, 18, 30),
        DateTime(2026, 10, 31, 6),
      );

      expect(filter.from, DateTime(2026, 10, 1));
      expect(filter.to, DateTime(2026, 10, 31));
    });

    test('sin ninguna fecha quita el criterio', () {
      final filter = empty
          .withRange(DateTime(2026, 10, 1), DateTime(2026, 10, 31))
          .withRange(null, null);

      expect(filter.isEmpty, isTrue);
    });

    test('poner solo una fecha borra la otra', () {
      final filter = empty
          .withRange(DateTime(2026, 10, 1), DateTime(2026, 10, 31))
          .withRange(DateTime(2026, 11, 1), null);

      expect(filter.from, DateTime(2026, 11, 1));
      expect(filter.to, isNull);
    });
  });

  test('onlyText conserva el texto y quita el resto', () {
    final filter = empty
        .withText('rappi')
        .withType(TransactionType.expense)
        .withAccount('a1')
        .withCategory('c1')
        .withRange(DateTime(2026, 10, 1), null);

    final cleared = filter.onlyText;

    expect(cleared.text, 'rappi');
    expect(cleared.activeCount, 1);
    expect(empty.onlyText.isEmpty, isTrue);
  });

  group('igualdad', () {
    test('dos filtros con los mismos criterios son iguales', () {
      final a = empty.withText('x').withAccount('a1');
      final b = empty.withAccount('a1').withText('x');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('con criterios distintos no son iguales', () {
      expect(empty.withText('x'), isNot(empty.withText('y')));
      expect(empty.withCategory('c1'), isNot(empty.withUncategorized()));
      expect(empty, isNot(empty.withType(TransactionType.income)));
    });

    test('es inmutable: cada with devuelve uno nuevo', () {
      final original = empty.withText('x');
      original.withType(TransactionType.income);

      expect(original.type, isNull);
    });
  });
}
