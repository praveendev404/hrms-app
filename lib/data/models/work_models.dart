// Wire models for the performance summary widget and timesheets.

String? _ymd(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  return s.length >= 10 ? s.substring(0, 10) : s;
}

/// My standing in the active performance cycle (mirrors the web widget).
class PerformanceSummary {
  final String cycleName;
  final int cycleStatusId;
  final String cycleStatusName;
  final int totalGoals;
  final int approvedGoals;
  final int? reviewStatusId;
  final String? nextDeadlineLabel;
  final String? nextDeadline;

  const PerformanceSummary({
    required this.cycleName,
    required this.cycleStatusId,
    required this.cycleStatusName,
    required this.totalGoals,
    required this.approvedGoals,
    this.reviewStatusId,
    this.nextDeadlineLabel,
    this.nextDeadline,
  });

  String get reviewLabel {
    switch (reviewStatusId) {
      case 1:
        return 'Pending';
      case 2:
        return 'Submitted';
      case 3:
        return 'In review';
      case 4:
        return 'Finalized';
      default:
        return 'Not started';
    }
  }

  /// Pure assembly from the three API payloads; the server stays the source of truth.
  static PerformanceSummary? build({
    required List<Map<String, dynamic>> cycles,
    required List<Map<String, dynamic>> goals,
    required List<Map<String, dynamic>> reviews,
  }) {
    if (cycles.isEmpty) return null;
    final c = cycles.firstWhere(
      (x) => ((x['cycleStatusTypeId'] as num?)?.toInt() ?? 0) >= 2 && ((x['cycleStatusTypeId'] as num?)?.toInt() ?? 0) <= 4,
      orElse: () => cycles.firstWhere(
        (x) => (x['cycleStatusTypeId'] as num?)?.toInt() == 5,
        orElse: () => cycles.first,
      ),
    );
    final status = (c['cycleStatusTypeId'] as num?)?.toInt() ?? 0;
    String? label;
    String? date;
    if (status == 2) {
      label = 'Goal setting ends';
      date = _ymd(c['goalSettingEndDate']);
    } else if (status == 3) {
      label = 'Self assessment ends';
      date = _ymd(c['selfAssessmentEndDate']);
    } else if (status == 4) {
      label = 'Manager review ends';
      date = _ymd(c['managerReviewEndDate']);
    }
    return PerformanceSummary(
      cycleName: c['name']?.toString() ?? '',
      cycleStatusId: status,
      cycleStatusName: c['cycleStatusTypeName']?.toString() ?? '',
      totalGoals: goals.length,
      approvedGoals: goals.where((g) => (g['goalStatusTypeId'] as num?)?.toInt() == 3).length,
      reviewStatusId: reviews.isEmpty ? null : (reviews.first['reviewStatusTypeId'] as num?)?.toInt(),
      nextDeadlineLabel: label,
      nextDeadline: date,
    );
  }
}

/// Timesheet statuses (TimesheetStatusTypes).
class TimesheetStatus {
  TimesheetStatus._();
  static const int draft = 1;
  static const int submitted = 2;
  static const int approved = 3;
  static const int rejected = 4;
}

class TimesheetItem {
  final int id;
  final String fromDate;
  final String toDate;
  final int statusId;
  final String statusName;
  final num totalHours;
  final num billableHours;
  final String? managerName;

  const TimesheetItem({
    required this.id,
    required this.fromDate,
    required this.toDate,
    required this.statusId,
    required this.statusName,
    required this.totalHours,
    required this.billableHours,
    this.managerName,
  });

  factory TimesheetItem.fromJson(Map<String, dynamic> j) => TimesheetItem(
        id: (j['id'] as num?)?.toInt() ?? 0,
        fromDate: _ymd(j['fromDate']) ?? '',
        toDate: _ymd(j['toDate']) ?? '',
        statusId: (j['timesheetStatusTypeId'] as num?)?.toInt() ?? 0,
        statusName: j['timesheetStatusTypeName']?.toString() ?? '',
        totalHours: j['totalHours'] as num? ?? 0,
        billableHours: j['billableHours'] as num? ?? 0,
        managerName: j['managerName'] as String?,
      );
}

/// One calendar day of my attendance (api/v1/attendence/getdetailAttendence).
class AttendanceDay {
  final String date;
  final String? firstIn;
  final String? lastOut;
  final double totalHours;
  final bool isLate;
  final int lateByMinutes;
  final bool isMissingPunchOut;
  final bool isWfh;
  final String? wfhReason;
  final bool isRegularize;
  final String? regularizeStatus;
  final String? regularizeType;
  final int punchCount;

  const AttendanceDay({
    required this.date,
    this.firstIn,
    this.lastOut,
    required this.totalHours,
    required this.isLate,
    required this.lateByMinutes,
    required this.isMissingPunchOut,
    required this.isWfh,
    this.wfhReason,
    required this.isRegularize,
    this.regularizeStatus,
    this.regularizeType,
    required this.punchCount,
  });

