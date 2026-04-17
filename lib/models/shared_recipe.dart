import 'package:equatable/equatable.dart';

/// A recipe that was shared with the current user by another user.
class SharedRecipe extends Equatable {
  const SharedRecipe({
    required this.shareId,
    required this.recipeId,
    required this.recipeTitle,
    this.recipePhoto,
    required this.recipeAuthorId,
    this.recipeAuthorName,
    required this.senderId,
    this.senderName,
    this.senderPhoto,
    this.message,
    required this.sharedAt,
  });

  final String shareId;
  final String recipeId;
  final String recipeTitle;
  final String? recipePhoto;
  final String recipeAuthorId;
  final String? recipeAuthorName;
  final String senderId;
  final String? senderName;
  final String? senderPhoto;
  final String? message;
  final DateTime sharedAt;

  factory SharedRecipe.fromJson(Map<String, dynamic> json) {
    return SharedRecipe(
      shareId: json['shareId'] as String,
      recipeId: json['recipeId'] as String,
      recipeTitle: json['recipeTitle'] as String? ?? '',
      recipePhoto: json['recipePhoto'] as String?,
      recipeAuthorId: json['recipeAuthorId'] as String,
      recipeAuthorName: json['recipeAuthorName'] as String?,
      senderId: json['senderId'] as String,
      senderName: json['senderName'] as String?,
      senderPhoto: json['senderPhoto'] as String?,
      message: json['message'] as String?,
      sharedAt: DateTime.tryParse(json['sharedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        shareId,
        recipeId,
        recipeTitle,
        recipePhoto,
        recipeAuthorId,
        recipeAuthorName,
        senderId,
        senderName,
        senderPhoto,
        message,
        sharedAt,
      ];
}
