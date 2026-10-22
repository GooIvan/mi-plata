import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../data/category_repository.dart';
import '../domain/category.dart';
import '../domain/category_type.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => CategoryRepository(ref.watch(supabaseClientProvider)),
);

final categoriesProvider =
    AsyncNotifierProvider.autoDispose<CategoriesNotifier, List<Category>>(
      CategoriesNotifier.new,
    );

/// Todas las categorías (activas y archivadas). Las operaciones lanzan el
/// error si fallan, para que quien las llama pueda avisar al usuario.
class CategoriesNotifier extends AsyncNotifier<List<Category>> {
  CategoryRepository get _repository => ref.read(categoryRepositoryProvider);

  @override
  Future<List<Category>> build() => _repository.fetchAll();

  Future<void> create({required String name, required CategoryType type}) async {
    await _repository.create(name: name, type: type);
    ref.invalidateSelf();
  }

  Future<void> rename(String id, String name) async {
    await _repository.rename(id, name);
    ref.invalidateSelf();
  }

  Future<void> setArchived(String id, {required bool isArchived}) async {
    await _repository.setArchived(id, isArchived: isArchived);
    ref.invalidateSelf();
  }
}
