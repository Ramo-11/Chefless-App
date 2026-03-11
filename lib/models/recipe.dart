import 'package:equatable/equatable.dart';

/// A single ingredient with a quantity, unit, and optional grouping.
class Ingredient extends Equatable {
  const Ingredient({
    required this.name,
    required this.quantity,
    required this.unit,
    this.group,
  });

  final String name;
  final double quantity;
  final String unit;
  final String? group;

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      name: json['name'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'] as String,
      group: json['group'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
      if (group != null) 'group': group,
    };
  }

  Ingredient copyWith({
    String? name,
    double? quantity,
    String? unit,
    String? group,
  }) {
    return Ingredient(
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      group: group ?? this.group,
    );
  }

  @override
  List<Object?> get props => [name, quantity, unit, group];
}

/// A numbered step in a recipe with an instruction and optional photo.
class RecipeStep extends Equatable {
  const RecipeStep({
    required this.order,
    required this.instruction,
    this.photo,
  });

  final int order;
  final String instruction;
  final String? photo;

  factory RecipeStep.fromJson(Map<String, dynamic> json) {
    return RecipeStep(
      order: json['order'] as int,
      instruction: json['instruction'] as String,
      photo: json['photo'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'order': order,
      'instruction': instruction,
      if (photo != null) 'photo': photo,
    };
  }

  RecipeStep copyWith({
    int? order,
    String? instruction,
    String? photo,
  }) {
    return RecipeStep(
      order: order ?? this.order,
      instruction: instruction ?? this.instruction,
      photo: photo ?? this.photo,
    );
  }

  @override
  List<Object?> get props => [order, instruction, photo];
}

/// Tracks where a forked recipe originally came from.
class ForkSource extends Equatable {
  const ForkSource({
    required this.recipeId,
    required this.authorId,
    required this.authorName,
  });

  final String recipeId;
  final String authorId;
  final String authorName;

