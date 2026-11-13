import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/profile_data.dart';

/// Acceso al perfil del usuario en Supabase. El `user_id` lo pone la base de
/// datos, y el RLS deja ver solo el propio.
class ProfileRepository {
  const ProfileRepository(this._client);

  final SupabaseClient _client;

  /// El perfil del usuario; null si no tiene fila (los usuarios que se
  /// registraron antes de que existiera el perfil).
  Future<ProfileData?> fetch() async {
    final row = await _client.from('profiles').select().maybeSingle();
    return row == null ? null : ProfileData.fromJson(row);
  }
}
