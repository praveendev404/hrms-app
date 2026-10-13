// Wire models for leave (api/v1/leave) and notifications (api/v1/notifications).

String? _date(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  return s.length >= 10 ? s.substring(0, 10) : s;
}

class LeaveBalance {
  final int leaveTypeId;
  final String leaveTypeName;
  final double total;
  final double used;

  const LeaveBalance({required this.leaveTypeId, required this.leaveTypeName, required this.total, required this.used});

  double get remaining => total - used;

  factory LeaveBalance.fromJson(Map<String, dynamic> j) => LeaveBalance(
        leaveTypeId: (j['leaveTypeId'] as num?)?.toInt() ?? 0,
        leaveTypeName: j['leaveTypeName']?.toString() ?? '',
        total: (j['totalLeaves'] as num?)?.toDouble() ?? 0,
        used: (j['usedLeaves'] as num?)?.toDouble() ?? 0,
      );
}

/// Leave statuses (LeaveStatusTypeEnum on the server).
class LeaveStatus {
  LeaveStatus._();
  static const int created = 1;
  static const int approved = 2;
  static const int cancelled = 3;
  static const int rejected = 4;
}

class LeaveRequest {
  final int id;
  final String? employeeName;
  final String leaveTypeName;
  final String fromDate;
  final String toDate;
  final String? fromDayTypeName;
  final String? toDayTypeName;
  final double noOfDays;
  final String? reason;
  final int statusId;
  final String statusName;
  final List<({String name, String status})> approvers;

  const LeaveRequest({
    required this.id,
    this.employeeName,
    required this.leaveTypeName,
    required this.fromDate,
    required this.toDate,
    this.fromDayTypeName,
    this.toDayTypeName,
    required this.noOfDays,
    this.reason,
    required this.statusId,
    required this.statusName,
    this.approvers = const [],
  });

  bool get canCancel => statusId == LeaveStatus.created;

  factory LeaveRequest.fromJson(Map<String, dynamic> j) => LeaveRequest(
        id: (j['id'] as num?)?.toInt() ?? 0,
        employeeName: j['employeeName'] as String?,
        leaveTypeName: j['leaveTypeName']?.toString() ?? '',
        fromDate: _date(j['fromDate']) ?? '',
        toDate: _date(j['toDate']) ?? '',
        fromDayTypeName: j['fromDayTypeName'] as String?,
        toDayTypeName: j['toDayTypeName'] as String?,
        noOfDays: (j['noOfDays'] as num?)?.toDouble() ?? 0,
        reason: j['reason'] as String?,
        statusId: int.tryParse(j['leaveStatusTypeId']?.toString() ?? '') ?? 0,
        statusName: j['leaveStatusTypeName']?.toString() ?? '',
        approvers: (j['approvalList'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map((a) => (name: (a['empName'] ?? '').toString().trim(), status: (a['leaveStatusName'] ?? '').toString()))
            .toList(),
      );
}

/// A pending approval row addressed to the current user.
class LeaveApproval {
  final int id;
  final String employeeName;
  final String leaveTypeName;
  final String fromDate;
  final String toDate;
  final double noOfDays;
  final String? reason;
  final int statusId;
  final String statusName;

  const LeaveApproval({
    required this.id,
    required this.employeeName,
    required this.leaveTypeName,
    required this.fromDate,
    required this.toDate,
    required this.noOfDays,
    this.reason,
    required this.statusId,
    required this.statusName,
  });

  bool get isPending => statusId == LeaveStatus.created;

  factory LeaveApproval.fromJson(Map<String, dynamic> j) => LeaveApproval(
        id: (j['id'] as num?)?.toInt() ?? 0,
        employeeName: j['employeeName']?.toString() ?? '',
        // The approvals endpoint does not select the leave type; never show a blank.
        leaveTypeName: (j['leaveTypeName']?.toString() ?? '').isEmpty ? 'Leave request' : j['leaveTypeName'].toString(),
        fromDate: _date(j['fromDate']) ?? '',
        toDate: _date(j['toDate']) ?? '',
        noOfDays: (j['noOfDays'] as num?)?.toDouble() ?? 0,
        reason: j['reason'] as String?,
        statusId: int.tryParse(j['leaveStatusTypeId']?.toString() ?? '') ?? 0,
        statusName: j['leaveStatusTypeName']?.toString() ?? '',
      );
}

class LeaveDayCount {
  final double noOfDays;
  final String problem;
  final bool isSubmittable;

  const LeaveDayCount({required this.noOfDays, required this.problem, required this.isSubmittable});

  /// Human text for a non-submittable result; the server stays the only calculator.
  String? get problemMessage {
    switch (problem) {
      case 'EndBeforeStart':
        return 'End date is before the start date.';
      case 'NoWorkingDays':
        return 'The selected dates have no working days (weekends or holidays).';
      case 'ZeroAfterPartialDays':
        return 'The selected half days bring the total to zero.';
      default:
        return isSubmittable ? null : 'Choose valid dates.';
    }
  }

  factory LeaveDayCount.fromJson(Map<String, dynamic> j) => LeaveDayCount(
        noOfDays: (j['noOfDays'] as num?)?.toDouble() ?? 0,
        problem: j['problem']?.toString() ?? 'None',
        isSubmittable: j['isSubmittable'] as bool? ?? false,
      );
}

/// Result of a mutating call (the platform's BaseResponse: success + message).
class ActionResult {
  final bool success;
  final String message;
  const ActionResult(this.success, this.message);

  factory ActionResult.fromJson(dynamic data) {
    if (data is Map<String, dynamic>) {
      return ActionResult(data['success'] as bool? ?? false, data['message']?.toString() ?? '');
    }
    return const ActionResult(false, 'Unexpected response');
  }
}

class AppNotification {
  final int id;
  final String type;
  final String title;
  final String message;
  final DateTime? createdDate;
  final bool isRead;
  final String? link;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.createdDate,
    required this.isRead,
    this.link,
  });

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        type: type,
        title: title,
        message: message,
        createdDate: createdDate,
        isRead: isRead ?? this.isRead,
        link: link,
      );

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: (j['id'] as num?)?.toInt() ?? 0,
        type: j['type']?.toString() ?? '',
        title: j['title']?.toString() ?? '',
        message: j['message']?.toString() ?? '',
        createdDate: DateTime.tryParse(j['createdDate']?.toString() ?? '')?.toLocal(),
        isRead: j['isRead'] as bool? ?? false,
        link: j['link'] as String?,
      );
}
