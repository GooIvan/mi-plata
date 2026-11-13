import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../data/profile_repository.dart';
import '../domain/profile_data.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(supabaseClientProvider)),
);

/// El perfil del usuario; null si todavía no tiene (los que se registraron antes
/// de que existiera). Las operaciones lanzan el error si fallan, para que el
/// formulario pueda avisar.
final profileProvider =
    AsyncNotifierProvider.autoDispose<ProfileNotifier, ProfileData?>(
      ProfileNotifier.new,
    );

class ProfileNotifier extends AsyncNotifier<ProfileData?> {
  ProfileRepository get _repository => ref.read(profileRepositoryProvider);

  @override
  Future<ProfileData?> build() => _repository.fetch();

  Future<void> save(ProfileData profile) async {
    await _repository.save(profile);
    ref.invalidateSelf();
  }
}
