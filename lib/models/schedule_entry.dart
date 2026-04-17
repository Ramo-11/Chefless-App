import 'package:equatable/equatable.dart';

/// A single meal slot in a schedule (kitchen or personal).
class ScheduleEntry extends Equatable {
  const ScheduleEntry({
    required this.id,
    this.kitchenId,
    this.userId,
    required this.date,
    required this.mealSlot,
    this.recipeId,
    this.recipeTitle,
    this.recipePhoto,
    this.recipeAuthorId,
    this.recipeAuthorName,
    this.freeformText,
    this.scheduledTime,
    this.prepTime,
    required this.status,
    this.suggestedBy,
    this.confirmedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? kitchenId;
  final String? userId;
  final DateTime date;
  final String mealSlot;
  final String? recipeId;
  final String? recipeTitle;
  final String? recipePhoto;
  final String? recipeAuthorId;
  final String? recipeAuthorName;
  final String? freeformText;
  final String? scheduledTime; // HH:mm format, optional
  final int? prepTime; // minutes, optional
  final String status;
  final String? suggestedBy;
  final String? confirmedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Whether this entry references a recipe (vs freeform text).
  bool get isRecipe => recipeId != null;

  /// Display label: recipe title or freeform text.
  String get displayLabel =>
      recipeTitle ?? freeformText ?? 'Untitled';

  /// Whether this is a personal entry (not tied to a kitchen).
  bool get isPersonal => kitchenId == null;

  factory ScheduleEntry.fromJson(Map<String, dynamic> json) {
    return ScheduleEntry(
      id: json['_id'] as String,
      kitchenId: json['kitchenId'] as String?,
      userId: json['userId'] as String?,
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      mealSlot: json['mealSlot'] as String,
      recipeId: json['recipeId'] as String?,
      recipeTitle: json['recipeTitle'] as String?,
      recipePhoto: json['recipePhoto'] as String?,
      recipeAuthorId: json['recipeAuthorId'] as String?,
      recipeAuthorName: json['recipeAuthorName'] as String?,
      freeformText: json['freeformText'] as String?,
      scheduledTime: json['scheduledTime'] as String?,
      prepTime: (json['prepTime'] as num?)?.toInt(),
      status: json['status'] as String? ?? 'confirmed',
      suggestedBy: json['suggestedBy'] as String?,
      confirmedBy: json['confirmedBy'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      if (kitchenId != null) 'kitchenId': kitchenId,
      if (userId != null) 'userId': userId,
      'date': date.toIso8601String(),
      'mealSlot': mealSlot,
      'recipeId': recipeId,
      'recipeTitle': recipeTitle,
      'recipePhoto': recipePhoto,
      'recipeAuthorId': recipeAuthorId,
      'recipeAuthorName': recipeAuthorName,
      'freeformText': freeformText,
      if (scheduledTime != null) 'scheduledTime': scheduledTime,
      if (prepTime != null) 'prepTime': prepTime,
      'status': status,
      'suggestedBy': suggestedBy,
      'confirmedBy': confirmedBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  ScheduleEntry copyWith({
    String? id,
    String? kitchenId,
    String? userId,
    DateTime? date,
    String? mealSlot,
    String? recipeId,
    String? recipeTitle,
    String? recipePhoto,
    String? recipeAuthorId,
    String? recipeAuthorName,
    String? freeformText,
    String? scheduledTime,
    int? prepTime,
    String? status,
    String? suggestedBy,
    String? confirmedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ScheduleEntry(
      id: id ?? this.id,
      kitchenId: kitchenId ?? this.kitchenId,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      mealSlot: mealSlot ?? this.mealSlot,
      recipeId: recipeId ?? this.recipeId,
      recipeTitle: recipeTitle ?? this.recipeTitle,
      recipePhoto: recipePhoto ?? this.recipePhoto,
      recipeAuthorId: recipeAuthorId ?? this.recipeAuthorId,
      recipeAuthorName: recipeAuthorName ?? this.recipeAuthorName,
      freeformText: freeformText ?? this.freeformText,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      prepTime: prepTime ?? this.prepTime,
      status: status ?? this.status,
      suggestedBy: suggestedBy ?? this.suggestedBy,
      confirmedBy: confirmedBy ?? this.confirmedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        kitchenId,
        userId,
        date,
        mealSlot,
        recipeId,
        recipeTitle,
        recipePhoto,
        recipeAuthorId,
        recipeAuthorName,
        freeformText,
        scheduledTime,
        prepTime,
        status,
        suggestedBy,
        confirmedBy,
        createdAt,
        updatedAt,
      ];
}
