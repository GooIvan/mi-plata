import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../data/category_repository.dart';
import '../domain/category.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => CategoryRepository(ref.watch(supabaseClientProvider)),
);

final categoriesProvider = FutureProvider.autoDispose<List<Category>>(
  (ref) => ref.watch(categoryRepositoryProvider).fetchActive(),
);
