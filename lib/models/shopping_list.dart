import 'package:equatable/equatable.dart';

/// A single item in a shopping list.
class ShoppingItem extends Equatable {
  const ShoppingItem({
    required this.id,
    required this.name,
    this.quantity,
    this.unit,
    this.recipeId,
    required this.isChecked,
    this.addedBy,
    this.category,
    this.notes,
    this.imageUrl,
  });

  final String id;
  final String name;
  final double? quantity;
  final String? unit;
  final String? recipeId;
  final bool isChecked;
  final String? addedBy;
  final String? category;
  final String? notes;
  final String? imageUrl;

  factory ShoppingItem.fromJson(Map<String, dynamic> json) {
    return ShoppingItem(
      id: json['_id'] as String? ?? json['id'] as String,
      name: json['name'] as String,
      quantity: (json['quantity'] as num?)?.toDouble(),
      unit: json['unit'] as String?,
      recipeId: json['recipeId'] as String?,
      isChecked: json['isChecked'] as bool? ?? false,
      addedBy: json['addedBy'] as String?,
      category: json['category'] as String?,
      notes: json['notes'] as String?,
      imageUrl: json['imageUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      if (quantity != null) 'quantity': quantity,
      if (unit != null) 'unit': unit,
      if (recipeId != null) 'recipeId': recipeId,
      'isChecked': isChecked,
      if (addedBy != null) 'addedBy': addedBy,
      if (category != null) 'category': category,
      if (notes != null) 'notes': notes,
      if (imageUrl != null) 'imageUrl': imageUrl,
    };
  }

  ShoppingItem copyWith({
    String? id,
    String? name,
    double? quantity,
    String? unit,
    String? recipeId,
    bool? isChecked,
    String? addedBy,
    String? category,
    String? notes,
    String? imageUrl,
  }) {
    return ShoppingItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      recipeId: recipeId ?? this.recipeId,
      isChecked: isChecked ?? this.isChecked,
      addedBy: addedBy ?? this.addedBy,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        quantity,
        unit,
        recipeId,
        isChecked,
        addedBy,
        category,
        notes,
        imageUrl,
      ];
}

/// A shopping list belonging to a user or kitchen.
class ShoppingList extends Equatable {
  const ShoppingList({
    required this.id,
    this.kitchenId,
    this.userId,
    this.name,
    required this.items,
    required this.generatedFromSchedule,
    this.scheduleStartDate,
    this.scheduleEndDate,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? kitchenId;
  final String? userId;
  final String? name;
  final List<ShoppingItem> items;
  final bool generatedFromSchedule;
  final DateTime? scheduleStartDate;
  final DateTime? scheduleEndDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Whether this list is shared with the kitchen (vs personal/private).
  bool get isShared => kitchenId != null;

  /// Number of items that have been checked off.
  int get checkedCount => items.where((i) => i.isChecked).length;

  /// Total number of items in the list.
  int get totalCount => items.length;

  /// Unique category values from all items, sorted alphabetically.
  List<String> get categories {
    final cats = <String>{};
    for (final item in items) {
      if (item.category != null && item.category!.isNotEmpty) {
        cats.add(item.category!);
      }
    }
    final sorted = cats.toList()..sort();
    return sorted;
  }

  factory ShoppingList.fromJson(Map<String, dynamic> json) {
    return ShoppingList(
      id: json['_id'] as String,
      kitchenId: json['kitchenId'] as String?,
      userId: json['userId'] as String?,
      name: json['name'] as String?,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => ShoppingItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      generatedFromSchedule:
          json['generatedFromSchedule'] as bool? ?? false,
      scheduleStartDate: json['scheduleStartDate'] != null
          ? DateTime.parse(json['scheduleStartDate'] as String)
          : null,
      scheduleEndDate: json['scheduleEndDate'] != null
          ? DateTime.parse(json['scheduleEndDate'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'kitchenId': kitchenId,
      'userId': userId,
      'name': name,
      'items': items.map((e) => e.toJson()).toList(),
      'generatedFromSchedule': generatedFromSchedule,
      if (scheduleStartDate != null)
        'scheduleStartDate': scheduleStartDate!.toIso8601String(),
      if (scheduleEndDate != null)
        'scheduleEndDate': scheduleEndDate!.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  ShoppingList copyWith({
    String? id,
    String? kitchenId,
    String? userId,
    String? name,
    List<ShoppingItem>? items,
    bool? generatedFromSchedule,
    DateTime? scheduleStartDate,
    DateTime? scheduleEndDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ShoppingList(
      id: id ?? this.id,
      kitchenId: kitchenId ?? this.kitchenId,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      items: items ?? this.items,
      generatedFromSchedule:
          generatedFromSchedule ?? this.generatedFromSchedule,
      scheduleStartDate: scheduleStartDate ?? this.scheduleStartDate,
      scheduleEndDate: scheduleEndDate ?? this.scheduleEndDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        kitchenId,
        userId,
        name,
        items,
        generatedFromSchedule,
        scheduleStartDate,
        scheduleEndDate,
        createdAt,
        updatedAt,
      ];
}
