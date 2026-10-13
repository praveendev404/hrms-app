// Wire models for the feed, assets and learning (my courses).

String? _ymd(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  return s.length >= 10 ? s.substring(0, 10) : s;
}

class FeedPost {
  final int id;
  final String header;
  final String body;
  final String feedTypeName;
  final String? authorName;
  final DateTime? createdDate;
  final int commentsCount;
  final int reactionsCount;
  final int myReactionTypeId;
  final String? expireDate;

  const FeedPost({
    required this.id,
    required this.header,
    required this.body,
    required this.feedTypeName,
    this.authorName,
    this.createdDate,
    required this.commentsCount,
    required this.reactionsCount,
    required this.myReactionTypeId,
    this.expireDate,
  });

  /// Expired announcements are not shown (the list endpoint does not filter them).
  bool get isExpired {
    final d = DateTime.tryParse(expireDate ?? '');
    if (d == null) return false;
    final today = DateTime.now();
    return DateTime(d.year, d.month, d.day).isBefore(DateTime(today.year, today.month, today.day));
  }

  bool get liked => myReactionTypeId > 0;

  /// Feed bodies may carry markup; show readable plain text on mobile.
  String get plainBody => body
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .trim();

  FeedPost withLike(bool like) => FeedPost(
        id: id,
        header: header,
        body: body,
        feedTypeName: feedTypeName,
        authorName: authorName,
        createdDate: createdDate,
        commentsCount: commentsCount,
        reactionsCount: (reactionsCount + (like ? 1 : -1)).clamp(0, 1 << 30),
        myReactionTypeId: like ? 1 : 0,
        expireDate: expireDate,
      );

  factory FeedPost.fromJson(Map<String, dynamic> j) {
    final info = j['baseListInfo'] as Map<String, dynamic>?;
    return FeedPost(
      id: (j['id'] as num?)?.toInt() ?? 0,
      header: j['header']?.toString() ?? '',
      body: j['body']?.toString() ?? '',
      feedTypeName: j['feedTypeName']?.toString() ?? '',
      authorName: info?['createdByName'] as String?,
      createdDate: DateTime.tryParse(info?['createdDate']?.toString() ?? '')?.toLocal(),
      commentsCount: (j['commentsCount'] as num?)?.toInt() ?? 0,
      reactionsCount: (j['reactionsCount'] as num?)?.toInt() ?? 0,
      myReactionTypeId: (j['empReactionTypeId'] as num?)?.toInt() ?? 0,
      expireDate: _ymd(j['expireDate']),
    );
  }
}

class FeedComment {
  final String author;
  final String text;
  final DateTime? at;
  const FeedComment({required this.author, required this.text, this.at});

  factory FeedComment.fromJson(Map<String, dynamic> j) => FeedComment(
        author: (j['empName'] ?? '').toString().trim(),
        text: j['comment']?.toString() ?? '',
        at: DateTime.tryParse(j['commentedDate']?.toString() ?? '')?.toLocal(),
      );
}

class AssetItem {
  final int id;
  final String code;
  final String typeName;
  final String? description;
  final String statusName;
  final String? issueDate;

  const AssetItem({
    required this.id,
    required this.code,
    required this.typeName,
    this.description,
    required this.statusName,
    this.issueDate,
  });

  factory AssetItem.fromJson(Map<String, dynamic> j) => AssetItem(
        id: (j['id'] as num?)?.toInt() ?? 0,
        code: j['assetCode']?.toString() ?? '',
        typeName: j['assetTypeName']?.toString() ?? '',
        description: j['description'] as String?,
        statusName: j['assetStatusTypeName']?.toString() ?? '',
        issueDate: _ymd(j['issueDate']),
      );
}

/// Enrollment statuses (see web LEARNING_ENROLLMENT_STATUSES).
class EnrollmentStatus {
  EnrollmentStatus._();
  static const int enrolled = 1;
  static const int inProgress = 2;
  static const int completed = 3;
  static const int dropped = 4;

  static String label(int id) {
    switch (id) {
      case inProgress:
        return 'In progress';
      case completed:
        return 'Completed';
      case dropped:
        return 'Dropped';
      default:
        return 'Enrolled';
    }
  }
}

class CourseEnrollment {
  final int id;
  final int courseId;
  final String title;
  final String? courseTypeName;
  final double? durationHours;
  final String? externalUrl;
  final int statusId;
  final String? dueDate;
  final double progress;

  const CourseEnrollment({
    required this.id,
    required this.courseId,
    required this.title,
    this.courseTypeName,
    this.durationHours,
    this.externalUrl,
    required this.statusId,
    this.dueDate,
    required this.progress,
  });

  factory CourseEnrollment.fromJson(Map<String, dynamic> j) => CourseEnrollment(
        id: (j['id'] as num?)?.toInt() ?? 0,
        courseId: (j['courseId'] as num?)?.toInt() ?? 0,
        title: j['courseTitle']?.toString() ?? '',
        courseTypeName: j['courseTypeName'] as String?,
        durationHours: (j['durationHours'] as num?)?.toDouble(),
        externalUrl: j['externalUrl'] as String?,
        statusId: (j['enrollmentStatusTypeId'] as num?)?.toInt() ?? 1,
        dueDate: _ymd(j['dueDate']),
        progress: (j['progressPercent'] as num?)?.toDouble() ?? 0,
      );
}

class CatalogCourse {
  final int id;
  final String title;
  final String? courseTypeName;
  final double? durationHours;

  const CatalogCourse({required this.id, required this.title, this.courseTypeName, this.durationHours});

  factory CatalogCourse.fromJson(Map<String, dynamic> j) => CatalogCourse(
        id: (j['id'] as num?)?.toInt() ?? 0,
        title: j['title']?.toString() ?? '',
        courseTypeName: j['courseTypeName'] as String?,
        durationHours: (j['durationHours'] as num?)?.toDouble(),
      );
}
