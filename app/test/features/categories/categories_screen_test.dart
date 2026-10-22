import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/features/categories/domain/category.dart';
import 'package:mi_plata/features/categories/domain/category_type.dart';
import 'package:mi_plata/features/categories/presentation/widgets/category_form_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/fake_backend.dart';
import '../../support/test_app.dart';

/// Abre la app y entra a Categorías desde el ícono del panel.
Future<FakeCategoryRepository> openCategories(
  WidgetTester tester, {
  List<Category> categories = const [],
}) async {
  final backend = FakeBackend(categories: categories);
  await pumpMiPlata(tester, backend: backend);
  await tester.tap(find.byTooltip('Categorías'));
  await tester.pumpAndSettle();
  return backend.categories;
}

Finder tab(String label) => find.widgetWithText(Tab, label);
Finder newCategoryButton() =>
    find.widgetWithText(FloatingActionButton, 'Nueva categoría');
Finder nameField() => find.byType(TextFormField);
Finder formButton(String label) => find.widgetWithText(FilledButton, label);

final _starter = [
  testCategory('Mercado', CategoryType.expense),
  testCategory('Transporte', CategoryType.expense),
  testCategory('Salario', CategoryType.income),
];

void main() {
  setUpAll(initDates);

  group('lista', () {
    testWidgets('se abre desde el panel y muestra primero los gastos', (
      tester,
    ) async {
      await openCategories(tester, categories: _starter);

      expect(find.widgetWithText(AppBar, 'Categorías'), findsOneWidget);
      expect(find.text('Mercado'), findsOneWidget);
      expect(find.text('Transporte'), findsOneWidget);
      expect(find.text('Salario'), findsNothing);
    });

    testWidgets('la pestaña Ingresos muestra solo las de ingreso', (tester) async {
      await openCategories(tester, categories: _starter);

      await tester.tap(tab('Ingresos'));
      await tester.pumpAndSettle();

      expect(find.text('Salario'), findsOneWidget);
      expect(find.text('Mercado'), findsNothing);
    });

    testWidgets('sin categorías de un tipo lo dice y ofrece crear', (tester) async {
      await openCategories(
        tester,
        categories: [testCategory('Mercado', CategoryType.expense)],
      );

      await tester.tap(tab('Ingresos'));
      await tester.pumpAndSettle();

      expect(find.text('Aún no tienes categorías de ingreso.'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Crear categoría'), findsOneWidget);
    });

    testWidgets('las archivadas se ocultan y se pueden mostrar', (tester) async {
      await openCategories(
        tester,
        categories: [
          testCategory('Mercado', CategoryType.expense),
          testCategory('Vieja', CategoryType.expense, archived: true),
        ],
      );

      expect(find.text('Vieja'), findsNothing);

      await tester.tap(find.byTooltip('Mostrar archivadas'));
      await tester.pumpAndSettle();

      expect(find.text('Vieja'), findsOneWidget);
      expect(find.text('Archivada'), findsOneWidget);
    });

    testWidgets('si todas las de un tipo están archivadas lo avisa', (tester) async {
      await openCategories(
        tester,
        categories: [testCategory('Vieja', CategoryType.expense, archived: true)],
      );

      expect(
        find.text('Todas tus categorías de gasto están archivadas.'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'Mostrar archivadas'));
      await tester.pumpAndSettle();
      expect(find.text('Vieja'), findsOneWidget);
    });

    testWidgets('si falla la carga muestra el error y permite reintentar', (
      tester,
    ) async {
      final backend = FakeBackend(categories: _starter);
      backend.categories.error = const PostgrestException(
        message: 'boom',
        code: '500',
      );
      await pumpMiPlata(tester, backend: backend);
      await tester.tap(find.byTooltip('Categorías'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No se pudo completar'), findsOneWidget);

      backend.categories.error = null;
      await tester.tap(find.widgetWithText(OutlinedButton, 'Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('Mercado'), findsOneWidget);
    });
  });

  group('crear', () {
    testWidgets('en la pestaña Gastos crea una categoría de gasto', (tester) async {
      final repository = await openCategories(tester, categories: _starter);

      await tester.tap(newCategoryButton());
      await tester.pumpAndSettle();
      expect(find.text('Nueva categoría de gasto'), findsOneWidget);

      await tester.enterText(nameField(), '  Mascotas ');
      await tester.tap(formButton('Crear categoría'));
      await tester.pumpAndSettle();

      expect(repository.calls, contains('create:Mascotas:expense'));
      expect(find.byType(CategoryFormSheet), findsNothing);
      expect(find.text('Mascotas'), findsOneWidget);
    });

    testWidgets('en la pestaña Ingresos crea una categoría de ingreso', (
      tester,
    ) async {
      final repository = await openCategories(tester, categories: _starter);

      await tester.tap(tab('Ingresos'));
      await tester.pumpAndSettle();
      await tester.tap(newCategoryButton());
      await tester.pumpAndSettle();
      expect(find.text('Nueva categoría de ingreso'), findsOneWidget);

      await tester.enterText(nameField(), 'Freelance');
      await tester.tap(formButton('Crear categoría'));
      await tester.pumpAndSettle();

      expect(repository.calls, contains('create:Freelance:income'));
      expect(find.text('Freelance'), findsOneWidget);
    });

    testWidgets('exige un nombre y no llama al servidor', (tester) async {
      final repository = await openCategories(tester, categories: _starter);

      await tester.tap(newCategoryButton());
      await tester.pumpAndSettle();
      await tester.tap(formButton('Crear categoría'));
      await tester.pump();

      expect(find.text('Ponle un nombre a la categoría'), findsOneWidget);
      expect(repository.calls.where((c) => c.startsWith('create')), isEmpty);
    });

    testWidgets('un nombre repetido muestra el error y deja el formulario', (
      tester,
    ) async {
      await openCategories(tester, categories: _starter);

      await tester.tap(newCategoryButton());
      await tester.pumpAndSettle();
      await tester.enterText(nameField(), 'mercado');
      await tester.tap(formButton('Crear categoría'));
      await tester.pumpAndSettle();

      expect(
        find.text('Ya tienes una categoría activa con ese nombre.'),
        findsOneWidget,
      );
      expect(find.byType(CategoryFormSheet), findsOneWidget);
    });

    testWidgets('el mismo nombre se permite en el otro tipo', (tester) async {
      final repository = await openCategories(
        tester,
        categories: [
          testCategory('Otros', CategoryType.expense),
          testCategory('Salario', CategoryType.income),
        ],
      );

      await tester.tap(tab('Ingresos'));
      await tester.pumpAndSettle();
      await tester.tap(newCategoryButton());
      await tester.pumpAndSettle();
      await tester.enterText(nameField(), 'Otros');
      await tester.tap(formButton('Crear categoría'));
      await tester.pumpAndSettle();

      expect(repository.calls, contains('create:Otros:income'));
      expect(find.byType(CategoryFormSheet), findsNothing);
    });

    testWidgets('desde el estado vacío también se puede crear', (tester) async {
      final repository = await openCategories(tester);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Crear categoría'));
      await tester.pumpAndSettle();
      await tester.enterText(nameField(), 'Mercado');
      await tester.tap(formButton('Crear categoría'));
      await tester.pumpAndSettle();

      expect(repository.calls, contains('create:Mercado:expense'));
    });
  });

  group('editar y archivar', () {
    testWidgets('renombrar precarga el nombre y guarda el cambio', (tester) async {
      final repository = await openCategories(tester, categories: _starter);

      await tester.tap(find.text('Mercado'));
      await tester.pumpAndSettle();

      expect(find.text('Editar categoría de gasto'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Mercado'), findsOneWidget);

      await tester.enterText(nameField(), 'Supermercado');
      await tester.tap(formButton('Guardar'));
      await tester.pumpAndSettle();

      expect(repository.calls, contains('rename:cat-Mercado:Supermercado'));
      expect(find.text('Supermercado'), findsOneWidget);
      expect(find.text('Mercado'), findsNothing);
    });

    testWidgets('renombrar a un nombre que ya existe da el error', (tester) async {
      await openCategories(tester, categories: _starter);

      await tester.tap(find.text('Mercado'));
      await tester.pumpAndSettle();
      await tester.enterText(nameField(), 'Transporte');
      await tester.tap(formButton('Guardar'));
      await tester.pumpAndSettle();

      expect(
        find.text('Ya tienes una categoría activa con ese nombre.'),
        findsOneWidget,
      );
    });

    testWidgets('archivar la saca de la lista y se puede deshacer', (tester) async {
      final repository = await openCategories(tester, categories: _starter);

      await tester.tap(find.byTooltip('Opciones').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archivar'));
      await tester.pumpAndSettle();

      expect(find.text('Categoría archivada'), findsOneWidget);
      expect(find.text('Mercado'), findsNothing);

      await tester.tap(find.text('Deshacer'));
      await tester.pumpAndSettle();

      expect(find.text('Mercado'), findsOneWidget);
      expect(
        repository.categories.firstWhere((c) => c.name == 'Mercado').isArchived,
        isFalse,
      );
    });

    testWidgets('restaurar una archivada la devuelve a la lista', (tester) async {
      final repository = await openCategories(
        tester,
        categories: [testCategory('Vieja', CategoryType.expense, archived: true)],
      );

      await tester.tap(find.byTooltip('Mostrar archivadas'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Opciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restaurar'));
      await tester.pumpAndSettle();

      expect(find.text('Categoría restaurada'), findsOneWidget);
      expect(repository.categories.single.isArchived, isFalse);
    });

    testWidgets('no se puede restaurar si ya hay una activa con ese nombre', (
      tester,
    ) async {
      await openCategories(
        tester,
        categories: [
          testCategory('Mercado', CategoryType.expense),
          // Mismo nombre que la activa, pero con otro id para el escenario.
          Category(
            id: 'cat-Mercado-viejo',
            name: 'Mercado',
            type: CategoryType.expense,
            isArchived: true,
          ),
        ],
      );

      await tester.tap(find.byTooltip('Mostrar archivadas'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Opciones').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restaurar'));
      await tester.pumpAndSettle();

      expect(
        find.text('Ya tienes una categoría activa con ese nombre.'),
        findsOneWidget,
      );
    });
  });
}