  factory ForkSource.fromJson(Map<String, dynamic> json) {
    return ForkSource(
      recipeId: json['recipeId'] as String,
      authorId: json['authorId'] as String,
      authorName: json['authorName'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'recipeId': recipeId,
      'authorId': authorId,
      'authorName': authorName,
    };
  }

  @override
  List<Object?> get props => [recipeId, authorId, authorName];
}

/// A full recipe as returned by the API.
class Recipe extends Equatable {
  const Recipe({
    required this.id,
    required this.authorId,
    required this.title,
    this.description,
    this.story,
    required this.photos,
    required this.showSignature,
    required this.labels,
    required this.dietaryTags,
    required this.cuisineTags,
    this.difficulty,
    required this.ingredients,
    required this.steps,
    this.prepTime,
    this.cookTime,
    this.totalTime,
    this.servings,
    this.calories,
    this.costEstimate,
    required this.baseServings,
    this.forkedFrom,
    required this.isModifiedFork,
    required this.isPrivate,
    required this.likesCount,
    required this.forksCount,
    this.authorName,
    this.authorPhoto,
    this.isLiked,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String authorId;
  final String title;
  final String? description;
  final String? story;
  final List<String> photos;
  final bool showSignature;
  final List<String> labels;
  final List<String> dietaryTags;
  final List<String> cuisineTags;
  final String? difficulty;
  final List<Ingredient> ingredients;
  final List<RecipeStep> steps;
  final int? prepTime;
  final int? cookTime;
  final int? totalTime;
  final int? servings;
  final int? calories;
  final String? costEstimate;
  final int baseServings;
  final ForkSource? forkedFrom;
  final bool isModifiedFork;
  final bool isPrivate;
  final int likesCount;
  final int forksCount;
  final String? authorName;
  final String? authorPhoto;

  /// Whether the current user has liked this recipe. `null` if unknown.
  final bool? isLiked;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['_id'] as String,
      authorId: json['authorId'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      story: json['story'] as String?,
      photos:
          (json['photos'] as List<dynamic>?)?.cast<String>() ?? const [],
      showSignature: json['showSignature'] as bool? ?? false,
      labels:
          (json['labels'] as List<dynamic>?)?.cast<String>() ?? const [],
      dietaryTags:
          (json['dietaryTags'] as List<dynamic>?)?.cast<String>() ?? const [],
      cuisineTags:
          (json['cuisineTags'] as List<dynamic>?)?.cast<String>() ?? const [],
      difficulty: json['difficulty'] as String?,
      ingredients: (json['ingredients'] as List<dynamic>?)
              ?.map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      steps: (json['steps'] as List<dynamic>?)
              ?.map((e) => RecipeStep.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      prepTime: json['prepTime'] as int?,
      cookTime: json['cookTime'] as int?,
      totalTime: json['totalTime'] as int?,
      servings: json['servings'] as int?,
      calories: json['calories'] as int?,
      costEstimate: json['costEstimate'] as String?,
      baseServings: json['baseServings'] as int? ?? 1,
      forkedFrom: json['forkedFrom'] != null
          ? ForkSource.fromJson(json['forkedFrom'] as Map<String, dynamic>)
          : null,
      isModifiedFork: json['isModifiedFork'] as bool? ?? false,
      isPrivate: json['isPrivate'] as bool? ?? false,
      likesCount: json['likesCount'] as int? ?? 0,
      forksCount: json['forksCount'] as int? ?? 0,
      authorName: json['authorName'] as String?,
      authorPhoto: json['authorPhoto'] as String?,
      isLiked: json['isLiked'] as bool?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'authorId': authorId,
      'title': title,
      'description': description,
      'story': story,
      'photos': photos,
      'showSignature': showSignature,
      'labels': labels,
      'dietaryTags': dietaryTags,
      'cuisineTags': cuisineTags,
      'difficulty': difficulty,
      'ingredients': ingredients.map((e) => e.toJson()).toList(),
      'steps': steps.map((e) => e.toJson()).toList(),
      'prepTime': prepTime,
      'cookTime': cookTime,
      'totalTime': totalTime,
      'servings': servings,
      'calories': calories,
      'costEstimate': costEstimate,
      'baseServings': baseServings,
      'forkedFrom': forkedFrom?.toJson(),
      'isModifiedFork': isModifiedFork,
      'isPrivate': isPrivate,
      'likesCount': likesCount,
      'forksCount': forksCount,
      'authorName': authorName,
      'authorPhoto': authorPhoto,
      'isLiked': isLiked,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Recipe copyWith({
    String? id,
    String? authorId,
    String? title,
    String? description,
    String? story,
    List<String>? photos,
    bool? showSignature,
    List<String>? labels,
    List<String>? dietaryTags,
    List<String>? cuisineTags,
    String? difficulty,
    List<Ingredient>? ingredients,
    List<RecipeStep>? steps,
    int? prepTime,
    int? cookTime,
    int? totalTime,
    int? servings,
    int? calories,
    String? costEstimate,
    int? baseServings,
    ForkSource? forkedFrom,
    bool? isModifiedFork,
    bool? isPrivate,
    int? likesCount,
    int? forksCount,
    String? authorName,
    String? authorPhoto,
    bool? isLiked,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Recipe(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      title: title ?? this.title,
      description: description ?? this.description,
      story: story ?? this.story,
      photos: photos ?? this.photos,
      showSignature: showSignature ?? this.showSignature,
      labels: labels ?? this.labels,
      dietaryTags: dietaryTags ?? this.dietaryTags,
      cuisineTags: cuisineTags ?? this.cuisineTags,
      difficulty: difficulty ?? this.difficulty,
      ingredients: ingredients ?? this.ingredients,
      steps: steps ?? this.steps,
      prepTime: prepTime ?? this.prepTime,
      cookTime: cookTime ?? this.cookTime,
      totalTime: totalTime ?? this.totalTime,
      servings: servings ?? this.servings,
      calories: calories ?? this.calories,
      costEstimate: costEstimate ?? this.costEstimate,
      baseServings: baseServings ?? this.baseServings,
      forkedFrom: forkedFrom ?? this.forkedFrom,
      isModifiedFork: isModifiedFork ?? this.isModifiedFork,
      isPrivate: isPrivate ?? this.isPrivate,
      likesCount: likesCount ?? this.likesCount,
      forksCount: forksCount ?? this.forksCount,
      authorName: authorName ?? this.authorName,
      authorPhoto: authorPhoto ?? this.authorPhoto,
      isLiked: isLiked ?? this.isLiked,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        authorId,
        title,
        description,
        story,
        photos,
        showSignature,
        labels,
        dietaryTags,
        cuisineTags,
        difficulty,
        ingredients,
        steps,
        prepTime,
        cookTime,
        totalTime,
        servings,
        calories,
        costEstimate,
        baseServings,
        forkedFrom,
        isModifiedFork,
        isPrivate,
        likesCount,
        forksCount,
        authorName,
        authorPhoto,
        isLiked,
        createdAt,
        updatedAt,
      ];
}
