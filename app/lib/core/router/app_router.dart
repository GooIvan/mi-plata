import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/accounts/presentation/accounts_screen.dart';
import '../../features/auth/presentation/auth_providers.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/budgets/presentation/budgets_screen.dart';
import '../../features/categories/presentation/categories_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/currency/presentation/rates_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/more/presentation/more_screen.dart';
import '../../features/recurring/presentation/recurring_screen.dart';
import '../../features/savings/presentation/goals_screen.dart';
import '../../features/debts/presentation/debts_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/summary/presentation/summary_screen.dart';
import '../../features/transactions/presentation/transactions_screen.dart';
import 'app_routes.dart';
import 'app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  final refresh = _AuthRefresh(auth.authStateChanges);
  // Un navegador por pestaña: así se puede volver a su pantalla inicial.
  final tabNavigators = List.generate(5, (_) => GlobalKey<NavigatorState>());

  final router = GoRouter(
    refreshListenable: refresh,
    redirect: (context, state) {
      final isLoggedIn = auth.currentSession != null;
      final isPublicRoute = AppRoutes.public.contains(state.matchedLocation);

      if (!isLoggedIn) return isPublicRoute ? null : AppRoutes.login;
      return isPublicRoute ? AppRoutes.dashboard : null;
    },
    routes: [
      // Las pestañas de la barra de navegación, en su orden.
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            AppShell(navigationShell: shell, tabNavigators: tabNavigators),
        branches: [
          for (final (index, (path, screen))
              in <(String, Widget)>[
                (AppRoutes.dashboard, const DashboardScreen()),
                (AppRoutes.transactions, const TransactionsScreen()),
                (AppRoutes.accounts, const AccountsScreen()),
                (AppRoutes.goals, const GoalsScreen()),
                (AppRoutes.more, const MoreScreen()),
              ].indexed)
            StatefulShellBranch(
              navigatorKey: tabNavigators[index],
              routes: [GoRoute(path: path, builder: (_, _) => screen)],
            ),
        ],
      ),
      GoRoute(
        path: AppRoutes.categories,
        builder: (context, state) => const CategoriesScreen(),
      ),
      GoRoute(
        path: AppRoutes.debts,
        builder: (context, state) => const DebtsScreen(),
      ),
      GoRoute(
        path: AppRoutes.summary,
        builder: (context, state) => const SummaryScreen(),
      ),
      GoRoute(
        path: AppRoutes.budgets,
        builder: (context, state) => const BudgetsScreen(),
      ),
      GoRoute(
        path: AppRoutes.recurring,
        builder: (context, state) => const RecurringScreen(),
      ),
      GoRoute(
        path: AppRoutes.rates,
        builder: (context, state) => const RatesScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

/// Hace que el router vuelva a evaluar sus redirecciones cuando cambia la sesión.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Stream<AuthState> stream) {
    _subscription = stream.listen((_) => notifyListeners(), onError: (_) {});
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
