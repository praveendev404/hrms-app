import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';


import '../../core/errors/exceptions.dart';
import '../../core/network/api_client.dart';
import '../models/dropdown_option_model.dart';
import '../models/extras_models.dart';
import '../models/leave_models.dart';
import '../models/work_models.dart';

/// Feed, who's-out-today, assets and learning.
class ExtrasRemoteDataSource {
  final ApiClient _api;
  ExtrasRemoteDataSource(this._api);

  List<Map<String, dynamic>> _list(dynamic data) =>
      ((data as Map<String, dynamic>)['list'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

  // ---- Feed ----

  Future<List<FeedPost>> getFeed({int pageSize = 20}) async {
    final r = await _api.post('/api/v1/feed/getall', data: {
      'pageModel': {'startIndex': 0, 'pageSize': pageSize},
    });
    final raw = r.data;
    final items = raw is List ? raw : (raw as Map<String, dynamic>)['list'] as List<dynamic>? ?? [];
    return items.map((e) => FeedPost.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Posts a feed item. The API takes multipart form data with the JSON in a `model` field
  /// (one optional attachment). [feedTypeId]: 1 post, 2 announcement.
  Future<ActionResult> createFeed({
    required String header,
    required String body,
    required int feedTypeId,
    String? expireDate,
    bool notifyEmployees = false,
    File? attachment,
  }) async {
    final r = await _api.uploadFilesWithModel(
      '/api/v1/feed',
      modelJson: jsonEncode({
        'header': header,
        'body': body,
        'feedTypeId': feedTypeId,
        'expireDate': expireDate,
        'isNotifyEmployee': notifyEmployees,
      }),
      files: attachment == null ? null : [attachment],
    );
    return ActionResult.fromJson(r.data);
  }

  /// Toggles my Like (reaction type 1): the server removes the reaction when the same
  /// type is posted again.
  Future<ActionResult> like({required int feedId, required int employeeId}) async {
    final r = await _api.post('/api/v1/feed/$feedId/reaction', data: {
      'feedId': feedId,
      'employeeId': employeeId,
      'reactionTypeId': 1,
    });
    return ActionResult.fromJson(r.data);
  }

  Future<List<FeedComment>> getComments(int feedId) async {
    final r = await _api.post('/api/v1/feed/$feedId/comment/getall', data: <String, dynamic>{});
    final list = (r.data is Map<String, dynamic> ? (r.data as Map<String, dynamic>)['list'] : r.data) as List<dynamic>? ?? [];
    return list.map((e) => FeedComment.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ActionResult> addComment({required int feedId, required int employeeId, required String text}) async {
    final r = await _api.post('/api/v1/feed/$feedId/comment', data: {
      'feedId': feedId,
      'employeeId': employeeId,
      'comment': text,
    });
    return ActionResult.fromJson(r.data);
  }

  // ---- Who's out today ----

  /// The web widget asks the leave list with today's date as the keyword.
  Future<List<LeaveRequest>> getOutToday() async {
    final n = DateTime.now();
    final r = await _api.post('/api/v1/leave/getall', data: {
      'pageModel': {'startIndex': 0, 'pageSize': 20, 'keyWord': '${n.year}-${n.month}-${n.day}'},
    });
    // The list also holds pending, rejected and cancelled requests; only approved leave means "out".
    return _list(r.data).map(LeaveRequest.fromJson).where((l) => l.statusId == LeaveStatus.approved).toList();
  }

  // ---- Assets ----

  Future<List<AssetItem>> getMyAssets() async {
    final r = await _api.post('/api/v1/asset/my-assets', data: {
      'pageModel': {'startIndex': 0, 'pageSize': 100},
    });
    return _list(r.data).map(AssetItem.fromJson).toList();
  }

  // ---- Learning ----

  Future<List<CourseEnrollment>> getMyEnrollments() async {
    final r = await _api.get('/api/v1/learning/my-enrollments');
    return (r.data as List<dynamic>? ?? [])
        .map((e) => CourseEnrollment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<CatalogCourse>> getCatalog() async {
    final r = await _api.get('/api/v1/learning/catalog');
    return (r.data as List<dynamic>? ?? [])
        .map((e) => CatalogCourse.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ActionResult> selfEnroll(int courseId) async {
    final r = await _api.post('/api/v1/learning/self-enroll', data: {'courseId': courseId});
    return ActionResult.fromJson(r.data);
  }

  // ---- Performance summary ----

  /// Built from my own goals and reviews (employee-readable). `cycle/getall` needs the
  /// PerformanceManage permission, so it is not used here.
  Future<PerformanceSummary?> getPerformanceSummary() async {
    final goals = await getMyGoals();
    final reviews = await getMyReviews();
    if (goals.isEmpty && reviews.isEmpty) return null;

    // The newest cycle I have a review or goals in.
    final cycleId = [...reviews.map((r) => r.cycleId), ...goals.map((g) => g.cycleId)]
        .fold<int>(0, (m, v) => v > m ? v : m);
    final cycleGoals = goals.where((g) => g.cycleId == cycleId).toList();
    final review = reviews.where((r) => r.cycleId == cycleId).toList();
    final name = review.isNotEmpty && review.first.cycleName.isNotEmpty
        ? review.first.cycleName
        : (cycleGoals.isNotEmpty ? cycleGoals.first.cycleName : 'Current cycle');

    return PerformanceSummary(
      cycleName: name,
      cycleStatusId: 0,
      cycleStatusName: '',
      totalGoals: cycleGoals.length,
      approvedGoals: cycleGoals.where((g) => g.statusId == GoalStatus.approved).length,
      reviewStatusId: review.isEmpty ? null : review.first.statusId,
    );
  }

  // ---- Performance: goals ----

  Future<List<PerfGoal>> getMyGoals() async {
    final r = await _api.post('/api/v1/performance/goal/getall', data: {
      'pageModel': {'startIndex': 0, 'pageSize': 200},
    });
    return _list(r.data).map(PerfGoal.fromJson).toList();
  }

  Future<ActionResult> saveGoal(PerfGoal g, int employeeId) async {
    final model = {
      if (g.id != null) 'id': g.id,
      'cycleId': g.cycleId,
      'employeeId': employeeId,
      'title': g.title,
      'description': g.description,
      'goalTypeId': g.goalTypeId,
      'weightPercentage': g.weight,
      'targetValue': g.target,
      'achievedValue': g.achieved,
      'goalStatusTypeId': g.id == null ? GoalStatus.draft : g.statusId,
    };
    final r = g.id == null
        ? await _api.post('/api/v1/performance/goal', data: {'model': model})
        : await _api.put('/api/v1/performance/goal', data: {'model': model});
    return ActionResult.fromJson(r.data);
  }

  Future<ActionResult> setGoalStatus(int id, int statusId) async {
    final r = await _api.put('/api/v1/performance/goal/$id/status/$statusId', data: <String, dynamic>{});
    return ActionResult.fromJson(r.data);
  }

  /// Cycles I can attach goals to. `cycle/getall` is admin-only, so fall back to the
  /// cycles seen on my own goals and reviews.
  Future<List<PerfCycleRef>> getKnownCycles() async {
    final seen = <int, String>{};
    try {
      final r = await _api.post('/api/v1/performance/cycle/getall', data: {
        'pageModel': {'startIndex': 0, 'pageSize': 20},
      });
      for (final c in _list(r.data)) {
        final st = (c['cycleStatusTypeId'] as num?)?.toInt() ?? 0;
        if (st >= 2 && st <= 4) seen[(c['id'] as num).toInt()] = c['name']?.toString() ?? 'Cycle';
      }
    } catch (_) {}
    for (final g in await getMyGoals()) {
      if (g.cycleId > 0) seen.putIfAbsent(g.cycleId, () => g.cycleName);
    }
    for (final v in await getMyReviews()) {
      if (v.cycleId > 0) seen.putIfAbsent(v.cycleId, () => v.cycleName);
    }
    return seen.entries.map((e) => PerfCycleRef(e.key, e.value)).toList()
      ..sort((a, b) => b.id.compareTo(a.id));
  }

  // ---- Performance: key results, 360, competencies ----

  Future<List<PerfKeyResult>> getKeyResults(int goalId) async {
    final r = await _api.get('/api/v1/performance/keyresult/goal/$goalId');
    return _list(r.data).map(PerfKeyResult.fromJson).toList();
  }

  Future<ActionResult> saveKeyResult(PerfKeyResult k) async {
    final model = {
      if (k.id != 0) 'id': k.id,
      'goalId': k.goalId,
      'title': k.title,
      'unit': k.unit,
      'startValue': k.start,
      'targetValue': k.target,
      'currentValue': k.current,
      'krStatusTypeId': k.statusId,
    };
    final r = k.id == 0
        ? await _api.post('/api/v1/performance/keyresult', data: {'model': model})
        : await _api.put('/api/v1/performance/keyresult', data: {'model': model});
    return ActionResult.fromJson(r.data);
  }

  Future<ActionResult> updateKeyResultProgress(int id, double current, int statusId) async {
    final r = await _api.put('/api/v1/performance/keyresult/progress',
        data: {'id': id, 'currentValue': current, 'krStatusTypeId': statusId});
    return ActionResult.fromJson(r.data);
  }

  Future<ActionResult> deleteKeyResult(int id) async {
    final r = await _api.delete('/api/v1/performance/keyresult/$id');
    return ActionResult.fromJson(r.data);
  }

  Future<List<Perf360Feedback>> get360(int reviewId) async {
    final r = await _api.get('/api/v1/performance/360/review/$reviewId');
    return _list(r.data).map(Perf360Feedback.fromJson).toList();
  }

  Future<List<CompetencyRating>> getCompetencyRatings(int reviewId) async {
    final r = await _api.get('/api/v1/performance/competency/ratings/$reviewId');
    return _list(r.data).map(CompetencyRating.fromJson).toList();
  }

  // ---- Performance: reviews ----

  Future<List<PerfReview>> getMyReviews() async {
    final r = await _api.post('/api/v1/performance/review/my', data: <String, dynamic>{});
    return _list(r.data).map(PerfReview.fromJson).toList();
  }

  Future<ActionResult> submitSelfAssessment({
    required PerfReview review,
    required int employeeId,
    required int score,
    required String comments,
  }) async {
    final model = {
      if (review.id != null) 'id': review.id,
      'cycleId': review.cycleId,
      'employeeId': employeeId,
      'selfScore': score,
      'selfComments': comments,
      'reviewStatusTypeId': ReviewStatus.selfDone,
    };
    final r = review.id != null
        ? await _api.put('/api/v1/performance/review', data: {'model': model})
        : await _api.post('/api/v1/performance/review', data: {'model': model});
    return ActionResult.fromJson(r.data);
  }

  // ---- Performance: feedback ----

  Future<List<PerfFeedback>> getFeedback({required bool received}) async {
    final r = await _api.post(
      '/api/v1/performance/feedback/${received ? 'received' : 'given'}',
      data: {'pageModel': {'startIndex': 0, 'pageSize': 50}},
    );
    return _list(r.data).map(PerfFeedback.fromJson).toList();
  }

  Future<ActionResult> giveFeedback({
    required int fromEmployeeId,
    required int toEmployeeId,
    required String category,
    required int rating,
    required String comments,
    required bool anonymous,
  }) async {
    final r = await _api.post('/api/v1/performance/feedback', data: {
      'model': {
        'fromEmployeeId': fromEmployeeId,
        'toEmployeeId': toEmployeeId,
        'category': category,
        'rating': rating,
        'comments': comments,
        'isAnonymous': anonymous,
      },
    });
    return ActionResult.fromJson(r.data);
  }

  // ---- My attendance ----

  /// The self-service month view. (`getAllOrgAttendance` is the HR pivot and needs
  /// the AttendanceManage permission, so it is not usable for a regular employee.)
  Future<List<AttendanceDay>> getMyAttendance(DateTime month) async {
    final m = month.month.toString().padLeft(2, '0');
    final r = await _api.post('/api/v1/attendence/getdetailAttendence', data: {
      'date': '${month.year}-$m-01',
    });
    return (r.data as List<dynamic>? ?? [])
        .map((e) => AttendanceDay.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---- Timesheet entry ----

  /// The tenant's first day of the week (0 = Sunday ... 6 = Saturday); Monday when unknown.
  Future<int> getWeekStartDay() async {
    try {
      final r = await _api.get('/api/v1/org/localization');
      final d = r.data;
      if (d is Map<String, dynamic>) {
        final direct = d['weekStartDay'];
        final nested = (d['profile'] is Map<String, dynamic>) ? (d['profile'] as Map<String, dynamic>)['weekStartDay'] : null;
        final v = direct ?? nested;
        if (v is num) return v.toInt();
      }
    } catch (_) {}
    return 1;
  }

  /// Opens (or creates) my timesheet for the week. The server answers a BaseResponse with
  /// success=false for refusals (e.g. an account with no employee record).
  Future<TimesheetSheet> getOrCreateWeek({required String fromDate, required String toDate}) async {
    final r = await _api.post('/api/v1/timesheet/week', data: {
      'fromDate': fromDate,
      'toDate': toDate,
      'timesheetStatusTypeId': 0,
      'managerId': 0,
    });
    final d = r.data;
    if (d is Map<String, dynamic>) {
      if (d['success'] == false) {
        throw ServerException(message: d['message']?.toString() ?? 'Could not open this timesheet.');
      }
      return TimesheetSheet.fromJson(d);
    }
    throw const ServerException(message: 'Unexpected timesheet response.');
  }

  Future<List<WorkLog>> getWorkLogs(int timesheetId) async {
    final r = await _api.post('/api/v1/timesheet/$timesheetId/WorkLog/getall', data: <String, dynamic>{});
    return _list(r.data).map(WorkLog.fromJson).toList();
  }

  Future<ActionResult> saveWorkLog({
    required int timesheetId,
    required int employeeId,
    required String weekFrom,
    required String weekTo,
    required WorkLog log,
  }) async {
    final body = {
      if (log.id != null) 'id': log.id,
      'timesheetId': timesheetId,
      'employeeId': employeeId,
      'fromDate': weekFrom,
      'toDate': weekTo,
      'projectId': log.projectId,
      'workLogTypeId': log.workLogTypeId,
      'date': log.date,
      'duration': log.hours,
      'taskNumber': log.taskNumber,
      'comments': log.comments,
      'isBillable': log.isBillable,
    };
    final url = '/api/v1/timesheet/$timesheetId/WorkLog';
    final r = log.id == null ? await _api.post(url, data: body) : await _api.put(url, data: body);
    return ActionResult.fromJson(r.data);
  }

  /// What copying onto [targetDate] would bring (the previous worked day unless [sourceDate]).
  Future<({bool ok, String message, String? sourceDate, List<WorkLog> logs, int hours})> getCopyPreview(
    int timesheetId,
    String targetDate,
  ) async {
    final r = await _api.get(
      '/api/v1/timesheet/$timesheetId/WorkLog/copy-source',
      queryParameters: {'targetDate': targetDate},
    );
    final d = r.data as Map<String, dynamic>;
    final list = (d['list'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    return (
      ok: d['success'] != false,
      message: d['message']?.toString() ?? '',
      sourceDate: d['sourceDate']?.toString().substring(0, 10),
      logs: list.map(WorkLog.fromJson).toList(),
      hours: (d['totalHours'] as num?)?.toInt() ?? 0,
    );
  }

  /// [mode] is 'day' (needs [targetDate], optional [sourceDate]) or 'week' (last week -> this sheet).
  Future<ActionResult> copyWorkLogs(
    int timesheetId, {
    required String mode,
    String? sourceDate,
    String? targetDate,
  }) async {
    final r = await _api.post('/api/v1/timesheet/$timesheetId/WorkLog/copy', data: {
      'mode': mode,
      if (sourceDate != null) 'sourceDate': sourceDate,
      if (targetDate != null) 'targetDate': targetDate,
    });
    return ActionResult.fromJson(r.data);
  }

  /// Submit = status 2, withdraw = status 1 (same as the web's employee log).
  Future<ActionResult> setTimesheetStatus(int timesheetId, int statusTypeId, String remarks) async {
    final r = await _api.post('/api/v1/timesheet/$timesheetId/AddWfLog', data: {
      'timesheetStatusTypeId': statusTypeId,
      'remarks': remarks,
    });
    return ActionResult.fromJson(r.data);
  }

  Future<List<DropdownOptionModel>> getOptions(String type) async {
    final r = await _api.get('/api/v1/admin/GetParentOptions/$type');
    return (r.data as List<dynamic>? ?? [])
        .map((e) => DropdownOptionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---- Org chart & week-offs ----

  /// Manager (if any) on top, then the person with their reports nested below.
  Future<OrgNode?> getOrgChart(int employeeId) async {
    final r = await _api.get('/api/v1/orgchart/$employeeId');
    final list = r.data as List<dynamic>? ?? [];
    if (list.isEmpty) return null;
    return OrgNode.fromJson(list.first as Map<String, dynamic>);
  }

  Future<List<WeekOffRule>> getWeekOffs() async {
    final r = await _api.get('/api/v1/profile/weekOffs');
    final data = r.data;
    final list = data is List ? data : (data is Map<String, dynamic> ? (data['list'] as List<dynamic>? ?? []) : []);
    return list.map(WeekOffRule.tryParse).whereType<WeekOffRule>().toList();
  }

  // ---- My skills ----

  Future<List<MySkill>> getMySkills(int employeeId) async {
    final r = await _api.get('/api/v1/skill-matrix/employee/$employeeId/skills');
    return (r.data as List<dynamic>? ?? []).map((e) => MySkill.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<SkillRef>> getSkillCatalog() async {
    final r = await _api.get('/api/v1/skill-matrix/skills');
    return (r.data as List<dynamic>? ?? []).map((e) => SkillRef.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ActionResult> saveMySkill({
    int? id,
    required int employeeId,
    required int skillId,
    required int level,
    String? notes,
  }) async {
    final r = await _api.post('/api/v1/skill-matrix/employee-skills', data: {
      'model': {
        'id': id ?? 0,
        'employeeId': employeeId,
        'skillId': skillId,
        'proficiencyLevel': level,
        'notes': notes,
      },
    });
    return ActionResult.fromJson(r.data);
  }

  Future<ActionResult> deleteMySkill(int id) async {
    final r = await _api.delete('/api/v1/skill-matrix/employee-skills/$id');
    return ActionResult.fromJson(r.data);
  }

  // ---- Onboarding tasks ----

  Future<List<OnbTask>> getMyOnboardingTasks() async {
    final r = await _api.get('/api/v1/onboarding/my-tasks');
    return (r.data as List<dynamic>? ?? []).map((e) => OnbTask.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ActionResult> setOnboardingTaskStatus(OnbTask t, int statusId, {String? notes}) async {
    final r = await _api.put('/api/v1/onboarding/${t.recordId}/tasks/${t.id}/status', data: {
      'taskStatusTypeId': statusId,
      if (notes != null && notes.isNotEmpty) 'completionNotes': notes,
    });
    return ActionResult.fromJson(r.data);
  }

  // ---- My finance ----

  Future<List<LoanItem>> getMyLoans() async {
    final r = await _api.post('/api/v1/emploan/my-loans', data: {
      'pageModel': {'startIndex': 0, 'pageSize': 50},
    });
    return _list(r.data).map(LoanItem.fromJson).toList();
  }

  Future<List<SalaryRecord>> getMySalaries() async {
    final r = await _api.post('/api/v1/empsaldetail/GetMySalaryDetails', data: {
      'pageModel': {'startIndex': 0, 'pageSize': 20},
    });
    return _list(r.data).map(SalaryRecord.fromJson).toList();
  }

  Future<List<SalaryComponent>> getSalaryBreakup(int salaryDetailId) async {
    final r = await _api.get('/api/v1/empsalcomp/$salaryDetailId');
    final comps = (r.data as Map<String, dynamic>)['empSalComponents'] as List<dynamic>? ?? [];
    return comps.map((e) => SalaryComponent.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ---- Recruitment (read-only) ----

  Future<List<JobOpening>> getJobOpenings() async {
    final r = await _api.post('/api/v1/jobpost/getall', data: {
      'pageModel': {'startIndex': 0, 'pageSize': 100},
    });
    return _list(r.data).map(JobOpening.fromJson).toList();
  }

  Future<List<JobCandidate>> getJobCandidates(String jobUniqueId) async {
    final r = await _api.post('/api/v1/jobpostcandidate/$jobUniqueId/getall', data: {
      'pageModel': {'startIndex': 0, 'pageSize': 200},
    });
    return _list(r.data).map(JobCandidate.fromJson).toList();
  }

  Future<List<OfferItem>> getOffers() async {
    final r = await _api.post('/api/v1/offers/getall', data: {
      'pageModel': {'startIndex': 0, 'pageSize': 100},
    });
    return _list(r.data).map(OfferItem.fromJson).toList();
  }

  // ---- Helpdesk activity ----

  Future<TicketActivity> getTicketActivity(int ticketId) async {
    final r = await _api.get('/api/v1/ticket/$ticketId/detailInfo');
    return TicketActivity.fromJson(r.data as Map<String, dynamic>);
  }

  /// One file per call (the server keeps the last file of a request).
  Future<ActionResult> addTicketAttachment(int ticketId, File file) async {
    final r = await _api.uploadFile('/api/v1/ticket/$ticketId/attachment/add', file: file, fieldName: 'file');
    return ActionResult.fromJson(r.data);
  }

  Future<ActionResult> removeTicketAttachment(int ticketId, int attachmentId) async {
    final r = await _api.post('/api/v1/ticket/$ticketId/attachment/$attachmentId/remove', data: <String, dynamic>{});
    return ActionResult.fromJson(r.data);
  }

  /// Downloads an attachment to a temp file and returns its path.
  Future<String> downloadTicketAttachment(int ticketId, TicketAttachment a) async {
    final r = await _api.get<List<int>>(
      '/api/v1/ticket/$ticketId/attachment/${a.id}/download',
      options: Options(responseType: ResponseType.bytes),
    );
    final dir = await getTemporaryDirectory();
    final safe = a.fileName.replaceAll(RegExp(r'[^\w.\- ]'), '_');
    final file = File('${dir.path}${Platform.pathSeparator}${a.id}_$safe');
    await file.writeAsBytes(r.data ?? const []);
    return file.path;
  }

  Future<ActionResult> addTicketComment(int ticketId, String text) async {
    final r = await _api.post('/api/v1/ticket/$ticketId/history/add', data: {
      'ticketId': ticketId,
      'description': text,
    });
    return ActionResult.fromJson(r.data);
  }

  Future<ActionResult> updateTicketStatus(int ticketId, int statusId, String? comments) async {
    final r = await _api.post('/api/v1/ticket/$ticketId/updateStatus', data: {
      'id': ticketId,
      'ticketStatusId': statusId,
      if (comments != null && comments.isNotEmpty) 'comments': comments,
    });
    return ActionResult.fromJson(r.data);
  }

  // ---- Resignation ----

  /// My latest resignation, or null when I have none.
  Future<ResignationItem?> getMyResignation(int employeeId) async {
    final r = await _api.get('/api/v1/resignation/by-employee/$employeeId');
    final d = r.data;
    if (d is Map<String, dynamic> && d['id'] != null) return ResignationItem.fromJson(d);
    return null;
  }

  /// Creates (POST) or updates (PUT) a draft. Returns the saved id in [ActionResult] via uniqueId
  /// is not exposed by [ActionResult], so callers re-read after saving.
  Future<ActionResult> saveResignation(ResignationItem item, int employeeId) async {
    final body = {
      if (item.id != null) 'id': item.id,
      'employeeId': employeeId,
      'resignationDate': item.resignationDate,
      'lastWorkingDate': item.lastWorkingDate,
      'noticePeriodDays': item.noticeDays,
      'reasonForLeaving': item.reason,
      'additionalRemarks': item.remarks,
      'resignationStatusTypeId': item.statusId,
    };
    final r = item.id == null
        ? await _api.post('/api/v1/resignation', data: body)
        : await _api.put('/api/v1/resignation', data: body);
    return ActionResult.fromJson(r.data);
  }

  Future<ActionResult> submitResignation(int id) async {
    final r = await _api.post('/api/v1/resignation/$id/submit');
    return ActionResult.fromJson(r.data);
  }

  Future<ActionResult> withdrawResignation(int id) async {
    final r = await _api.post('/api/v1/resignation/$id/withdraw');
    return ActionResult.fromJson(r.data);
  }

  // ---- Comp-off ----

  Future<List<CompOffItem>> getMyCompOffs(int employeeId) async {
    final r = await _api.post('/api/v1/compoff/GetAll', data: {
      'selfEmpId': employeeId,
      'pageModel': {'startIndex': 0, 'pageSize': 50},
    });
    return _list(r.data).map(CompOffItem.fromJson).toList();
  }

  Future<ActionResult> requestCompOff({required String date, required String reason}) async {
    final r = await _api.post('/api/v1/compoff', data: {
      'model': {'requestDate': date, 'reason': reason},
    });
    return ActionResult.fromJson(r.data);
  }

  /// Withdraw = change status to Cancelled (3).
  Future<ActionResult> cancelCompOff(String id) async {
    final r = await _api.post('/api/v1/compoff/changestatus', data: {
      'id': id,
      'leaveStatusTypeId': 3,
      'isBillable': false,
      'reason': 'Withdrawn',
    });
    return ActionResult.fromJson(r.data);
  }

  // ---- Timesheets ----

  Future<List<TimesheetItem>> getMyTimesheets() async {
    final r = await _api.post('/api/v1/timesheet/getall', data: {
      'scope': 'own',
      'pageModel': {'startIndex': 0, 'pageSize': 30},
    });
    return _list(r.data).map(TimesheetItem.fromJson).toList();
  }
}
