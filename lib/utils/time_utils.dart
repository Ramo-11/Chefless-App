import 'package:intl/intl.dart';

/// Formats a [DateTime] as a human-readable relative timestamp.
///
/// Returns "just now" for <1 minute, compact units for recent times
/// ("2m", "1h", "3d", "2w"), and a date string ("Mar 5") for older entries.
String timeAgo(DateTime date) {
  final now = DateTime.now();
  final difference = now.difference(date);

  if (difference.isNegative || difference.inSeconds < 60) {
    return 'just now';
  }

  if (difference.inMinutes < 60) {
    return '${difference.inMinutes}m';
  }

  if (difference.inHours < 24) {
    return '${difference.inHours}h';
  }

  if (difference.inDays < 7) {
    return '${difference.inDays}d';
  }

  if (difference.inDays < 30) {
    final weeks = difference.inDays ~/ 7;
    return '${weeks}w';
  }

  // For anything older than ~4 weeks, show the date.
  return DateFormat.MMMd().format(date);
}
