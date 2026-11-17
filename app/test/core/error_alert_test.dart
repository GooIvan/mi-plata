import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/core/widgets/error_alert.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/fake_auth_repository.dart';
import '../support/test_app.dart';

/// Una pantalla con un botón que muestra un error, y otro que abre una hoja con
/// su propio botón: así se prueba que el aviso queda por encima de la hoja.
Widget harness() => localizedApp(
  home: Builder(
    builder: (context) => Scaffold(
      body: Column(
        children: [
          TextButton(
            onPressed: () => showErrorAlert(context, 'Primer error'),
            child: const Text('mostrar'),
          ),
          TextButton(
            onPressed: () => showErrorAlert(context, 'Segundo error'),
            child: const Text('mostrar otro'),
          ),
          TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              useRootNavigator: true,
              builder: (sheet) => SizedBox(
                height: 300,
                child: Center(
                  child: TextButton(
                    onPressed: () => showErrorAlert(sheet, 'Error en la hoja'),
                    child: const Text('fallar'),
                  ),
                ),
              ),
            ),
            child: const Text('abrir hoja'),
          ),
        ],
      ),
    ),
  ),
);

void main() {
  setUpAll(initDates);

  group('showErrorAlert', () {
    testWidgets('muestra el mensaje y desaparece a los 3 segundos', (
      tester,
    ) async {
      await tester.pumpWidget(harness());

      await tester.tap(find.text('mostrar'));
      await tester.pumpAndSettle();
      expect(find.text('Primer error'), findsOneWidget);

      // A los 2,9 s todavía está.
      await tester.pump(const Duration(milliseconds: 2800));
      expect(find.text('Primer error'), findsOneWidget);

      // Pasados los 3 s (más lo que tarda en salir) ya no.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('Primer error'), findsNothing);
    });

    testWidgets('dura exactamente 3 segundos', (tester) async {
      expect(errorAlertDuration, const Duration(seconds: 3));
    });

    testWidgets('al tocarlo se va antes', (tester) async {
      await tester.pumpWidget(harness());
      await tester.tap(find.text('mostrar'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Primer error'));
      await tester.pumpAndSettle();

      expect(find.text('Primer error'), findsNothing);
    });

    testWidgets('un error nuevo reemplaza al anterior: solo hay uno', (
      tester,
    ) async {
      await tester.pumpWidget(harness());

      await tester.tap(find.text('mostrar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('mostrar otro'));
      await tester.pumpAndSettle();

      expect(find.text('Primer error'), findsNothing);
      expect(find.text('Segundo error'), findsOneWidget);
    });

    testWidgets('el segundo error cuenta sus propios 3 segundos', (
      tester,
    ) async {
      await tester.pumpWidget(harness());

      await tester.tap(find.text('mostrar'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.text('mostrar otro'));
      await tester.pumpAndSettle();
      // Han pasado 2 s del primero, pero el segundo apenas empieza.
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Segundo error'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Segundo error'), findsNothing);
    });

    testWidgets('queda por encima de una hoja modal, arriba de la pantalla', (
      tester,
    ) async {
      await tester.pumpWidget(harness());
      await tester.tap(find.text('abrir hoja'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('fallar'));
      await tester.pumpAndSettle();

      expect(find.text('Error en la hoja'), findsOneWidget);
      // Arriba: la hoja ocupa la parte de abajo.
      expect(
        tester.getTopLeft(find.text('Error en la hoja')).dy,
        lessThan(120),
      );
      // Y se puede tocar (no está tapado por la hoja ni por su fondo).
      await tester.tap(find.text('Error en la hoja'));
      await tester.pumpAndSettle();
      expect(find.text('Error en la hoja'), findsNothing);
    });
  });

  group('ErrorAlert (en los formularios)', () {
    testWidgets('muestra el aviso al aparecer y no dibuja nada', (
      tester,
    ) async {
      await tester.pumpWidget(
        localizedApp(home: const Scaffold(body: ErrorAlert('Algo falló'))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Algo falló'), findsOneWidget);
      // El propio widget no ocupa espacio.
      expect(tester.getSize(find.byType(ErrorAlert)), Size.zero);
    });

    testWidgets('avisa de nuevo si el mensaje cambia, y no si es el mismo', (
      tester,
    ) async {
      final message = ValueNotifier('Uno');
      await tester.pumpWidget(
        localizedApp(
          home: Scaffold(
            body: ValueListenableBuilder(
              valueListenable: message,
              builder: (_, value, _) => ErrorAlert(value),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Uno'), findsOneWidget);

      // Pasan los 3 s: se fue. Reconstruir con el mismo texto no lo repite.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      message.value = 'Uno';
      await tester.pumpAndSettle();
      expect(find.text('Uno'), findsNothing);

      message.value = 'Dos';
      await tester.pumpAndSettle();
      expect(find.text('Dos'), findsOneWidget);
    });
  });

  group('en las pantallas', () {
    testWidgets('el error de conexión sale arriba, dura 3 segundos y se va', (
      tester,
    ) async {
      final repository = FakeAuthRepository()
        ..error = AuthRetryableFetchException();
      tallView(tester);
      // Sin sesión: la app abre en el inicio de sesión.
      await pumpMiPlata(tester, auth: repository);

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'ana@correo.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'clave1234');
      await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
      await tester.pumpAndSettle();

      const message =
          'No hay conexión con el servidor. Revisa tu internet e intenta de nuevo.';
      expect(find.text(message), findsOneWidget);
      // Ya no es un recuadro fijo dentro del formulario.
      expect(
        find.descendant(of: find.byType(Form), matching: find.text(message)),
        findsNothing,
      );

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text(message), findsNothing);
    });
  });
}