  bool get hasPunches => punchCount > 0;

  factory AttendanceDay.fromJson(Map<String, dynamic> j) => AttendanceDay(
        date: _ymd(j['date']) ?? '',
        firstIn: j['firstPunchIn'] as String?,
        lastOut: j['lastPunchOut'] as String?,
        totalHours: (j['totalHours'] as num?)?.toDouble() ?? 0,
        isLate: j['isLate'] as bool? ?? false,
        lateByMinutes: (j['lateByMinutes'] as num?)?.toInt() ?? 0,
        isMissingPunchOut: j['isMissingPunchOut'] as bool? ?? false,
        isWfh: j['isWfh'] as bool? ?? false,
        wfhReason: j['wfhReason'] as String?,
        isRegularize: j['isRegularize'] as bool? ?? false,
        regularizeStatus: j['regularizeStatus'] as String?,
        regularizeType: j['regularizeType'] as String?,
        punchCount: (j['logs'] as List<dynamic>?)?.length ?? 0,
      );
}

/// One employee-week timesheet (api/v1/timesheet/week).
class TimesheetSheet {
  final int id;
  final int statusId;
  final String statusName;
  final String fromDate;
  final String toDate;

  const TimesheetSheet({
    required this.id,
    required this.statusId,
    required this.statusName,
    required this.fromDate,
    required this.toDate,
  });

  /// Hours can be edited while the sheet is Draft or was Rejected.
  bool get isEditable => statusId == TimesheetStatus.draft || statusId == TimesheetStatus.rejected;
  bool get canSubmit => isEditable;
  bool get canWithdraw => statusId == TimesheetStatus.submitted;

  factory TimesheetSheet.fromJson(Map<String, dynamic> j) => TimesheetSheet(
        id: (j['id'] as num?)?.toInt() ?? 0,
        statusId: (j['timesheetStatusTypeId'] as num?)?.toInt() ?? TimesheetStatus.draft,
        statusName: j['timesheetStatusTypeName']?.toString() ?? '',
        fromDate: _ymd(j['fromDate']) ?? '',
        toDate: _ymd(j['toDate']) ?? '',
      );
}

/// One logged line of work on a timesheet.
class WorkLog {
  final int? id;
  final int projectId;
  final String projectName;
  final int workLogTypeId;
  final String workLogTypeName;
  final String date;
  final int hours;
  final String? taskNumber;
  final String comments;
  final bool isBillable;

  const WorkLog({
    this.id,
    required this.projectId,
    this.projectName = '',
    required this.workLogTypeId,
    this.workLogTypeName = '',
    required this.date,
    required this.hours,
    this.taskNumber,
    required this.comments,
    required this.isBillable,
  });

  factory WorkLog.fromJson(Map<String, dynamic> j) => WorkLog(
        id: (j['id'] as num?)?.toInt(),
        projectId: (j['projectId'] as num?)?.toInt() ?? 0,
        projectName: j['projectName']?.toString() ?? '',
        workLogTypeId: (j['workLogTypeId'] as num?)?.toInt() ?? 0,
        workLogTypeName: j['workLogTypeName']?.toString() ?? '',
        date: _ymd(j['date']) ?? '',
        hours: (j['duration'] as num?)?.toInt() ?? 0,
        taskNumber: j['taskNumber'] as String?,
        comments: j['comments']?.toString() ?? '',
        isBillable: j['isBillable'] as bool? ?? false,
      );
}

/// A compensatory-off request (api/v1/compoff).
class CompOffItem {
  final String id;
  final String requestDate;
  final String? reason;
  final int statusId;
  final String statusName;
  final String empName;

  const CompOffItem({
    required this.id,
    required this.requestDate,
    this.reason,
    required this.statusId,
    required this.statusName,
    this.empName = '',
  });

  /// LeaveStatusTypeEnum: 1 Created is still pending.
  bool get canWithdraw => statusId == 1;

  factory CompOffItem.fromJson(Map<String, dynamic> j) => CompOffItem(
        id: j['id']?.toString() ?? '',
        requestDate: _ymd(j['requestDate']) ?? '',
        reason: j['reason'] as String?,
        statusId: (j['leaveStatusTypeId'] as num?)?.toInt() ?? 0,
        statusName: j['leaveStatusTypeName']?.toString() ?? '',
        empName: (j['empName'] ?? '').toString().trim(),
      );
}

/// Goal status ids (PerformanceGoalStatusType).
class GoalStatus {
  GoalStatus._();
  static const int draft = 1;
  static const int submitted = 2;
  static const int approved = 3;
  static const int rejected = 4;
}

