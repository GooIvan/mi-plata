import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../domain/category.dart';
import '../category_type_ui.dart';

enum CategoryMenuAction { edit, toggleArchived }

class CategoryTile extends StatelessWidget {
  const CategoryTile({
    super.key,
    required this.category,
    required this.onEdit,
    required this.onToggleArchived,
  });

  final Category category;
  final VoidCallback onEdit;
  final VoidCallback onToggleArchived;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Opacity(
      opacity: category.isArchived ? 0.6 : 1,
      child: ListTile(
        leading: CircleAvatar(child: Icon(category.type.icon)),
        title: Text(category.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: category.isArchived ? Text(l10n.commonArchivedTag) : null,
        trailing: PopupMenuButton<CategoryMenuAction>(
          tooltip: l10n.commonOptions,
          onSelected: (action) => switch (action) {
            CategoryMenuAction.edit => onEdit(),
            CategoryMenuAction.toggleArchived => onToggleArchived(),
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: CategoryMenuAction.edit,
              child: Text(l10n.commonEdit),
            ),
            PopupMenuItem(
              value: CategoryMenuAction.toggleArchived,
              child: Text(
                category.isArchived ? l10n.commonRestore : l10n.commonArchive,
              ),
            ),
          ],
        ),
        onTap: onEdit,
      ),
    );
  }
}
