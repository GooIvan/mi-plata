import 'category_type.dart';

class Category {
  const Category({required this.id, required this.name, required this.type});

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: json['id'] as String,
    name: json['name'] as String,
    type: CategoryType.fromDb(json['type'] as String),
  );

  final String id;
  final String name;
  final CategoryType type;
}
