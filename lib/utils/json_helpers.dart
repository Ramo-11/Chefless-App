// Safe JSON parsing helpers for MongoDB responses.
//
// MongoDB may serialize ObjectId and Date fields in several formats depending
// on whether the query used `.find().lean()`, aggregation, or populate. These
// helpers handle every variant so model `fromJson` factories never crash.

/// Extracts a plain string ID from a value that may be:
/// - A `String` (most common from `.lean()`)
/// - A `Map` with `$oid` key (MongoDB extended JSON)
/// - An `ObjectId` serialised by Dio as a Map
/// - `null`
String asId(dynamic value) {
  if (value is String) return value;
  if (value is Map) {
    if (value.containsKey('\$oid')) return value['\$oid'] as String;
    if (value.containsKey('_id')) return asId(value['_id']);
  }
  return value?.toString() ?? '';
}

/// Same as [asId] but returns `null` for null/missing values.
String? asIdOrNull(dynamic value) {
  if (value == null) return null;
  final result = asId(value);
  return result.isEmpty ? null : result;
}

/// Parses a DateTime from a value that may be:
/// - An ISO 8601 `String`
/// - A `Map` with `$date` key (MongoDB extended JSON)
/// - Already a `DateTime` (rare, from Mongoose internals)
/// - `null` (returns [fallback])
DateTime asDateTime(dynamic value, {DateTime? fallback}) {
  if (value is String) return DateTime.parse(value);
  if (value is Map && value.containsKey('\$date')) {
    return DateTime.parse(value['\$date'] as String);
  }
  if (value is DateTime) return value;
  return fallback ?? DateTime.now();
}
