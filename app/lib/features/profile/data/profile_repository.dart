import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/format/date_format.dart';

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

  /// Guarda el perfil: lo crea si el usuario no tenía (los que se registraron
  /// antes de que existiera) o lo reemplaza. Los datos que van vacíos se borran.
  Future<void> save(ProfileData profile) async {
    await _client.from('profiles').upsert({
      'first_name': profile.firstName?.trim(),
      'last_name': profile.lastName?.trim(),
      'birth_date': profile.birthDate == null ? null : toDbDate(profile.birthDate!),
      'profession': profile.profession?.trim().isEmpty ?? true
          ? null
          : profile.profession!.trim(),
      'monthly_income': profile.monthlyIncome,
      'monthly_income_currency': profile.monthlyIncome == null
          ? null
          : (profile.monthlyIncomeCurrency ?? 'COP'),
    }, onConflict: 'user_id');
  }

  /// Borra la cuenta del usuario y todo lo suyo. No se puede deshacer.
  Future<void> deleteAccount() async {
    await _client.rpc<dynamic>('delete_my_account');
  }
}
