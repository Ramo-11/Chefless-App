import 'package:flutter_test/flutter_test.dart';
import 'package:chefless_app/models/report.dart';

void main() {
  final now = DateTime.utc(2026, 3, 10, 12, 0, 0);
  final later = DateTime.utc(2026, 3, 10, 13, 0, 0);

  Map<String, dynamic> sampleJson() => {
        '_id': 'report-123',
        'reporterId': 'user-456',
        'targetType': 'recipe',
        'targetId': 'recipe-789',
        'reason': 'spam',
        'description': 'This looks like spam',
        'status': 'pending',
        'reviewedBy': 'admin-001',
        'reviewNote': 'Will review soon',
        'createdAt': now.toIso8601String(),
        'updatedAt': later.toIso8601String(),
      };

  Report sampleReport() => Report(
        id: 'report-123',
        reporterId: 'user-456',
        targetType: 'recipe',
        targetId: 'recipe-789',
        reason: 'spam',
        description: 'This looks like spam',
        status: 'pending',
        reviewedBy: 'admin-001',
        reviewNote: 'Will review soon',
        createdAt: now,
        updatedAt: later,
      );

  group('Report', () {
    group('fromJson / toJson round-trip', () {
      test('parses all fields correctly from JSON', () {
        final report = Report.fromJson(sampleJson());

        expect(report.id, 'report-123');
        expect(report.reporterId, 'user-456');
        expect(report.targetType, 'recipe');
        expect(report.targetId, 'recipe-789');
        expect(report.reason, 'spam');
        expect(report.description, 'This looks like spam');
        expect(report.status, 'pending');
        expect(report.reviewedBy, 'admin-001');
        expect(report.reviewNote, 'Will review soon');
        expect(report.createdAt, now);
        expect(report.updatedAt, later);
      });

      test('round-trips through toJson and fromJson', () {
        final original = sampleReport();
        final json = original.toJson();
        final restored = Report.fromJson(json);

        expect(restored, original);
      });

      test('handles null optional fields', () {
        final json = {
          '_id': 'report-minimal',
          'reporterId': 'user-1',
          'targetType': 'user',
          'targetId': 'user-2',
          'reason': 'harassment',
          'status': 'pending',
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        };

        final report = Report.fromJson(json);

        expect(report.description, isNull);
        expect(report.reviewedBy, isNull);
        expect(report.reviewNote, isNull);
      });

      test('defaults status to pending when null in JSON', () {
        final json = {
          '_id': 'report-no-status',
          'reporterId': 'user-1',
          'targetType': 'recipe',
          'targetId': 'recipe-1',
          'reason': 'spam',
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        };

        final report = Report.fromJson(json);
        expect(report.status, 'pending');
      });

      test('toJson omits null optional fields', () {
        final report = Report(
          id: 'r1',
          reporterId: 'u1',
          targetType: 'recipe',
          targetId: 'rec1',
          reason: 'spam',
          status: 'pending',
          createdAt: now,
          updatedAt: now,
        );

        final json = report.toJson();

        expect(json.containsKey('description'), isFalse);
        expect(json.containsKey('reviewedBy'), isFalse);
        expect(json.containsKey('reviewNote'), isFalse);
      });

      test('handles action_taken status', () {
        final json = sampleJson();
        json['status'] = 'action_taken';

        final report = Report.fromJson(json);
        expect(report.status, 'action_taken');

        final serialized = report.toJson();
        expect(serialized['status'], 'action_taken');
      });

      test('handles all valid reason values', () {
        for (final reason in ['spam', 'inappropriate', 'copyright', 'harassment', 'other']) {
          final json = sampleJson();
          json['reason'] = reason;

          final report = Report.fromJson(json);
          expect(report.reason, reason);

          final serialized = report.toJson();
          final restored = Report.fromJson(serialized);
          expect(restored.reason, reason);
        }
      });

      test('handles all valid targetType values', () {
        for (final targetType in ['recipe', 'user']) {
          final json = sampleJson();
          json['targetType'] = targetType;

          final report = Report.fromJson(json);
          expect(report.targetType, targetType);
        }
      });
    });

    group('copyWith', () {
      test('returns identical report when no args provided', () {
        final original = sampleReport();
        final copy = original.copyWith();

        expect(copy, original);
      });

      test('updates only specified fields', () {
        final original = sampleReport();
        final updated = original.copyWith(
          status: 'reviewed',
          reviewNote: 'Looks good',
        );

        expect(updated.status, 'reviewed');
        expect(updated.reviewNote, 'Looks good');
        expect(updated.id, original.id);
        expect(updated.reporterId, original.reporterId);
        expect(updated.reason, original.reason);
      });
    });

    group('Equatable', () {
      test('two reports with same data are equal', () {
        final a = sampleReport();
        final b = sampleReport();

        expect(a, b);
        expect(a.hashCode, b.hashCode);
      });

      test('two reports with different data are not equal', () {
        final a = sampleReport();
        final b = sampleReport().copyWith(id: 'different-id');

        expect(a, isNot(b));
      });

      test('reports with different statuses are not equal', () {
        final a = sampleReport();
        final b = sampleReport().copyWith(status: 'dismissed');

        expect(a, isNot(b));
      });
    });
  });
}
