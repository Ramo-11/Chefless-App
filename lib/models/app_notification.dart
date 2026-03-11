import 'package:equatable/equatable.dart';

/// Represents an in-app notification from the Chefless API.
///
/// Named `AppNotification` to avoid conflict with Flutter's built-in
/// [Notification] class.
class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    this.actorId,
    this.actorName,
    this.actorPhoto,
    this.recipeId,
    this.recipeTitle,
    this.kitchenId,
    this.scheduleEntryId,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String type;
  final String? actorId;
  final String? actorName;
  final String? actorPhoto;
  final String? recipeId;
  final String? recipeTitle;
  final String? kitchenId;
  final String? scheduleEntryId;
  final bool isRead;
  final DateTime createdAt;

  /// Human-readable message based on the notification [type].
  String get displayMessage {
    final actor = actorName ?? 'Someone';
    final recipe = recipeTitle ?? 'a recipe';

    switch (type) {
      case 'new_follower':
        return '$actor started following you.';
      case 'follow_request':
        return '$actor sent you a follow request.';
      case 'follow_accepted':
        return '$actor accepted your follow request.';
      case 'recipe_liked':
        return '$actor liked your recipe "$recipe".';
      case 'recipe_forked':
        return '$actor forked your recipe "$recipe".';
      case 'recipe_shared':
        return '$actor shared a recipe with you: "$recipe".';
      case 'schedule_suggestion':
        return '$actor suggested "$recipe" for the schedule.';
      case 'suggestion_approved':
        return 'Your suggestion "$recipe" was approved.';
      case 'suggestion_denied':
        return 'Your suggestion "$recipe" was denied.';
      case 'kitchen_joined':
        return '$actor joined the kitchen.';
      case 'kitchen_removed':
        return 'You were removed from the kitchen.';
      default:
        return 'You have a new notification.';
    }
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['_id'] as String,
      userId: json['userId'] as String,
      type: json['type'] as String,
      actorId: json['actorId'] as String?,
      actorName: json['actorName'] as String?,
      actorPhoto: json['actorPhoto'] as String?,
      recipeId: json['recipeId'] as String?,
      recipeTitle: json['recipeTitle'] as String?,
      kitchenId: json['kitchenId'] as String?,
      scheduleEntryId: json['scheduleEntryId'] as String?,
      isRead: json['isRead'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'userId': userId,
      'type': type,
      'actorId': actorId,
      'actorName': actorName,
      'actorPhoto': actorPhoto,
      'recipeId': recipeId,
      'recipeTitle': recipeTitle,
      'kitchenId': kitchenId,
      'scheduleEntryId': scheduleEntryId,
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  AppNotification copyWith({
    String? id,
    String? userId,
    String? type,
    String? actorId,
    String? actorName,
    String? actorPhoto,
    String? recipeId,
    String? recipeTitle,
    String? kitchenId,
    String? scheduleEntryId,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      actorId: actorId ?? this.actorId,
      actorName: actorName ?? this.actorName,
      actorPhoto: actorPhoto ?? this.actorPhoto,
      recipeId: recipeId ?? this.recipeId,
      recipeTitle: recipeTitle ?? this.recipeTitle,
      kitchenId: kitchenId ?? this.kitchenId,
      scheduleEntryId: scheduleEntryId ?? this.scheduleEntryId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        type,
        actorId,
        actorName,
        actorPhoto,
        recipeId,
        recipeTitle,
        kitchenId,
        scheduleEntryId,
        isRead,
        createdAt,
      ];
}
