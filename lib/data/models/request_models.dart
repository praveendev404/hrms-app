// Wire models for attendance regularization, WFH requests and payslips.

String? _ymd(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  return s.length >= 10 ? s.substring(0, 10) : s;
}

/// Status ids shared by regularization (RegularizeStatusTypesEnum).
class RegularizeStatus {
  RegularizeStatus._();
  static const int initiated = 1;
  static const int approved = 2;
  static const int rejected = 3;
  static const int reInitiated = 4;
  static const int clarification = 5;
}

/// Status ids for WFH (WfhRequestStatusTypesEnum).
class WfhStatus {
  WfhStatus._();
  static const int pending = 1;
  static const int approved = 2;
  static const int rejected = 3;
  static const int cancelled = 4;
}

class RegularizeItem {
  final int id;
  final int empId;
  final String empName;
  final String date;
  final String? inTime;
  final String? outTime;
  final String typeName;
  final String? notes;
  final int statusId;
  final String statusName;

  const RegularizeItem({
    required this.id,
    required this.empId,
    required this.empName,
    required this.date,
    this.inTime,
    this.outTime,
    required this.typeName,
    this.notes,
    required this.statusId,
    required this.statusName,
  });

  bool get isPending =>
      statusId == RegularizeStatus.initiated ||
      statusId == RegularizeStatus.reInitiated ||
      statusId == RegularizeStatus.clarification;

  factory RegularizeItem.fromJson(Map<String, dynamic> j) => RegularizeItem(
        id: (j['id'] as num?)?.toInt() ?? 0,
        empId: (j['empId'] as num?)?.toInt() ?? 0,
        empName: j['empName']?.toString() ?? '',
        date: _ymd(j['date']) ?? '',
        inTime: j['inTime'] as String?,
        outTime: j['outTime'] as String?,
        typeName: j['regularizeTypeName']?.toString() ?? '',
        notes: j['notes'] as String?,
        statusId: (j['regularizeStatusTypeId'] as num?)?.toInt() ?? 0,
        statusName: j['regularizeStatusTypeName']?.toString() ?? '',
      );
}

class WfhItem {
  final int id;
  final int empId;
  final String empName;
  final String fromDate;
  final String toDate;
  final String? reason;
  final int statusId;
  final String statusName;

  const WfhItem({
    required this.id,
    required this.empId,
    required this.empName,
    required this.fromDate,
    required this.toDate,
    this.reason,
    required this.statusId,
    required this.statusName,
  });

  bool get isPending => statusId == WfhStatus.pending;

  factory WfhItem.fromJson(Map<String, dynamic> j) => WfhItem(
        id: (j['id'] as num?)?.toInt() ?? 0,
        empId: (j['empId'] as num?)?.toInt() ?? 0,
        empName: j['empName']?.toString() ?? '',
        fromDate: _ymd(j['fromDate']) ?? '',
        toDate: _ymd(j['toDate']) ?? '',
        reason: j['reason'] as String?,
        statusId: (j['statusTypeId'] as num?)?.toInt() ?? 0,
        statusName: j['statusTypeName']?.toString() ?? '',
      );
}

class PayslipItem {
  final int id;
  final String? filePath;
  final String fromDate;
  final String toDate;
  final double payDays;
  final double lopDays;

  const PayslipItem({
    required this.id,
    this.filePath,
    required this.fromDate,
    required this.toDate,
    required this.payDays,
    required this.lopDays,
  });

  factory PayslipItem.fromJson(Map<String, dynamic> j) => PayslipItem(
        id: (j['id'] as num?)?.toInt() ?? 0,
        filePath: j['paySlip'] as String?,
        fromDate: _ymd(j['fromDate']) ?? '',
        toDate: _ymd(j['toDate']) ?? '',
        payDays: (j['payDays'] as num?)?.toDouble() ?? 0,
        lopDays: (j['lopDays'] as num?)?.toDouble() ?? 0,
      );
}