/// Review status ids (PerformanceReviewStatusType).
class ReviewStatus {
  ReviewStatus._();
  static const int pending = 1;
  static const int selfDone = 2;
  static const int managerDone = 3;
  static const int finalized = 4;

  static String label(int id) {
    switch (id) {
      case selfDone:
        return 'Self-assessment submitted';
      case managerDone:
        return 'Manager reviewed';
      case finalized:
        return 'Finalized';
      default:
        return 'Pending your self-assessment';
    }
  }
}

const Map<int, String> kRatingLabels = {
  1: 'Needs improvement',
  2: 'Below expectations',
  3: 'Meets expectations',
  4: 'Exceeds expectations',
  5: 'Outstanding',
};

class PerfGoal {
  final int? id;
  final int cycleId;
  final String cycleName;
  final String title;
  final String? description;
  final int goalTypeId;
  final int weight;
  final String? target;
  final String? achieved;
  final int statusId;
  final String statusName;

  const PerfGoal({
    this.id,
    required this.cycleId,
    this.cycleName = '',
    required this.title,
    this.description,
    required this.goalTypeId,
    required this.weight,
    this.target,
    this.achieved,
    this.statusId = GoalStatus.draft,
    this.statusName = '',
  });

  bool get canEdit => statusId == GoalStatus.draft || statusId == GoalStatus.rejected;

  factory PerfGoal.fromJson(Map<String, dynamic> j) => PerfGoal(
        id: (j['id'] as num?)?.toInt(),
        cycleId: (j['cycleId'] as num?)?.toInt() ?? 0,
        cycleName: j['cycleName']?.toString() ?? '',
        title: j['title']?.toString() ?? '',
        description: j['description'] as String?,
        goalTypeId: (j['goalTypeId'] as num?)?.toInt() ?? 1,
        weight: (j['weightPercentage'] as num?)?.toInt() ?? 0,
        target: j['targetValue'] as String?,
        achieved: j['achievedValue'] as String?,
        statusId: (j['goalStatusTypeId'] as num?)?.toInt() ?? GoalStatus.draft,
        statusName: j['goalStatusTypeName']?.toString() ?? '',
      );
}

class PerfReview {
  final int? id;
  final int cycleId;
  final String cycleName;
  final int? selfScore;
  final String? selfComments;
  final int? managerScore;
  final String? managerComments;
  final int? finalScore;
  final String? finalComments;
  final int statusId;

  const PerfReview({
    this.id,
    required this.cycleId,
    this.cycleName = '',
    this.selfScore,
    this.selfComments,
    this.managerScore,
    this.managerComments,
    this.finalScore,
    this.finalComments,
    required this.statusId,
  });

  bool get canSelfAssess => statusId == ReviewStatus.pending;

  factory PerfReview.fromJson(Map<String, dynamic> j) => PerfReview(
        id: (j['id'] as num?)?.toInt(),
        cycleId: (j['cycleId'] as num?)?.toInt() ?? 0,
        cycleName: j['cycleName']?.toString() ?? '',
        selfScore: (j['selfScore'] as num?)?.toInt(),
        selfComments: j['selfComments'] as String?,
        managerScore: (j['managerScore'] as num?)?.toInt(),
        managerComments: j['managerComments'] as String?,
        finalScore: (j['finalScore'] as num?)?.toInt(),
        finalComments: j['finalComments'] as String?,
        statusId: (j['reviewStatusTypeId'] as num?)?.toInt() ?? ReviewStatus.pending,
      );
}

class PerfFeedback {
  final int id;
  final String fromName;
  final String toName;
  final String? category;
  final int rating;
  final String comments;
  final bool isAnonymous;
  final DateTime? createdDate;

  const PerfFeedback({
    required this.id,
    required this.fromName,
    required this.toName,
    this.category,
    required this.rating,
    required this.comments,
    required this.isAnonymous,
    this.createdDate,
  });

  factory PerfFeedback.fromJson(Map<String, dynamic> j) => PerfFeedback(
        id: (j['id'] as num?)?.toInt() ?? 0,
        fromName: (j['fromEmployeeName'] ?? '').toString().trim(),
        toName: (j['toEmployeeName'] ?? '').toString().trim(),
        category: j['category'] as String?,
        rating: (j['rating'] as num?)?.toInt() ?? 0,
        comments: j['comments']?.toString() ?? '',
        isAnonymous: j['isAnonymous'] as bool? ?? false,
        createdDate: DateTime.tryParse(((j['baseListInfo'] as Map<String, dynamic>?)?['createdDate'] ?? '').toString())?.toLocal(),
      );
}

class PerfCycleRef {
  final int id;
  final String name;
  const PerfCycleRef(this.id, this.name);
}

