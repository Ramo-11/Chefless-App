import 'package:equatable/equatable.dart';

/// A user-submitted report against a recipe or user.
class Report extends Equatable {
  const Report({
    required this.id,
    required this.reporterId,
    required this.targetType,
    required this.targetId,
    required this.reason,
    this.description,
    required this.status,
    this.reviewedBy,
    this.reviewNote,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String reporterId;
  final String targetType;
  final String targetId;
  final String reason;
  final String? description;
  final String status;
  final String? reviewedBy;
  final String? reviewNote;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['_id'] as String,
      reporterId: json['reporterId'] as String,
      targetType: json['targetType'] as String,
      targetId: json['targetId'] as String,
      reason: json['reason'] as String,
      description: json['description'] as String?,
      status: json['status'] as String? ?? 'pending',
      reviewedBy: json['reviewedBy'] as String?,
      reviewNote: json['reviewNote'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'reporterId': reporterId,
      'targetType': targetType,
      'targetId': targetId,
      'reason': reason,
      if (description != null) 'description': description,
      'status': status,
      if (reviewedBy != null) 'reviewedBy': reviewedBy,
      if (reviewNote != null) 'reviewNote': reviewNote,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Report copyWith({
    String? id,
    String? reporterId,
    String? targetType,
    String? targetId,
    String? reason,
    String? description,
    String? status,
    String? reviewedBy,
    String? reviewNote,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Report(
      id: id ?? this.id,
      reporterId: reporterId ?? this.reporterId,
      targetType: targetType ?? this.targetType,
      targetId: targetId ?? this.targetId,
      reason: reason ?? this.reason,
      description: description ?? this.description,
      status: status ?? this.status,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewNote: reviewNote ?? this.reviewNote,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        reporterId,
        targetType,
        targetId,
        reason,
        description,
        status,
        reviewedBy,
        reviewNote,
        createdAt,
        updatedAt,
      ];
}
