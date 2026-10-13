import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../models/dropdown_option_model.dart';
import '../models/leave_models.dart';
import '../models/request_models.dart';
import '../models/work_models.dart';

/// Regularization, WFH requests and payslips.
class RequestRemoteDataSource {
  final ApiClient _api;
  RequestRemoteDataSource(this._api);

  List<Map<String, dynamic>> _list(dynamic data) =>
      ((data as Map<String, dynamic>)['list'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

  // ---- Regularization ----

  /// The server list is tenant-wide; callers filter to their own employee id.
  Future<List<RegularizeItem>> getRegularizations() async {
    final r = await _api.post(ApiEndpoints.regularizeList, data: {
      'pageModel': {'startIndex': 0, 'pageSize': 200},
    });
    return _list(r.data).map(RegularizeItem.fromJson).toList();
  }

  Future<List<DropdownOptionModel>> getRegularizeTypes() async {
    final r = await _api.get(ApiEndpoints.regularizeTypesOptions);
    return (r.data as List<dynamic>? ?? [])
        .map((e) => DropdownOptionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ActionResult> addRegularization({
    required int empId,
    required int typeId,
    required String date,
    required String notes,
    String? inTime,
    String? outTime,
  }) async {
    final r = await _api.post(ApiEndpoints.regularize, data: {
      'empId': empId,
      'regularizeTypeId': typeId,
      'date': date,
      'notes': notes,
      if (inTime != null) 'inTime': inTime,
      if (outTime != null) 'outTime': outTime,
    });
    return ActionResult.fromJson(r.data);
  }

  Future<ActionResult> setRegularizationStatus(int id, int statusTypeId, {String? remarks}) async {
    final r = await _api.put(ApiEndpoints.regularizeStatus(id), data: {
      'statusTypeId': statusTypeId,
      if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
    });
    return ActionResult.fromJson(r.data);
  }

  // ---- WFH ----

  /// [scope]: own | team | all.
  Future<List<WfhItem>> getWfh({String scope = 'own', int? statusTypeId}) async {
    final r = await _api.post(ApiEndpoints.wfhList, data: {
      'scope': scope,
      if (statusTypeId != null) 'statusTypeId': statusTypeId,
      'pageModel': {'startIndex': 0, 'pageSize': 100},
    });
    return _list(r.data).map(WfhItem.fromJson).toList();
  }

  Future<ActionResult> addWfh({required String fromDate, required String toDate, String? reason}) async {
    final r = await _api.post(ApiEndpoints.wfh, data: {
      'fromDate': fromDate,
      'toDate': toDate,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
    return ActionResult.fromJson(r.data);
  }

  Future<ActionResult> setWfhStatus(int id, int statusTypeId, {String? remarks}) async {
    final r = await _api.put(ApiEndpoints.wfhStatus(id), data: {
      'statusTypeId': statusTypeId,
      if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
    });
    return ActionResult.fromJson(r.data);
  }

  // ---- Admin / manager approvals ----

  /// Submitted timesheets. Asks for scope 'all'; the server downgrades it to the caller's
  /// team unless they hold the attendance-manage permission.
  Future<List<TimesheetReviewItem>> getTimesheetsToReview() async {
    final r = await _api.post('/api/v1/timesheet/getall', data: {
      'scope': 'all',
      'timesheetStatusTypeId': TimesheetStatus.submitted,
      'pageModel': {'startIndex': 0, 'pageSize': 100},
    });
    return _list(r.data).map(TimesheetReviewItem.fromJson).toList();
  }

  Future<List<WorkLog>> getWorkLogsOf(int timesheetId) async {
    final r = await _api.post('/api/v1/timesheet/$timesheetId/WorkLog/getall', data: <String, dynamic>{});
    return _list(r.data).map(WorkLog.fromJson).toList();
  }

  /// Manager verdict: approve = 3, reject = 4 (remarks required for reject).
  Future<ActionResult> decideTimesheet(int id, {required bool approve, String? remarks}) async {
    final r = await _api.post('/api/v1/timesheet/$id/managerAddWfLog', data: {
      'timesheetStatusTypeId': approve ? TimesheetStatus.approved : TimesheetStatus.rejected,
      'remarks': remarks ?? '',
    });
    return ActionResult.fromJson(r.data);
  }

  Future<List<CompOffItem>> getCompOffsToReview() async {
    final r = await _api.post('/api/v1/compoff/GetAll', data: {
      'pageModel': {'startIndex': 0, 'pageSize': 100},
    });
    return _list(r.data).map(CompOffItem.fromJson).where((c) => c.statusId == 1).toList();
  }

  /// Approve = 2, reject = 4 (LeaveStatusTypeEnum).
  Future<ActionResult> decideCompOff(String id, {required bool approve, String? reason}) async {
    final r = await _api.post('/api/v1/compoff/changestatus', data: {
      'id': id,
      'leaveStatusTypeId': approve ? 2 : 4,
      'isBillable': false,
      'reason': reason ?? '',
    });
    return ActionResult.fromJson(r.data);
  }

  Future<List<LateEntryItem>> getLateEntriesToResolve() async {
    final r = await _api.post('/api/v1/late-comers/list', data: {
      'scope': 'all',
      'statusTypeId': 1,
      'pageModel': {'startIndex': 0, 'pageSize': 100},
    });
    return _list(r.data).map(LateEntryItem.fromJson).toList();
  }

  Future<ActionResult> resolveLateEntry(int id, String remarks) async {
    final r = await _api.put('/api/v1/late-comers/$id/resolve', data: {'remarks': remarks});
    return ActionResult.fromJson(r.data);
  }

  /// Every employee's resignation (needs the employee-manage permission).
  Future<List<ResignationItem>> getAllResignations() async {
    final r = await _api.post('/api/v1/resignation/getall', data: {
      'pageModel': {'startIndex': 0, 'pageSize': 100},
    });
    return _list(r.data).map(ResignationItem.fromJson).toList();
  }

  /// Two stages: manager (Submitted -> 3 / 4) then HR (ManagerApproved -> 5 / 6).
  Future<ActionResult> decideResignation(ResignationItem item, {required bool approve, String? remarks}) async {
    final hrStage = item.statusId == ResignationStatus.managerApproved;
    final status = hrStage
        ? (approve ? ResignationStatus.hrApproved : ResignationStatus.hrRejected)
        : (approve ? ResignationStatus.managerApproved : ResignationStatus.managerRejected);
    final body = {
      'resignationStatusTypeId': status,
      if (hrStage) 'hrRemarks': remarks else 'managerRemarks': remarks,
    };
    final r = await _api.post(
      '/api/v1/resignation/${item.id}/${approve ? 'approve' : 'reject'}',
      data: body,
    );
    return ActionResult.fromJson(r.data);
  }

  /// All leave requests across the org (needs the leave-manage permission); callers
  /// keep the pending ones.
  Future<List<LeaveRequest>> getOrgLeaveRequests() async {
    final r = await _api.post('/api/v1/leave/GetAll', data: {
      'pageModel': {'startIndex': 0, 'pageSize': 200},
    });
    return _list(r.data).map(LeaveRequest.fromJson).toList();
  }

  /// HR override of a leave request's status: approve = 2, reject = 4.
  Future<ActionResult> decideLeave(int id, {required bool approve, String? reason}) async {
    final r = await _api.post('/api/v1/leave/$id/changestatus', data: {
      'leaveStatusTypeId': approve ? 2 : 4,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
    return ActionResult.fromJson(r.data);
  }

  // ---- Form 16 ----

  Future<List<Form16Item>> getForm16List(int employeeId) async {
    final r = await _api.get('/api/v1/tax/form16/list/$employeeId');
    return _list(r.data).map(Form16Item.fromJson).toList();
  }

  /// Downloads a Form 16 PDF to a temp file and returns its path.
  Future<String> downloadForm16(int employeeId, Form16Item f) async {
    final r = await _api.get<List<int>>(
      '/api/v1/tax/form16/download/$employeeId/${f.fyId}',
      options: Options(responseType: ResponseType.bytes),
    );
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}form16_${f.fyId}.pdf');
    await file.writeAsBytes(r.data ?? const []);
    return file.path;
  }

  // ---- Payslips ----

  Future<List<PayslipItem>> getPayslips(int year) async {
    final r = await _api.post(ApiEndpoints.payslipList, data: {
      'year': year,
      'pageModel': {'startIndex': 0, 'pageSize': 50},
    });
    return _list(r.data).map(PayslipItem.fromJson).toList();
  }

  /// Downloads a payslip PDF to a temp file and returns its path.
  Future<String> downloadPayslip(PayslipItem p) async {
    final path = p.filePath;
    if (path == null || path.isEmpty) {
      throw Exception('This payslip has no file.');
    }
    final r = await _api.post<List<int>>(
      ApiEndpoints.payslipDownload,
      data: {'filePath': path},
      options: Options(responseType: ResponseType.bytes),
    );
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}payslip_${p.id}.pdf');
    await file.writeAsBytes(r.data ?? const []);
    return file.path;
  }
}
