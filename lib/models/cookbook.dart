import 'package:equatable/equatable.dart';

import '../utils/json_helpers.dart';

/// A user-owned collection of recipes — a folder, where each recipe is a file.
class Cookbook extends Equatable {
  const Cookbook({
    required this.id,
    required this.ownerId,
    required this.name,
    this.description,
    this.coverPhoto,
    required this.recipeIds,
    required this.isPrivate,
    required this.recipesCount,
    this.ownerName,
    this.ownerPhoto,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String ownerId;
  final String name;
  final String? description;
  final String? coverPhoto;
  final List<String> recipeIds;
  final bool isPrivate;
  final int recipesCount;
  final String? ownerName;
  final String? ownerPhoto;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Cookbook.fromJson(Map<String, dynamic> json) {
    return Cookbook(
      id: asId(json['_id']),
      ownerId: asId(json['ownerId']),
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      coverPhoto: json['coverPhoto'] as String?,
      recipeIds: (json['recipeIds'] as List<dynamic>?)
              ?.map((e) => asId(e))
              .where((id) => id.isNotEmpty)
              .toList() ??
          const [],
      isPrivate: json['isPrivate'] as bool? ?? false,
      recipesCount: json['recipesCount'] as int? ??
          ((json['recipeIds'] as List<dynamic>?)?.length ?? 0),
      ownerName: json['ownerName'] as String?,
      ownerPhoto: json['ownerPhoto'] as String?,
      createdAt: asDateTime(json['createdAt'], fallback: DateTime.now()),
      updatedAt: asDateTime(json['updatedAt'], fallback: DateTime.now()),
    );
  }

  Cookbook copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? description,
    String? coverPhoto,
    List<String>? recipeIds,
    bool? isPrivate,
    int? recipesCount,
    String? ownerName,
    String? ownerPhoto,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Cookbook(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      description: description ?? this.description,
      coverPhoto: coverPhoto ?? this.coverPhoto,
      recipeIds: recipeIds ?? this.recipeIds,
      isPrivate: isPrivate ?? this.isPrivate,
      recipesCount: recipesCount ?? this.recipesCount,
      ownerName: ownerName ?? this.ownerName,
      ownerPhoto: ownerPhoto ?? this.ownerPhoto,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        ownerId,
        name,
        description,
        coverPhoto,
        recipeIds,
        isPrivate,
        recipesCount,
        ownerName,
        ownerPhoto,
        createdAt,
        updatedAt,
      ];
}
