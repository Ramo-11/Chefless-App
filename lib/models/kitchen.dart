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
    required this.isPublic,
    required this.membersWithScheduleEdit,
    required this.membersWithApprovalPower,
    required this.memberCount,
    required this.customMealSlots,
    required this.scheduleAddPolicy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String leadId;
  final String inviteCode;
  final String? photo;
  final bool isPublic;
  final List<String> membersWithScheduleEdit;
  final List<String> membersWithApprovalPower;
  final int memberCount;
  /// Custom meal slot names added by the kitchen lead (e.g. "Pre-Workout").
  final List<String> customMealSlots;

  /// Who can add schedule entries directly.
  ///
  /// - `"lead_only"` (default): only the lead and members in
  ///   [membersWithScheduleEdit] add directly; other members' additions
  ///   become suggestions awaiting approval.
  /// - `"all"`: any kitchen member adds entries directly.
  final String scheduleAddPolicy;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Kitchen.fromJson(Map<String, dynamic> json) {
    return Kitchen(
      id: json['_id'] as String,
      name: json['name'] as String,
      leadId: json['leadId'] as String,
      inviteCode: json['inviteCode'] as String,
      photo: json['photo'] as String?,
      isPublic: json['isPublic'] as bool? ?? false,
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
      scheduleAddPolicy:
          json['scheduleAddPolicy'] as String? ?? 'lead_only',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'leadId': leadId,
      'inviteCode': inviteCode,
      'photo': photo,
      'isPublic': isPublic,
      'membersWithScheduleEdit': membersWithScheduleEdit,
      'membersWithApprovalPower': membersWithApprovalPower,
      'memberCount': memberCount,
      'customMealSlots': customMealSlots,
      'scheduleAddPolicy': scheduleAddPolicy,
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
    bool? isPublic,
    List<String>? membersWithScheduleEdit,
    List<String>? membersWithApprovalPower,
    int? memberCount,
    List<String>? customMealSlots,
    String? scheduleAddPolicy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Kitchen(
      id: id ?? this.id,
      name: name ?? this.name,
      leadId: leadId ?? this.leadId,
      inviteCode: inviteCode ?? this.inviteCode,
      photo: photo ?? this.photo,
      isPublic: isPublic ?? this.isPublic,
      membersWithScheduleEdit:
          membersWithScheduleEdit ?? this.membersWithScheduleEdit,
      membersWithApprovalPower:
          membersWithApprovalPower ?? this.membersWithApprovalPower,
      memberCount: memberCount ?? this.memberCount,
      customMealSlots: customMealSlots ?? this.customMealSlots,
      scheduleAddPolicy: scheduleAddPolicy ?? this.scheduleAddPolicy,
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
        isPublic,
        membersWithScheduleEdit,
        membersWithApprovalPower,
        memberCount,
        customMealSlots,
        scheduleAddPolicy,
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
