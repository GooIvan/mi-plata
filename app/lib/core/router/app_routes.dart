class AppRoutes {
  const AppRoutes._();

  static const dashboard = '/';
  static const login = '/login';
  static const register = '/register';

  /// Rutas accesibles sin sesión.
  static const public = {login, register};
}
