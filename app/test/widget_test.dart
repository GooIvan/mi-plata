import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/app.dart';

void main() {
  testWidgets('muestra la pantalla inicial', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MiPlataApp()));

    expect(find.text('mi-plata'), findsOneWidget);
  });
}
