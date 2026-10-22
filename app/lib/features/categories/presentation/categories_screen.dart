import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/state_message.dart';
import '../domain/category.dart';
import '../domain/category_type.dart';
import 'categories_providers.dart';
import 'category_error_message.dart';
import 'category_type_ui.dart';
import 'widgets/category_form_sheet.dart';
import 'widgets/category_tile.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen>
    with SingleTickerProviderStateMixin {
  /// El orden de las pestañas: Gastos primero, porque es lo que más se usa.
  static const _types = [CategoryType.expense, CategoryType.income];

  late final _tabs = TabController(length: _types.length, vsync: this);
  bool _showArchived = false;

  CategoryType get _currentType => _types[_tabs.index];

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _setArchived(Category category, {required bool archived}) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref
          .read(categoriesProvider.notifier)
          .setArchived(category.id, isArchived: archived);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(categoryErrorMessage(error))));
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(archived ? 'Categoría archivada' : 'Categoría restaurada'),
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () => _setArchived(category, archived: !archived),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categorías'),
        actions: [
          IconButton(
            tooltip: _showArchived ? 'Ocultar archivadas' : 'Mostrar archivadas',
            icon: Icon(
              _showArchived ? Icons.inventory_2 : Icons.inventory_2_outlined,
            ),
            onPressed: () => setState(() => _showArchived = !_showArchived),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'Gastos'), Tab(text: 'Ingresos')],
        ),
      ),
      body: categories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => StateMessage(
          icon: Icons.cloud_off_outlined,
          text: categoryErrorMessage(error),
          actionLabel: 'Reintentar',
          onAction: () => ref.invalidate(categoriesProvider),
        ),
        data: (all) => TabBarView(
          controller: _tabs,
          children: [for (final type in _types) _buildList(all, type)],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCategoryForm(context, type: _currentType),
        icon: const Icon(Icons.add),
        label: const Text('Nueva categoría'),
      ),
    );
  }

  Widget _buildList(List<Category> all, CategoryType type) {
    final ofType = all.where((category) => category.type == type).toList();

    if (ofType.isEmpty) {
      return StateMessage(
        icon: type.icon,
        text: 'Aún no tienes categorías de ${type.label}.',
        actionLabel: 'Crear categoría',
        onAction: () => showCategoryForm(context, type: type),
      );
    }

    // Las activas primero; las archivadas, al final y solo si se piden.
    final visible = [
      ...ofType.where((category) => !category.isArchived),
      if (_showArchived) ...ofType.where((category) => category.isArchived),
    ];

    if (visible.isEmpty) {
      return StateMessage(
        icon: Icons.inventory_2_outlined,
        text: 'Todas tus categorías de ${type.label} están archivadas.',
        actionLabel: 'Mostrar archivadas',
        onAction: () => setState(() => _showArchived = true),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: visible.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final category = visible[index];
        return CategoryTile(
          category: category,
          onEdit: () => showCategoryForm(context, category: category),
          onToggleArchived: () =>
              _setArchived(category, archived: !category.isArchived),
        );
      },
    );
  }
}
