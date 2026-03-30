import 'package:equatable/equatable.dart';

import 'user.dart';

/// Represents a Kitchen group as returned by the API.
class Kitchen extends Equatable {
  const Kitchen({
    required this.id,
    required this.name,
    required this.leadId,
    required this.inviteCode,
    this.photo,
    required this.membersWithScheduleEdit,
    required this.membersWithApprovalPower,
    required this.memberCount,
    required this.customMealSlots,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String leadId;
  final String inviteCode;
  final String? photo;
  final List<String> membersWithScheduleEdit;
  final List<String> membersWithApprovalPower;
  final int memberCount;
  /// Custom meal slot names added by the kitchen lead (e.g. "Pre-Workout").
  final List<String> customMealSlots;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Kitchen.fromJson(Map<String, dynamic> json) {
    return Kitchen(
      id: json['_id'] as String,
      name: json['name'] as String,
      leadId: json['leadId'] as String,
      inviteCode: json['inviteCode'] as String,
      photo: json['photo'] as String?,
      membersWithScheduleEdit:
          (json['membersWithScheduleEdit'] as List<dynamic>?)
                  ?.cast<String>() ??
              const [],
      membersWithApprovalPower:
          (json['membersWithApprovalPower'] as List<dynamic>?)
                  ?.cast<String>() ??
              const [],
      memberCount: json['memberCount'] as int? ?? 1,
      customMealSlots:
          (json['customMealSlots'] as List<dynamic>?)?.cast<String>() ??
              const [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'leadId': leadId,
      'inviteCode': inviteCode,
      'photo': photo,
      'membersWithScheduleEdit': membersWithScheduleEdit,
      'membersWithApprovalPower': membersWithApprovalPower,
      'memberCount': memberCount,
      'customMealSlots': customMealSlots,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Kitchen copyWith({
    String? id,
    String? name,
    String? leadId,
    String? inviteCode,
    String? photo,
    List<String>? membersWithScheduleEdit,
    List<String>? membersWithApprovalPower,
    int? memberCount,
    List<String>? customMealSlots,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Kitchen(
      id: id ?? this.id,
      name: name ?? this.name,
      leadId: leadId ?? this.leadId,
      inviteCode: inviteCode ?? this.inviteCode,
      photo: photo ?? this.photo,
      membersWithScheduleEdit:
          membersWithScheduleEdit ?? this.membersWithScheduleEdit,
      membersWithApprovalPower:
          membersWithApprovalPower ?? this.membersWithApprovalPower,
      memberCount: memberCount ?? this.memberCount,
      customMealSlots: customMealSlots ?? this.customMealSlots,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        leadId,
        inviteCode,
        photo,
        membersWithScheduleEdit,
        membersWithApprovalPower,
        memberCount,
        customMealSlots,
        createdAt,
        updatedAt,
      ];
}

/// Kitchen detail response containing the kitchen and its members.
class KitchenDetail extends Equatable {
  const KitchenDetail({
    required this.kitchen,
    required this.members,
  });

  final Kitchen kitchen;
  final List<CheflessUser> members;

  factory KitchenDetail.fromJson(Map<String, dynamic> json) {
    final kitchenData = json['kitchen'] as Map<String, dynamic>;
    final membersData = json['members'] as List<dynamic>? ?? const [];

    return KitchenDetail(
      kitchen: Kitchen.fromJson(kitchenData),
      members: membersData
          .map((m) => CheflessUser.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  List<Object?> get props => [kitchen, members];
}