/// Resignation statuses (ResignationStatusTypeEnum).
class ResignationStatus {
  ResignationStatus._();
  static const int draft = 1;
  static const int submitted = 2;
  static const int managerApproved = 3;
  static const int managerRejected = 4;
  static const int hrApproved = 5;
  static const int hrRejected = 6;
  static const int withdrawn = 7;

  static String label(int id) {
    switch (id) {
      case submitted:
        return 'Submitted';
      case managerApproved:
        return 'Manager approved';
      case managerRejected:
        return 'Manager rejected';
      case hrApproved:
        return 'HR approved';
      case hrRejected:
        return 'HR rejected';
      case withdrawn:
        return 'Withdrawn';
      default:
        return 'Draft';
    }
  }
}

class ResignationItem {
  final int? id;
  final String resignationDate;
  final String lastWorkingDate;
  final int noticeDays;
  final String? reason;
  final String? remarks;
  final int statusId;
  final String? managerRemarks;
  final String? hrRemarks;
  final String employeeName;
  final String employeeCode;
  final String department;
  final String designation;

  const ResignationItem({
    this.id,
    required this.resignationDate,
    required this.lastWorkingDate,
    required this.noticeDays,
    this.reason,
    this.remarks,
    this.statusId = ResignationStatus.draft,
    this.managerRemarks,
    this.hrRemarks,
    this.employeeName = '',
    this.employeeCode = '',
    this.department = '',
    this.designation = '',
  });

  bool get canEdit => statusId == ResignationStatus.draft;
  bool get canSubmit => id != null && statusId == ResignationStatus.draft;
  bool get canWithdraw =>
      id != null && (statusId == ResignationStatus.submitted || statusId == ResignationStatus.managerApproved);
  bool get isFinished =>
      statusId == ResignationStatus.withdrawn ||
      statusId == ResignationStatus.managerRejected ||
      statusId == ResignationStatus.hrRejected;

  factory ResignationItem.fromJson(Map<String, dynamic> j) => ResignationItem(
        id: (j['id'] as num?)?.toInt(),
        resignationDate: _ymd(j['resignationDate']) ?? '',
        lastWorkingDate: _ymd(j['lastWorkingDate']) ?? '',
        noticeDays: (j['noticePeriodDays'] as num?)?.toInt() ?? 0,
        reason: j['reasonForLeaving'] as String?,
        remarks: j['additionalRemarks'] as String?,
        statusId: (j['resignationStatusTypeId'] as num?)?.toInt() ?? ResignationStatus.draft,
        managerRemarks: j['managerRemarks'] as String?,
        hrRemarks: j['hrRemarks'] as String?,
        employeeName: (j['employeeName'] ?? '').toString().trim(),
        employeeCode: (j['employeeCode'] ?? '').toString(),
        department: (j['departmentName'] ?? '').toString(),
        designation: (j['designationName'] ?? '').toString(),
      );
}

/// One of my loans (api/v1/emploan/my-loans).
class LoanItem {
  final int id;
  final double amount;
  final String takenOn;
  final double percentage;
  final String payType;
  final double totalPaid;
  final double balance;
  final double emi;
  final String? emiFrom;
  final bool isActive;

  const LoanItem({
    required this.id,
    required this.amount,
    required this.takenOn,
    required this.percentage,
    required this.payType,
    required this.totalPaid,
    required this.balance,
    required this.emi,
    this.emiFrom,
    required this.isActive,
  });

  double get repaidRatio => amount <= 0 ? 0 : (totalPaid / amount).clamp(0.0, 1.0).toDouble();

  factory LoanItem.fromJson(Map<String, dynamic> j) => LoanItem(
        id: (j['id'] as num?)?.toInt() ?? 0,
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        takenOn: _ymd(j['loanTakenOn']) ?? '',
        percentage: (j['percentage'] as num?)?.toDouble() ?? 0,
        payType: j['payTypeName']?.toString() ?? '',
        totalPaid: (j['totalPaid'] as num?)?.toDouble() ?? 0,
        balance: (j['balanceAmount'] as num?)?.toDouble() ?? 0,
        emi: (j['emiAmount'] as num?)?.toDouble() ?? 0,
        emiFrom: _ymd(j['emiEffectiveDate']),
        isActive: j['isActive'] as bool? ?? true,
      );
}

/// One salary revision of mine.
class SalaryRecord {
  final int id;
  final double ctc;
  final double bonus;
  final String effectiveFrom;
  final bool isActive;

  const SalaryRecord({
    required this.id,
    required this.ctc,
    required this.bonus,
    required this.effectiveFrom,
    required this.isActive,
  });

  factory SalaryRecord.fromJson(Map<String, dynamic> j) => SalaryRecord(
        id: (j['id'] as num?)?.toInt() ?? 0,
        ctc: (j['ctc'] as num?)?.toDouble() ?? 0,
        bonus: (j['bonusAmount'] as num?)?.toDouble() ?? 0,
        effectiveFrom: _ymd(j['effectiveFrom']) ?? '',
        isActive: j['isActive'] as bool? ?? false,
      );
}

