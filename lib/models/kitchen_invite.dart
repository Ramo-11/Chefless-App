import 'package:equatable/equatable.dart';

import '../utils/json_helpers.dart';

/// Represents an in-app Kitchen invite as returned by the API.
///
/// The API populates `senderId` with the user's `fullName` and
/// `profilePicture` so the notifications UI can render a friendly tile
/// without a second round-trip.
class KitchenInvite extends Equatable {
  const KitchenInvite({
    required this.id,
    required this.kitchenId,
    required this.kitchenName,
    required this.senderId,
    required this.senderName,
    this.senderPhoto,
    required this.recipientId,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String kitchenId;
  final String kitchenName;
  final String senderId;
  final String senderName;
  final String? senderPhoto;
  final String recipientId;

  /// One of `"pending"`, `"accepted"`, `"declined"`.
  final String status;
  final DateTime createdAt;

  bool get isPending => status == 'pending';

  factory KitchenInvite.fromJson(Map<String, dynamic> json) {
    // `senderId` may arrive populated (Map with fullName/profilePicture) from
    // the pending invites endpoint, or as a plain ObjectId string after the
    // invite is created via `sendKitchenInvite`.
    final senderRaw = json['senderId'];
    String senderId = '';
    String senderName = '';
    String? senderPhoto;
    if (senderRaw is Map<String, dynamic>) {
      senderId = asIdOrNull(senderRaw['_id']) ?? '';
      senderName = (senderRaw['fullName'] as String?) ?? '';
      senderPhoto = senderRaw['profilePicture'] as String?;
    } else {
      senderId = asIdOrNull(senderRaw) ?? '';
    }

    return KitchenInvite(
      id: asId(json['_id']),
      kitchenId: asIdOrNull(json['kitchenId']) ?? '',
      kitchenName: (json['kitchenName'] as String?) ?? '',
      senderId: senderId,
      senderName: senderName,
      senderPhoto: senderPhoto,
      recipientId: asIdOrNull(json['recipientId']) ?? '',
      status: (json['status'] as String?) ?? 'pending',
      createdAt:
          asDateTime(json['createdAt'], fallback: DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'kitchenId': kitchenId,
      'kitchenName': kitchenName,
      'senderId': senderId,
      'senderName': senderName,
      'senderPhoto': senderPhoto,
      'recipientId': recipientId,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  KitchenInvite copyWith({
    String? id,
    String? kitchenId,
    String? kitchenName,
    String? senderId,
    String? senderName,
    String? senderPhoto,
    String? recipientId,
    String? status,
    DateTime? createdAt,
  }) {
    return KitchenInvite(
      id: id ?? this.id,
      kitchenId: kitchenId ?? this.kitchenId,
      kitchenName: kitchenName ?? this.kitchenName,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderPhoto: senderPhoto ?? this.senderPhoto,
      recipientId: recipientId ?? this.recipientId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        kitchenId,
        kitchenName,
        senderId,
        senderName,
        senderPhoto,
        recipientId,
        status,
        createdAt,
      ];
}
