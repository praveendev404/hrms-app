import 'package:intl/intl.dart';

/// Date and time formatting utilities
class AppDateUtils {
  AppDateUtils._();

  /// Format date to readable string (e.g., "Dec 22, 2025")
  static String formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  /// Format date and time (e.g., "Dec 22, 2025 at 3:45 PM")
  static String formatDateTime(DateTime dateTime) {
    return DateFormat('MMM dd, yyyy \'at\' h:mm a').format(dateTime);
  }

  /// Format time only (e.g., "3:45 PM")
  static String formatTime(DateTime dateTime) {
    return DateFormat('h:mm a').format(dateTime);
  }

  /// Format to ISO 8601 string
  static String toIsoString(DateTime dateTime) {
    return dateTime.toUtc().toIso8601String();
  }

  /// Parse ISO 8601 string to DateTime
  static DateTime? fromIsoString(String? isoString) {
    if (isoString == null) return null;
    try {
      return DateTime.parse(isoString);
    } catch (_) {
      return null;
    }
  }

  /// Get relative time string (e.g., "2 hours ago")
  static String getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return formatDate(dateTime);
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  /// Get timestamp for photo metadata
  static String getTimestamp() {
    return DateTime.now().toUtc().toIso8601String();
  }
}