class SalaryComponent {
  final String name;
  final double amount;
  final bool isEarning;
  final bool excludeFromPayslip;

  const SalaryComponent({
    required this.name,
    required this.amount,
    required this.isEarning,
    required this.excludeFromPayslip,
  });

  factory SalaryComponent.fromJson(Map<String, dynamic> j) => SalaryComponent(
        name: j['salaryComponentName']?.toString() ?? '',
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        isEarning: (j['salaryComponentTypeId'] as num?)?.toInt() == 1,
        excludeFromPayslip: j['excludeInPaySlip'] as bool? ?? false,
      );
}

const Map<int, String> kProficiency = {1: 'Beginner', 2: 'Intermediate', 3: 'Advanced', 4: 'Expert'};

class SkillRef {
  final int id;
  final String name;
  final String category;
  const SkillRef({required this.id, required this.name, required this.category});

  factory SkillRef.fromJson(Map<String, dynamic> j) => SkillRef(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: j['name']?.toString() ?? '',
        category: j['categoryName']?.toString() ?? '',
      );
}

/// One of my skills with a self-rated proficiency (1-4).
class MySkill {
  final int id;
  final int skillId;
  final String skillName;
  final String category;
  final int level;
  final String? notes;

  const MySkill({
    required this.id,
    required this.skillId,
    required this.skillName,
    required this.category,
    required this.level,
    this.notes,
  });

  factory MySkill.fromJson(Map<String, dynamic> j) => MySkill(
        id: (j['id'] as num?)?.toInt() ?? 0,
        skillId: (j['skillId'] as num?)?.toInt() ?? 0,
        skillName: j['skillName']?.toString() ?? '',
        category: j['categoryName']?.toString() ?? '',
        level: (j['proficiencyLevel'] as num?)?.toInt() ?? 1,
        notes: j['notes'] as String?,
      );
}

/// Onboarding task statuses (OnboardingTaskStatus).
class OnbTaskStatus {
  OnbTaskStatus._();
  static const int pending = 1;
  static const int inProgress = 2;
  static const int done = 3;
  static const int skipped = 4;

  static String label(int id) {
    switch (id) {
      case inProgress:
        return 'In progress';
      case done:
        return 'Done';
      case skipped:
        return 'Skipped';
      default:
        return 'Pending';
    }
  }
}

/// An onboarding task assigned to me (or my team).
class OnbTask {
  final int id;
  final int recordId;
  final String title;
  final String? description;
  final String teamName;
  final String candidate;
  final String code;
  final String? dueDate;
  final String? joiningDate;
  final int statusId;
  final String? notes;

  const OnbTask({
    required this.id,
    required this.recordId,
    required this.title,
    this.description,
    required this.teamName,
    required this.candidate,
    required this.code,
    this.dueDate,
    this.joiningDate,
    required this.statusId,
    this.notes,
  });

  bool get isOpen => statusId == OnbTaskStatus.pending || statusId == OnbTaskStatus.inProgress;

  factory OnbTask.fromJson(Map<String, dynamic> j) => OnbTask(
        id: (j['id'] as num?)?.toInt() ?? 0,
        recordId: (j['onboardingRecordId'] as num?)?.toInt() ?? 0,
        title: j['title']?.toString() ?? '',
        description: j['description'] as String?,
        teamName: j['assignedTeamName']?.toString() ?? '',
        candidate: j['candidateName']?.toString() ?? '',
        code: j['onboardingCode']?.toString() ?? '',
        dueDate: _ymd(j['dueDate']),
        joiningDate: _ymd(j['joiningDate']),
        statusId: (j['taskStatusTypeId'] as num?)?.toInt() ?? OnbTaskStatus.pending,
        notes: j['completionNotes'] as String?,
      );
}

/// A published Form 16 for one financial year.
class Form16Item {
  final int fyId;
  final String label;
  final DateTime? publishedOn;
  final double tdsDeducted;
  final bool isProjected;

  const Form16Item({
    required this.fyId,
    required this.label,
    this.publishedOn,
    required this.tdsDeducted,
    required this.isProjected,
  });

  factory Form16Item.fromJson(Map<String, dynamic> j) => Form16Item(
        fyId: (j['taxFinancialYearId'] as num?)?.toInt() ?? 0,
        label: (j['fyLabel'] ?? j['fYLabel'] ?? 'FY ${j['taxFinancialYearId']}').toString(),
        publishedOn: DateTime.tryParse(j['publishedOn']?.toString() ?? '')?.toLocal(),
        tdsDeducted: ((j['totalTDSDeducted'] ?? j['totalTdsDeducted']) as num?)?.toDouble() ?? 0,
        isProjected: (j['tdsIsProjected'] ?? j['tDSIsProjected']) as bool? ?? false,
      );
}

