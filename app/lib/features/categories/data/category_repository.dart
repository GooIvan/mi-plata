import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/category.dart';

class CategoryRepository {
  const CategoryRepository(this._client);

  final SupabaseClient _client;

  /// Las categorías activas del usuario, ordenadas por nombre.
  Future<List<Category>> fetchActive() async {
    final rows = await _client
        .from('categories')
        .select()
        .eq('is_archived', false)
        .order('name');
    return rows.map(Category.fromJson).toList();
  }
}
