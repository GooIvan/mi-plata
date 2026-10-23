class AppRoutes {
  const AppRoutes._();

  static const dashboard = '/';
  static const login = '/login';
  static const register = '/register';
  static const accounts = '/accounts';
  static const transactions = '/transactions';
  static const categories = '/categories';
  static const summary = '/summary';
  static const debts = '/debts';
  static const budgets = '/budgets';
  static const settings = '/settings';
  static const rates = '/rates';
  static const recurring = '/recurring';

  /// Rutas accesibles sin sesión.
  static const public = {login, register};
}
