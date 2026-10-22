import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mi_plata/app.dart';
import 'package:mi_plata/core/format/date_format.dart';
import 'package:mi_plata/core/riverpod/no_retry.dart';
import 'package:mi_plata/features/accounts/presentation/accounts_providers.dart';
import 'package:mi_plata/features/auth/presentation/auth_providers.dart';
import 'package:mi_plata/features/categories/presentation/categories_providers.dart';
import 'package:mi_plata/features/summary/presentation/summary_providers.dart';
import 'package:mi_plata/features/transactions/presentation/transactions_providers.dart';

import 'fake_account_repository.dart';
import 'fake_auth_repository.dart';
import 'fake_backend.dart';

/// Un texto con los espacios no separables normalizados (intl los usa).
Finder textLike(String text) => find.byWidgetPredicate(
  (widget) =>
      widget is Text &&
      widget.data?.replaceAll(' ', ' ').replaceAll(RegExp(r'\s+'), ' ') ==
          text,
);

/// Prepara los datos de fecha en español; se llama desde `setUpAll`.
Future<void> initDates() => initializeDateFormatting(dateLocale);

/// Abre la app completa con repositorios falsos y espera a que se asiente.
///
/// Si no se indica otra cosa, hay una sesión iniciada y ninguna cuenta.
Future<FakeBackend> pumpMiPlata(
  WidgetTester tester, {
  FakeAuthRepository? auth,
  FakeBackend? backend,
  FakeAccountRepository? accountRepository,
}) async {
  final fakes = backend ?? FakeBackend();

  await tester.pumpWidget(
    ProviderScope(
      retry: noRetry,
      overrides: [
        authRepositoryProvider.overrideWithValue(
          auth ?? FakeAuthRepository(signedInAs: 'ana@correo.com'),
        ),
        accountRepositoryProvider.overrideWithValue(
          accountRepository ?? fakes.accounts,
        ),
        transactionRepositoryProvider.overrideWithValue(fakes.transactions),
        categoryRepositoryProvider.overrideWithValue(fakes.categories),
        summaryRepositoryProvider.overrideWithValue(fakes.summary),
      ],
      child: const MiPlataApp(),
    ),
  );
  await tester.pumpAndSettle();
  return fakes;
}

/// Navega a [location] como lo haría un enlace, sin pasar por los botones.
Future<void> goTo(WidgetTester tester, String location) async {
  final context = tester.element(find.byType(Scaffold).first);
  GoRouter.of(context).push(location);
  await tester.pumpAndSettle();
}
