import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/accounts/presentation/accounts_screen.dart';
import '../../features/auth/presentation/auth_providers.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/budgets/presentation/budgets_screen.dart';
import '../../features/categories/presentation/categories_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/debts/presentation/debts_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/summary/presentation/summary_screen.dart';
import '../../features/transactions/presentation/transactions_screen.dart';
import 'app_routes.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  final refresh = _AuthRefresh(auth.authStateChanges);

  final router = GoRouter(
    refreshListenable: refresh,
    redirect: (context, state) {
      final isLoggedIn = auth.currentSession != null;
      final isPublicRoute = AppRoutes.public.contains(state.matchedLocation);

      if (!isLoggedIn) return isPublicRoute ? null : AppRoutes.login;
      return isPublicRoute ? AppRoutes.dashboard : null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.dashboard,
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.accounts,
        builder: (context, state) => const AccountsScreen(),
      ),
      GoRoute(
        path: AppRoutes.transactions,
        builder: (context, state) => const TransactionsScreen(),
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
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
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
