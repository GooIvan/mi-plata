import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/error_banner.dart';
import '../../domain/category.dart';
import '../../domain/category_type.dart';
import '../../domain/category_validators.dart';
import '../categories_providers.dart';
import '../category_error_message.dart';
import '../category_type_ui.dart';

/// Abre el formulario para crear una categoría de [type], o para renombrar
/// [category] (el tipo de una categoría existente no se puede cambiar).
Future<void> showCategoryForm(
  BuildContext context, {
  Category? category,
  CategoryType? type,
}) {
  assert(category != null || type != null, 'Hace falta una categoría o un tipo');
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => CategoryFormSheet(category: category, type: type),
  );
}

class CategoryFormSheet extends ConsumerStatefulWidget {
  const CategoryFormSheet({super.key, this.category, this.type});

  final Category? category;
  final CategoryType? type;

  @override
  ConsumerState<CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends ConsumerState<CategoryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.category?.name);
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.category != null;
  CategoryType get _type => widget.category?.type ?? widget.type!;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final categories = ref.read(categoriesProvider.notifier);
    final name = _name.text.trim();

    try {
      if (_isEditing) {
        await categories.rename(widget.category!.id, name);
      } else {
        await categories.create(name: name, type: _type);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = categoryErrorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isEditing
                  ? 'Editar categoría de ${_type.label}'
                  : 'Nueva categoría de ${_type.label}',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _name,
              enabled: !_saving,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              validator: CategoryValidators.name,
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Nombre',
                hintText: 'Ej: Mascotas',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              ErrorBanner(_error!),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEditing ? 'Guardar' : 'Crear categoría'),
            ),
          ],
        ),
      ),
    );
  }
}