/// A submitted timesheet waiting for review.
class TimesheetReviewItem {
  final int id;
  final String empName;
  final String? empCode;
  final String fromDate;
  final String toDate;
  final num totalHours;
  final num billableHours;

  const TimesheetReviewItem({
    required this.id,
    required this.empName,
    this.empCode,
    required this.fromDate,
    required this.toDate,
    required this.totalHours,
    required this.billableHours,
  });

  factory TimesheetReviewItem.fromJson(Map<String, dynamic> j) => TimesheetReviewItem(
        id: (j['id'] as num?)?.toInt() ?? 0,
        empName: (j['empName'] ?? '').toString().trim(),
        empCode: j['empCode'] as String?,
        fromDate: _ymd(j['fromDate']) ?? '',
        toDate: _ymd(j['toDate']) ?? '',
        totalHours: j['totalHours'] as num? ?? 0,
        billableHours: j['billableHours'] as num? ?? 0,
      );
}

/// A late-arrival record waiting for HR/manager resolution.
class LateEntryItem {
  final int id;
  final String empName;
  final String? empCode;
  final String date;
  final String? shiftName;
  final int lateByMinutes;
  final int statusId;
  final String statusName;

  const LateEntryItem({
    required this.id,
    required this.empName,
    this.empCode,
    required this.date,
    this.shiftName,
    required this.lateByMinutes,
    required this.statusId,
    required this.statusName,
  });

  bool get isPending => statusId == 1;

  factory LateEntryItem.fromJson(Map<String, dynamic> j) => LateEntryItem(
        id: (j['id'] as num?)?.toInt() ?? 0,
        empName: (j['empName'] ?? '').toString().trim(),
        empCode: j['empCode'] as String?,
        date: _ymd(j['attendanceDate']) ?? '',
        shiftName: j['shiftName'] as String?,
        lateByMinutes: (j['lateByMinutes'] as num?)?.toInt() ?? 0,
        statusId: (j['statusTypeId'] as num?)?.toInt() ?? 0,
        statusName: j['statusTypeName']?.toString() ?? '',
      );
}

class TicketComment {
  final int id;
  final int empId;
  final String text;
  final DateTime? at;
  const TicketComment({required this.id, required this.empId, required this.text, this.at});

  factory TicketComment.fromJson(Map<String, dynamic> j) => TicketComment(
        id: (j['historyId'] as num?)?.toInt() ?? 0,
        empId: (j['empId'] as num?)?.toInt() ?? 0,
        text: j['description']?.toString() ?? '',
        at: DateTime.tryParse(j['createdDate']?.toString() ?? '')?.toLocal(),
      );
}

class TicketApprovalRow {
  final String name;
  final String action;
  final DateTime? at;
  const TicketApprovalRow({required this.name, required this.action, this.at});

  factory TicketApprovalRow.fromJson(Map<String, dynamic> j) => TicketApprovalRow(
        name: (j['empName'] ?? '').toString().trim(),
        action: j['ticketActionTypeName']?.toString() ?? '',
        at: DateTime.tryParse(j['actionDate']?.toString() ?? '')?.toLocal(),
      );
}

/// Live detail of a ticket (status, assignee, conversation, approvals).
class TicketActivity {
  final int id;
  final String ticketNo;
  final String subject;
  final String requester;
  final String assignee;
  final int? statusId;
  final String statusName;
  final String priority;
  final String category;
  final List<TicketComment> comments;
  final List<TicketApprovalRow> approvals;
  final List<TicketAttachment> attachments;

  const TicketActivity({
    required this.id,
    required this.ticketNo,
    required this.subject,
    required this.requester,
    required this.assignee,
    this.statusId,
    required this.statusName,
    required this.priority,
    required this.category,
    required this.comments,
    required this.approvals,
    this.attachments = const [],
  });

