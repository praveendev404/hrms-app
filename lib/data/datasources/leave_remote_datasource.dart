import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../models/dropdown_option_model.dart';
import '../models/leave_models.dart';

/// Remote data for leave: balances, my requests, apply/cancel, approvals.
class LeaveRemoteDataSource {
  final ApiClient _api;
  LeaveRemoteDataSource(this._api);

  Future<List<LeaveBalance>> getBalances() async {
    final r = await _api.get(ApiEndpoints.leaveInfo);
    return (r.data as List<dynamic>? ?? [])
        .map((e) => LeaveBalance.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<LeaveRequest>> getMyRequests({int pageSize = 50}) async {
    final r = await _api.post(ApiEndpoints.leaveMine, data: {
      'pageModel': {'startIndex': 0, 'pageSize': pageSize},
    });
    return ((r.data as Map<String, dynamic>)['list'] as List<dynamic>? ?? [])
        .map((e) => LeaveRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<DropdownOptionModel>> _options(String path) async {
    final r = await _api.get(path);
    return (r.data as List<dynamic>? ?? [])
        .map((e) => DropdownOptionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<DropdownOptionModel>> getLeaveTypes() => _options(ApiEndpoints.leaveTypesOptions);
  Future<List<DropdownOptionModel>> getDayTypes() => _options(ApiEndpoints.dayTypesOptions);

  /// The server is the only day calculator (holidays, week-offs, half days).
  Future<LeaveDayCount> getDayCount({
    required int employeeId,
    required String fromDate,
    required String toDate,
    required int fromDayTypeId,
    required int toDayTypeId,
  }) async {
    final r = await _api.post(ApiEndpoints.leaveDayCount, data: {
      'forEmployeeId': employeeId,
      'fromDate': fromDate,
      'toDate': toDate,
      'fromDayTypeId': fromDayTypeId,
      'toDayTypeId': toDayTypeId,
    });
    return LeaveDayCount.fromJson(r.data as Map<String, dynamic>);
  }

  Future<ActionResult> apply({
    required int employeeId,
    required int leaveTypeId,
    required String fromDate,
    required String toDate,
    required int fromDayTypeId,
    required int toDayTypeId,
    required double noOfDays,
    required String reason,
  }) async {
    final r = await _api.post(ApiEndpoints.leave, data: {
      'leaveModel': {
        'employeeId': employeeId,
        'leaveTypeId': leaveTypeId,
        'fromDate': fromDate,
        'toDate': toDate,
        'fromDayTypeId': fromDayTypeId,
        'toDayTypeId': toDayTypeId,
        'noOfDays': noOfDays,
        'reason': reason,
      },
    });
    return ActionResult.fromJson(r.data);
  }

  /// Withdraws my request: changestatus -> Cancelled (3), the same call the web makes.
  Future<ActionResult> cancel(int id, {String? reason}) async {
    final r = await _api.post(ApiEndpoints.leaveCancel(id), data: {
      'leaveStatusTypeId': LeaveStatus.cancelled,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
    return ActionResult.fromJson(r.data);
  }

  Future<List<LeaveApproval>> getApprovals() async {
    final r = await _api.post(ApiEndpoints.leaveApprovals, data: <String, dynamic>{});
    return ((r.data as Map<String, dynamic>)['list'] as List<dynamic>? ?? [])
        .map((e) => LeaveApproval.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ActionResult> actOnApprovals(List<int> ids, int statusTypeId, {String? reason}) async {
    final r = await _api.post(ApiEndpoints.leaveBulkAction, data: {
      'approvalIds': ids,
      'leaveStatusTypeId': statusTypeId,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
    return ActionResult.fromJson(r.data);
  }
}
