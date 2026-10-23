import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider).auth),
);

final authControllerProvider =
    AsyncNotifierProvider.autoDispose<AuthController, void>(
      AuthController.new,
    );

enum SignUpOutcome { signedIn, confirmationRequired, failed }

/// Estado de las operaciones de acceso: cargando, con error o en reposo.
/// Al abrirse la sesión, el router redirige solo; aquí no se navega.
class AuthController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => _repository.signIn(email: email, password: password),
    );
    if (ref.mounted) state = result;
  }

  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
    required String language,
  }) async {
    state = const AsyncLoading();
    var confirmationRequired = false;
    final result = await AsyncValue.guard(() async {
      confirmationRequired = await _repository.signUp(
        email: email,
        password: password,
        language: language,
      );
    });
    if (ref.mounted) state = result;

    if (result.hasError) return SignUpOutcome.failed;
    return confirmationRequired
        ? SignUpOutcome.confirmationRequired
        : SignUpOutcome.signedIn;
  }
}
