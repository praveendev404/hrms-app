import 'package:intl/intl.dart';

/// Attendance models
class AttendanceRequest {
  final String date;
  final int empId;
  final bool isForParticularDate;

  AttendanceRequest({
    required this.date,
    required this.empId,
    required this.isForParticularDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'empId': empId,
      'isForParticularDate': isForParticularDate,
    };
  }
}

class LeaveInfo {
  final String? leaveType;
  final String? status;

  LeaveInfo({this.leaveType, this.status});

  factory LeaveInfo.fromJson(Map<String, dynamic> json) {
    return LeaveInfo(
      leaveType: json['leaveType'] as String?,
      status: json['status'] as String?,
    );
  }
}

class RegularizeInfo {
  final String? status;
  final String? reason;

  RegularizeInfo({this.status, this.reason});

  factory RegularizeInfo.fromJson(Map<String, dynamic> json) {
    return RegularizeInfo(
      status: json['status'] as String?,
      reason: json['reason'] as String?,
    );
  }
}

class CompOffInfo {
  final String? date;
  final String? status;

  CompOffInfo({this.date, this.status});

  factory CompOffInfo.fromJson(Map<String, dynamic> json) {
    return CompOffInfo(
      date: json['date'] as String?,
      status: json['status'] as String?,
    );
  }
}

class AttendanceLog {
  final String? inTime;
  final String? outTime;
  final String? duration;

  AttendanceLog({this.inTime, this.outTime, this.duration});

  factory AttendanceLog.fromJson(Map<String, dynamic> json) {
    return AttendanceLog(
      inTime: json['inTime'] as String?,
      outTime: json['outTime'] as String?,
      duration: json['duration'] as String?,
    );
  }
}

class DailyAttendance {
  final String date;
  final String weekday;
  final LeaveInfo? leaveInfo;
  final RegularizeInfo? regularizeInfo;
  final CompOffInfo? compOffInfo;
  final List<AttendanceLog> logs;
  final bool isHoliday;

  DailyAttendance({
    required this.date,
    required this.weekday,
    this.leaveInfo,
    this.regularizeInfo,
    this.compOffInfo,
    required this.logs,
    required this.isHoliday,
  });

  factory DailyAttendance.fromJson(Map<String, dynamic> json) {
    return DailyAttendance(
      date: json['date'] as String,
      weekday: json['weekday'] as String,
      leaveInfo: json['leaveInfo'] != null
          ? LeaveInfo.fromJson(json['leaveInfo'] as Map<String, dynamic>)
          : null,
      regularizeInfo: json['regularizeInfo'] != null
          ? RegularizeInfo.fromJson(json['regularizeInfo'] as Map<String, dynamic>)
          : null,
      compOffInfo: json['compOffInfo'] != null
          ? CompOffInfo.fromJson(json['compOffInfo'] as Map<String, dynamic>)
          : null,
      logs: (json['logs'] as List?)
              ?.map((e) => AttendanceLog.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      isHoliday: json['isHoliday'] as bool? ?? false,
    );
  }

  /// Determine attendance status for this day
  String get status {
    if (isHoliday) return 'holiday';
    if (leaveInfo != null) return 'leave';
    if (compOffInfo != null) return 'compoff';
    if (logs.isEmpty) return 'absent';
    // Could add logic for half day based on logs duration
    return 'present';
  }
}

class EmployeeAttendance {
  final int empId;
  final String employeeName;
  final List<DailyAttendance> logsByDate;
  final String? emailId;

  EmployeeAttendance({
    required this.empId,
    required this.employeeName,
    required this.logsByDate,
    this.emailId,
  });

  factory EmployeeAttendance.fromJson(Map<String, dynamic> json) {
    return EmployeeAttendance(
      empId: json['empId'] as int,
      employeeName: json['employeeName'] as String,
      logsByDate: (json['logsByDate'] as List)
          .map((e) => DailyAttendance.fromJson(e as Map<String, dynamic>))
          .toList(),
      emailId: json['emailId'] as String?,
    );
  }

  /// Count total present days
  int get presentCount =>
      logsByDate.where((day) => day.status == 'present').length;

  /// Count total absent days (excluding holidays)
  int get absentCount =>
      logsByDate.where((day) => day.status == 'absent').length;

  /// Count total working days (excluding holidays)
  int get totalWorkingDays =>
      logsByDate.where((day) => !day.isHoliday).length;
}

class AttendanceResponse {
  final List<EmployeeAttendance> employees;

  AttendanceResponse({required this.employees});

  factory AttendanceResponse.fromJson(List<dynamic> json) {
    return AttendanceResponse(
      employees: json
          .map((e) => EmployeeAttendance.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Calculate overall present count
  int get totalPresent =>
      employees.fold(0, (sum, emp) => sum + emp.presentCount);

  /// Calculate overall absent count
  int get totalAbsent =>
      employees.fold(0, (sum, emp) => sum + emp.absentCount);

  /// Calculate total working days
  int get totalWorkingDays =>
      employees.fold(0, (sum, emp) => sum + emp.totalWorkingDays);

  /// Get today's attendance counts for a specific date
  Map<String, int> getTodayCounts(String dateStr) {
    int present = 0;
    int absent = 0;
    int total = 0;

    // Normalize the date string for comparison
    String normalizeDate(String date) {
      try {
        final dt = DateTime.parse(date);
        return DateFormat('yyyy-MM-dd').format(dt);
      } catch (e) {
        return date;
      }
    }

    final normalizedDateStr = normalizeDate(dateStr);

    for (var emp in employees) {
      final todayAttendance = emp.logsByDate.where((day) {
        final normalizedDay = normalizeDate(day.date);
        return normalizedDay == normalizedDateStr;
      }).firstOrNull;
      
      if (todayAttendance != null) {
        if (!todayAttendance.isHoliday) {
          total++;
          if (todayAttendance.status == 'present') {
            present++;
          } else if (todayAttendance.status == 'absent') {
            absent++;
          }
        }
      }
    }

    return {
      'present': present,
      'absent': absent,
      'total': total,
    };
  }
}
