import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/category.dart';
import '../domain/category_type.dart';

/// Acceso a las categorías en Supabase. El `user_id` lo pone la base de datos.
class CategoryRepository {
  const CategoryRepository(this._client);

  final SupabaseClient _client;

  /// Todas las categorías, activas y archivadas, ordenadas por nombre.
  ///
  /// Las archivadas se traen porque los movimientos viejos que las usan
  /// deben seguir mostrando su nombre.
  Future<List<Category>> fetchAll() async {
    final rows = await _client.from('categories').select().order('name');
    return rows.map(Category.fromJson).toList();
  }

  Future<void> create({required String name, required CategoryType type}) async {
    await _client.from('categories').insert({
      'name': name,
      'type': type.dbValue,
    });
  }

  Future<void> rename(String id, String name) async {
    await _client.from('categories').update({'name': name}).eq('id', id);
  }

  Future<void> setArchived(String id, {required bool isArchived}) async {
    await _client
        .from('categories')
        .update({'is_archived': isArchived})
        .eq('id', id);
  }
}
