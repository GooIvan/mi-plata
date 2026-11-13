import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/currency/presentation/rates_refresh.dart';
import '../../l10n/l10n.dart';

/// El marco de las pestañas principales: la barra de navegación de abajo y,
/// encima, la pestaña elegida. Cada pestaña conserva su estado al cambiar.
///
/// El orden de los destinos es el de las ramas del router.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
    required this.tabNavigators,
  });

  final StatefulNavigationShell navigationShell;

  /// El navegador de cada pestaña, en el orden de los destinos.
  final List<GlobalKey<NavigatorState>> tabNavigators;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  void initState() {
    super.initState();
    // Al abrir la app con sesión, las tasas automáticas se ponen al día (una
    // vez al día). Si falla, no pasa nada: quedan las últimas guardadas.
    if (ref.read(automaticRatesOnOpenProvider)) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => refreshAutomaticRates(ref),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final navigationShell = widget.navigationShell;
    final tabNavigators = widget.tabNavigators;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          // Tocar la pestaña en la que ya estás cierra lo que abriste en ella
          // (un detalle, por ejemplo) y vuelve a su pantalla inicial.
          if (index == navigationShell.currentIndex) {
            tabNavigators[index].currentState?.popUntil((r) => r.isFirst);
          }
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l10n.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.receipt_long_outlined),
            selectedIcon: const Icon(Icons.receipt_long),
            label: l10n.navTransactions,
          ),
          NavigationDestination(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: const Icon(Icons.account_balance_wallet),
            label: l10n.accountsTitle,
          ),
          NavigationDestination(
            icon: const Icon(Icons.flag_outlined),
            selectedIcon: const Icon(Icons.flag),
            label: l10n.navGoals,
          ),
          NavigationDestination(
            icon: const Icon(Icons.menu),
            label: l10n.navMore,
          ),
        ],
      ),
    );
  }
}
