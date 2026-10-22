class AppRoutes {
  const AppRoutes._();

  static const dashboard = '/';
  static const login = '/login';
  static const register = '/register';
  static const accounts = '/accounts';
  static const transactions = '/transactions';
  static const categories = '/categories';
  static const summary = '/summary';

  /// Rutas accesibles sin sesión.
  static const public = {login, register};
}
