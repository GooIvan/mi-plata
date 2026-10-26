import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/state_message.dart';
import '../../../l10n/l10n.dart';
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
    final l10n = context.l10n;

    try {
      await ref
          .read(categoriesProvider.notifier)
          .setArchived(category.id, isArchived: archived);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(categoryErrorMessage(l10n, error))),
      );
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          archived
              ? l10n.categoriesArchivedMessage
              : l10n.categoriesRestoredMessage,
        ),
        action: SnackBarAction(
          label: l10n.commonUndo,
          onPressed: () => _setArchived(category, archived: !archived),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.categoriesTitle),
        actions: [
          IconButton(
            tooltip: _showArchived
                ? l10n.commonHideArchived
                : l10n.commonShowArchived,
            icon: Icon(
              _showArchived ? Icons.inventory_2 : Icons.inventory_2_outlined,
            ),
            onPressed: () => setState(() => _showArchived = !_showArchived),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: l10n.commonExpenses),
            Tab(text: l10n.commonIncomes),
          ],
        ),
      ),
      body: categories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => StateMessage(
          icon: Icons.cloud_off_outlined,
          text: categoryErrorMessage(l10n, error),
          actionLabel: l10n.commonRetry,
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
        label: Text(l10n.categoriesNew),
      ),
    );
  }

  Widget _buildList(List<Category> all, CategoryType type) {
    final l10n = context.l10n;
    final ofType = all.where((category) => category.type == type).toList();

    if (ofType.isEmpty) {
      return StateMessage(
        icon: type.icon,
        text: l10n.categoriesEmptyOfType(type.name),
        actionLabel: l10n.categoriesCreateButton,
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
        text: l10n.categoriesAllArchivedOfType(type.name),
        actionLabel: l10n.commonShowArchived,
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
