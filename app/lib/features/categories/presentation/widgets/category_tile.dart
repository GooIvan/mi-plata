import 'package:flutter/material.dart';

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
    return Opacity(
      opacity: category.isArchived ? 0.6 : 1,
      child: ListTile(
        leading: CircleAvatar(child: Icon(category.type.icon)),
        title: Text(category.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: category.isArchived ? const Text('Archivada') : null,
        trailing: PopupMenuButton<CategoryMenuAction>(
          tooltip: 'Opciones',
          onSelected: (action) => switch (action) {
            CategoryMenuAction.edit => onEdit(),
            CategoryMenuAction.toggleArchived => onToggleArchived(),
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: CategoryMenuAction.edit,
              child: Text('Editar'),
            ),
            PopupMenuItem(
              value: CategoryMenuAction.toggleArchived,
              child: Text(category.isArchived ? 'Restaurar' : 'Archivar'),
            ),
          ],
        ),
        onTap: onEdit,
      ),
    );
  }
}
