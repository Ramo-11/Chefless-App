import 'package:flutter_test/flutter_test.dart';
import 'package:chefless_app/models/user.dart';

void main() {
  final now = DateTime.utc(2026, 3, 10, 12, 0, 0);
  final later = DateTime.utc(2026, 3, 10, 13, 0, 0);

  Map<String, dynamic> sampleUserJson() => {
        '_id': 'user-123',
        'firebaseUid': 'firebase-abc',
        'email': 'test@example.com',
        'fullName': 'John Doe',
        'phone': '+1234567890',
        'profilePicture': 'https://example.com/avatar.jpg',
        'signature': 'Chef John',
        'bio': 'I love cooking',
        'isPublic': true,
        'followersCount': 100,
        'followingCount': 50,
        'recipesCount': 25,
        'originalRecipesCount': 18,
        'kitchenId': 'kitchen-456',
        'isPremium': true,
        'premiumPlan': 'annual',
        'premiumExpiresAt': later.toIso8601String(),
        'dietaryPreferences': ['vegan', 'gluten-free'],
        'cuisinePreferences': ['italian', 'japanese'],
        'onboardingComplete': true,
        'lastActiveAt': now.toIso8601String(),
        'createdAt': now.toIso8601String(),
        'updatedAt': later.toIso8601String(),
      };

  group('CheflessUser', () {
    test('fromJson parses all fields correctly', () {
      final user = CheflessUser.fromJson(sampleUserJson());

      expect(user.id, 'user-123');
      expect(user.firebaseUid, 'firebase-abc');
      expect(user.email, 'test@example.com');
      expect(user.fullName, 'John Doe');
      expect(user.phone, '+1234567890');
      expect(user.profilePicture, 'https://example.com/avatar.jpg');
      expect(user.signature, 'Chef John');
      expect(user.bio, 'I love cooking');
      expect(user.isPublic, true);
      expect(user.followersCount, 100);
      expect(user.followingCount, 50);
      expect(user.recipesCount, 25);
      expect(user.originalRecipesCount, 18);
      expect(user.kitchenId, 'kitchen-456');
      expect(user.isPremium, true);
      expect(user.premiumPlan, 'annual');
      expect(user.premiumExpiresAt, later);
      expect(user.dietaryPreferences, ['vegan', 'gluten-free']);
      expect(user.cuisinePreferences, ['italian', 'japanese']);
      expect(user.onboardingComplete, true);
      expect(user.lastActiveAt, now);
      expect(user.createdAt, now);
      expect(user.updatedAt, later);
    });

    test('fromJson handles minimal / default values', () {
      final json = {
        '_id': 'user-min',
        'firebaseUid': 'firebase-min',
        'email': 'min@example.com',
        'fullName': 'Min User',
        'lastActiveAt': now.toIso8601String(),
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };

      final user = CheflessUser.fromJson(json);

      expect(user.phone, isNull);
      expect(user.profilePicture, isNull);
      expect(user.signature, isNull);
      expect(user.bio, isNull);
      expect(user.isPublic, true);
      expect(user.followersCount, 0);
      expect(user.followingCount, 0);
      expect(user.recipesCount, 0);
      expect(user.originalRecipesCount, 0);
      expect(user.kitchenId, isNull);
      expect(user.isPremium, false);
      expect(user.premiumPlan, isNull);
      expect(user.premiumExpiresAt, isNull);
      expect(user.dietaryPreferences, isEmpty);
      expect(user.cuisinePreferences, isEmpty);
      expect(user.onboardingComplete, false);
    });

    test('toJson / fromJson round-trips correctly', () {
      final original = CheflessUser.fromJson(sampleUserJson());
      final json = original.toJson();
      final restored = CheflessUser.fromJson(json);

      expect(restored, original);
    });

    test('toJson includes all fields', () {
      final user = CheflessUser.fromJson(sampleUserJson());
      final json = user.toJson();

      expect(json['_id'], 'user-123');
      expect(json['firebaseUid'], 'firebase-abc');
      expect(json['email'], 'test@example.com');
      expect(json['fullName'], 'John Doe');
      expect(json['phone'], '+1234567890');
      expect(json['profilePicture'], 'https://example.com/avatar.jpg');
      expect(json['recipesCount'], 25);
      expect(json['originalRecipesCount'], 18);
      expect(json['isPremium'], true);
      expect(json['premiumPlan'], 'annual');
      expect(json['dietaryPreferences'], ['vegan', 'gluten-free']);
      expect(json['cuisinePreferences'], ['italian', 'japanese']);
    });

    test('copyWith updates only specified fields', () {
      final original = CheflessUser.fromJson(sampleUserJson());
      final updated = original.copyWith(
        fullName: 'Jane Doe',
        isPremium: false,
      );

      expect(updated.fullName, 'Jane Doe');
      expect(updated.isPremium, false);
      expect(updated.id, original.id);
      expect(updated.email, original.email);
      expect(updated.firebaseUid, original.firebaseUid);
    });

    test('Equatable: same data are equal', () {
      final a = CheflessUser.fromJson(sampleUserJson());
      final b = CheflessUser.fromJson(sampleUserJson());

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('Equatable: different data are not equal', () {
      final a = CheflessUser.fromJson(sampleUserJson());
      final b = a.copyWith(email: 'other@example.com');

      expect(a, isNot(b));
    });
  });
}