  factory TicketActivity.fromJson(Map<String, dynamic> j) => TicketActivity(
        id: (j['id'] as num?)?.toInt() ?? 0,
        ticketNo: j['ticketNo']?.toString() ?? '',
        subject: j['subject']?.toString() ?? '',
        requester: (j['employeeName'] ?? '').toString().trim(),
        assignee: (j['assignedEmpName'] ?? '').toString().trim(),
        statusId: (j['ticketStatusId'] as num?)?.toInt(),
        statusName: j['ticketStatusName']?.toString() ?? '',
        priority: j['priorityText']?.toString() ?? '',
        category: j['ticketCategoryName']?.toString() ?? '',
        comments: (j['history'] as List<dynamic>? ?? [])
            .map((e) => TicketComment.fromJson(e as Map<String, dynamic>))
            .toList(),
        approvals: (j['approvals'] as List<dynamic>? ?? [])
            .map((e) => TicketApprovalRow.fromJson(e as Map<String, dynamic>))
            .toList(),
        attachments: (j['attachments'] as List<dynamic>? ?? [])
            .map((e) => TicketAttachment.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class TicketAttachment {
  final int id;
  final String fileName;
  final String uploadedBy;
  final DateTime? at;

  const TicketAttachment({required this.id, required this.fileName, this.uploadedBy = '', this.at});

  factory TicketAttachment.fromJson(Map<String, dynamic> j) => TicketAttachment(
        id: (j['attachmentId'] as num?)?.toInt() ?? 0,
        fileName: (j['fileName'] ?? j['attachment'] ?? 'Attachment').toString(),
        uploadedBy: j['uploadedByName']?.toString() ?? '',
        at: DateTime.tryParse(j['uploadedDate']?.toString() ?? ''),
      );
}

/// A job opening (api/v1/jobpost).
class JobOpening {
  final int id;
  final String uniqueId;
  final String name;
  final String position;
  final String location;
  final num openings;
  final String? driveStart;
  final String? driveEnd;

  const JobOpening({
    required this.id,
    required this.uniqueId,
    required this.name,
    required this.position,
    required this.location,
    required this.openings,
    this.driveStart,
    this.driveEnd,
  });

  factory JobOpening.fromJson(Map<String, dynamic> j) => JobOpening(
        id: (j['id'] as num?)?.toInt() ?? 0,
        uniqueId: j['uniqueId']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        position: j['position']?.toString() ?? '',
        location: j['location']?.toString() ?? '',
        openings: j['noOfOpenings'] as num? ?? 0,
        driveStart: _ymd(j['driveStartDate']),
        driveEnd: _ymd(j['driveEndDate']),
      );
}

class JobCandidate {
  final String uniqueNo;
  final String name;
  final String email;
  final String? phone;
  final double? currentCtc;
  final double? expectedCtc;
  final double? score;

  const JobCandidate({
    required this.uniqueNo,
    required this.name,
    required this.email,
    this.phone,
    this.currentCtc,
    this.expectedCtc,
    this.score,
  });

  factory JobCandidate.fromJson(Map<String, dynamic> j) => JobCandidate(
        uniqueNo: j['uniqueNo']?.toString() ?? '',
        name: (j['name'] ?? '').toString().trim(),
        email: j['email']?.toString() ?? '',
        phone: j['phoneNo'] as String?,
        currentCtc: (j['currentCtc'] as num?)?.toDouble(),
        expectedCtc: (j['expectedCtc'] as num?)?.toDouble(),
        score: (j['score'] as num?)?.toDouble(),
      );
}

class OfferItem {
  final int id;
  final String code;
  final String candidate;
  final String position;
  final String? department;
  final String joiningDate;
  final double ctc;
  final String statusName;
  final String validUntil;

  const OfferItem({
    required this.id,
    required this.code,
    required this.candidate,
    required this.position,
    this.department,
    required this.joiningDate,
    required this.ctc,
    required this.statusName,
    required this.validUntil,
  });

  factory OfferItem.fromJson(Map<String, dynamic> j) => OfferItem(
        id: (j['id'] as num?)?.toInt() ?? 0,
        code: j['offerCode']?.toString() ?? '',
        candidate: j['candidateName']?.toString() ?? '',
        position: j['position']?.toString() ?? '',
        department: j['department'] as String?,
        joiningDate: _ymd(j['joiningDate']) ?? '',
        ctc: (j['offeredCtc'] as num?)?.toDouble() ?? 0,
        statusName: j['offerStatusName']?.toString() ?? '',
        validUntil: _ymd(j['validUntil']) ?? '',
      );
}

/// A person in the org chart tree (api/v1/orgchart/{id}).
class OrgNode {
  final int id;
  final String name;
  final String designation;
  final String department;
  final String? email;
  final String? mobile;
  final List<OrgNode> children;

  const OrgNode({
    required this.id,
    required this.name,
    required this.designation,
    required this.department,
    this.email,
    this.mobile,
    this.children = const [],
  });

  factory OrgNode.fromJson(Map<String, dynamic> j) => OrgNode(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: [j['firstName'], j['middleName'], j['lastName']]
            .where((e) => (e ?? '').toString().trim().isNotEmpty)
            .join(' '),
        designation: j['designation']?.toString() ?? '',
        department: j['department']?.toString() ?? '',
        email: j['emailId'] as String?,
        mobile: j['mobileNo'] as String?,
        children: (j['children'] as List<dynamic>? ?? [])
            .map((e) => OrgNode.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// Depth-first search for [targetId] in this subtree.
  OrgNode? find(int targetId) {
    if (id == targetId) return this;
    for (final c in children) {
      final hit = c.find(targetId);
      if (hit != null) return hit;
    }
    return null;
  }
}

/// A weekly off rule from the business unit (api/v1/profile/weekOffs).
class WeekOffRule {
  final int weekday; // DateTime.monday..sunday
  final bool alternate;
  final List<int> weeks; // 1-based week-of-month that are OFF when [alternate]

  const WeekOffRule({required this.weekday, required this.alternate, required this.weeks});

  static const _names = {
    'monday': DateTime.monday,
    'tuesday': DateTime.tuesday,
    'wednesday': DateTime.wednesday,
    'thursday': DateTime.thursday,
    'friday': DateTime.friday,
    'saturday': DateTime.saturday,
    'sunday': DateTime.sunday,
  };

  static WeekOffRule? tryParse(dynamic j) {
    if (j is String) {
      final d = _names[j.toLowerCase()];
      return d == null ? null : WeekOffRule(weekday: d, alternate: false, weeks: const []);
    }
    if (j is Map<String, dynamic>) {
      final d = _names[(j['day'] ?? '').toString().toLowerCase()];
      if (d == null) return null;
      final type = (j['type'] ?? '').toString().toLowerCase();
      return WeekOffRule(
        weekday: d,
        alternate: type.contains('alt'),
        weeks: (j['weeks'] as List<dynamic>? ?? []).map((e) => (e as num).toInt()).toList(),
      );
    }
    return null;
  }

  bool isOff(DateTime d) {
    if (d.weekday != weekday) return false;
    if (!alternate) return true;
    final weekOfMonth = ((d.day - 1) ~/ 7) + 1;
    return weeks.contains(weekOfMonth);
  }
}

// ---- Performance depth: key results, 360° feedback, competency ratings ----

abstract class KrStatus {
  static const onTrack = 1, atRisk = 2, behind = 3, completed = 4;
  static String label(int id) => switch (id) {
        onTrack => 'On track',
        atRisk => 'At risk',
        behind => 'Behind',
        completed => 'Completed',
        _ => 'On track',
      };
}

class PerfKeyResult {
  final int id;
  final int goalId;
  final String title;
  final String? unit;
  final double start;
  final double target;
  final double current;
  final int statusId;

  const PerfKeyResult({
    required this.id,
    required this.goalId,
    required this.title,
    this.unit,
    this.start = 0,
    this.target = 0,
    this.current = 0,
    this.statusId = KrStatus.onTrack,
  });

  /// 0..1, clamped; the server's own formula (current-start)/(target-start).
  double get progress {
    final span = target - start;
    if (span == 0) return 0;
    return ((current - start) / span).clamp(0.0, 1.0);
  }

  factory PerfKeyResult.fromJson(Map<String, dynamic> j) => PerfKeyResult(
        id: (j['id'] as num?)?.toInt() ?? 0,
        goalId: (j['goalId'] as num?)?.toInt() ?? 0,
        title: j['title']?.toString() ?? '',
        unit: j['unit']?.toString(),
        start: (j['startValue'] as num?)?.toDouble() ?? 0,
        target: (j['targetValue'] as num?)?.toDouble() ?? 0,
        current: (j['currentValue'] as num?)?.toDouble() ?? 0,
        statusId: (j['krStatusTypeId'] as num?)?.toInt() ?? KrStatus.onTrack,
      );
}

class Perf360Feedback {
  final String reviewer;
  final String reviewerType;
  final double? score;
  final String? strengths;
  final String? improvements;
  final String? comments;
  final bool submitted;

  const Perf360Feedback({
    required this.reviewer,
    required this.reviewerType,
    this.score,
    this.strengths,
    this.improvements,
    this.comments,
    this.submitted = false,
  });

  factory Perf360Feedback.fromJson(Map<String, dynamic> j) => Perf360Feedback(
        reviewer: j['reviewerEmployeeName']?.toString() ?? '',
        reviewerType: j['reviewerTypeName']?.toString() ?? '',
        score: (j['overallScore'] as num?)?.toDouble(),
        strengths: j['strengths']?.toString(),
        improvements: j['improvements']?.toString(),
        comments: j['comments']?.toString(),
        // Drafts are the reviewer's own; anything past status 1 has been submitted.
        submitted: ((j['feedbackStatusTypeId'] as num?)?.toInt() ?? 1) > 1,
      );
}

class CompetencyRating {
  final String name;
  final String group;
  final int value;
  final String? comments;

  const CompetencyRating({required this.name, required this.group, required this.value, this.comments});

  factory CompetencyRating.fromJson(Map<String, dynamic> j) => CompetencyRating(
        name: j['competencyName']?.toString() ?? '',
        group: j['groupName']?.toString() ?? '',
        value: (j['ratingValue'] as num?)?.toInt() ?? 0,
        comments: j['comments']?.toString(),
      );
}
