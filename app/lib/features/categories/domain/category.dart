import 'category_type.dart';

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.type,
    required this.isArchived,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: json['id'] as String,
    name: json['name'] as String,
    type: CategoryType.fromDb(json['type'] as String),
    isArchived: json['is_archived'] as bool,
  );

  final String id;
  final String name;
  final CategoryType type;
  final bool isArchived;
}
