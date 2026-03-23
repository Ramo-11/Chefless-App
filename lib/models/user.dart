import 'package:equatable/equatable.dart';

import '../utils/json_helpers.dart';

/// Represents a Chefless user profile as returned by the API.
class CheflessUser extends Equatable {
  const CheflessUser({
    required this.id,
    required this.firebaseUid,
    required this.email,
    required this.fullName,
    this.phone,
    this.profilePicture,
    this.signature,
    this.bio,
    required this.isPublic,
    required this.followersCount,
    required this.followingCount,
    required this.recipesCount,
    this.kitchenId,
    required this.isPremium,
    this.premiumPlan,
    this.premiumExpiresAt,
    required this.dietaryPreferences,
    required this.cuisinePreferences,
    required this.onboardingComplete,
    required this.lastActiveAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String firebaseUid;
  final String email;
  final String fullName;
  final String? phone;
  final String? profilePicture;
  final String? signature;
  final String? bio;
  final bool isPublic;
  final int followersCount;
  final int followingCount;
  final int recipesCount;
  final String? kitchenId;
  final bool isPremium;
  final String? premiumPlan;
  final DateTime? premiumExpiresAt;
  final List<String> dietaryPreferences;
  final List<String> cuisinePreferences;
  final bool onboardingComplete;
  final DateTime lastActiveAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory CheflessUser.fromJson(Map<String, dynamic> json) {
    return CheflessUser(
      id: asId(json['_id']),
      firebaseUid: json['firebaseUid'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      phone: json['phone'] as String?,
      profilePicture: json['profilePicture'] as String?,
      signature: json['signature'] as String?,
      bio: json['bio'] as String?,
      isPublic: json['isPublic'] as bool? ?? true,
      followersCount: json['followersCount'] as int? ?? 0,
      followingCount: json['followingCount'] as int? ?? 0,
      recipesCount: json['recipesCount'] as int? ?? 0,
      kitchenId: asIdOrNull(json['kitchenId']),
      isPremium: json['isPremium'] as bool? ?? false,
      premiumPlan: json['premiumPlan'] as String?,
      premiumExpiresAt: json['premiumExpiresAt'] != null
          ? asDateTime(json['premiumExpiresAt'])
          : null,
      dietaryPreferences:
          (json['dietaryPreferences'] as List<dynamic>?)?.cast<String>() ??
              const [],
      cuisinePreferences:
          (json['cuisinePreferences'] as List<dynamic>?)?.cast<String>() ??
              const [],
      onboardingComplete: json['onboardingComplete'] as bool? ?? false,
      lastActiveAt: asDateTime(json['lastActiveAt'], fallback: DateTime.now()),
      createdAt: asDateTime(json['createdAt'], fallback: DateTime.now()),
      updatedAt: asDateTime(json['updatedAt'], fallback: DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'firebaseUid': firebaseUid,
      'email': email,
      'fullName': fullName,
      'phone': phone,
      'profilePicture': profilePicture,
      'signature': signature,
      'bio': bio,
      'isPublic': isPublic,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'recipesCount': recipesCount,
      'kitchenId': kitchenId,
      'isPremium': isPremium,
      'premiumPlan': premiumPlan,
      'premiumExpiresAt': premiumExpiresAt?.toIso8601String(),
      'dietaryPreferences': dietaryPreferences,
      'cuisinePreferences': cuisinePreferences,
      'onboardingComplete': onboardingComplete,
      'lastActiveAt': lastActiveAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  CheflessUser copyWith({
    String? id,
    String? firebaseUid,
    String? email,
    String? fullName,
    String? phone,
    String? profilePicture,
    String? signature,
    String? bio,
    bool? isPublic,
    int? followersCount,
    int? followingCount,
    int? recipesCount,
    String? kitchenId,
    bool? isPremium,
    String? premiumPlan,
    DateTime? premiumExpiresAt,
    List<String>? dietaryPreferences,
    List<String>? cuisinePreferences,
    bool? onboardingComplete,
    DateTime? lastActiveAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CheflessUser(
      id: id ?? this.id,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      profilePicture: profilePicture ?? this.profilePicture,
      signature: signature ?? this.signature,
      bio: bio ?? this.bio,
      isPublic: isPublic ?? this.isPublic,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      recipesCount: recipesCount ?? this.recipesCount,
      kitchenId: kitchenId ?? this.kitchenId,
      isPremium: isPremium ?? this.isPremium,
      premiumPlan: premiumPlan ?? this.premiumPlan,
      premiumExpiresAt: premiumExpiresAt ?? this.premiumExpiresAt,
      dietaryPreferences: dietaryPreferences ?? this.dietaryPreferences,
      cuisinePreferences: cuisinePreferences ?? this.cuisinePreferences,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        firebaseUid,
        email,
        fullName,
        phone,
        profilePicture,
        signature,
        bio,
        isPublic,
        followersCount,
        followingCount,
        recipesCount,
        kitchenId,
        isPremium,
        premiumPlan,
        premiumExpiresAt,
        dietaryPreferences,
        cuisinePreferences,
        onboardingComplete,
        lastActiveAt,
        createdAt,
        updatedAt,
      ];
}
