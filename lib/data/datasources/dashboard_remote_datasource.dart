import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../models/dashboard_models.dart';
import '../models/leave_models.dart';

/// Remote data for the server-driven dashboard widgets.
class DashboardRemoteDataSource {
  final ApiClient _api;
  DashboardRemoteDataSource(this._api);

  Future<DashboardLayout> getLayout() async {
    final r = await _api.get(ApiEndpoints.dashboardLayout);
    return DashboardLayout.fromJson(r.data as Map<String, dynamic>);
  }

  Future<Map<String, DashboardCatalogItem>> getCatalog() async {
    final r = await _api.get(ApiEndpoints.dashboardCatalog);
    final items = (r.data as Map<String, dynamic>)['items'] as List<dynamic>? ?? [];
    return {
      for (final e in items)
        (e as Map<String, dynamic>)['id'] as String: DashboardCatalogItem.fromJson(e),
    };
  }

  Future<int> getCount(String type) async {
    final r = await _api.post(ApiEndpoints.counts, data: {'type': type});
    return ((r.data as Map<String, dynamic>)['value'] as num?)?.toInt() ?? 0;
  }

  Future<List<ChartPoint>> getChart(String chartType, {int? departmentId, int? year}) async {
    final r = await _api.post(ApiEndpoints.countsCharts, data: {
      'chartType': chartType,
      if (departmentId != null) 'departmentId': departmentId,
      if (year != null) 'year': year,
    });
    final pts = (r.data as Map<String, dynamic>)['dataPoints'] as List<dynamic>? ?? [];
    return pts.map((e) => ChartPoint.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AnalyticsSummary> getAnalyticsSummary({int? departmentId}) async {
    final r = await _api.get(
      '/api/v1/counts/analytics-summary',
      queryParameters: {if (departmentId != null) 'departmentId': departmentId},
    );
    return AnalyticsSummary.fromJson(r.data as Map<String, dynamic>);
  }

  Future<PeopleWidgets> getPeople() async {
    final r = await _api.post(ApiEndpoints.countsPeople, data: <String, dynamic>{});
    return PeopleWidgets.fromJson(r.data as Map<String, dynamic>);
  }

  Future<ApprovalsInbox> getApprovalsInbox() async {
    final r = await _api.get(ApiEndpoints.approvalsInbox);
    return ApprovalsInbox.fromJson(r.data as Map<String, dynamic>);
  }

  Future<TodoDashboard> getTodos() async {
    final r = await _api.get(ApiEndpoints.todoDashboard);
    return TodoDashboard.fromJson(r.data as Map<String, dynamic>);
  }

  Future<void> completeTodo(int id) async {
    await _api.post(ApiEndpoints.todoComplete(id));
  }

  /// Inclusive date range, at most 93 days.
  Future<List<TodoItem>> listTodos(String from, String to) async {
    final r = await _api.post('/api/v1/todo/list', data: {
      'fromDate': from,
      'toDate': to,
      'includeCompleted': true,
    });
    return ((r.data as Map<String, dynamic>)['items'] as List<dynamic>? ?? [])
        .map((e) => TodoItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ActionResult> saveTodo({
    int? id,
    required String title,
    String? description,
    required String dueDate,
    String? dueTime,
    int? priority,
    int reminderType = 0,
  }) async {
    final r = await _api.post('/api/v1/todo/upsert', data: {
      if (id != null) 'id': id,
      'title': title,
      'description': description,
      'dueDate': dueDate,
      'dueTime': dueTime,
      'priority': priority,
      'reminderType': reminderType,
    });
    return ActionResult.fromJson(r.data);
  }

  Future<void> reopenTodo(int id) async {
    await _api.post('/api/v1/todo/$id/reopen');
  }

  Future<void> deleteTodo(int id) async {
    await _api.delete('/api/v1/todo/$id');
  }

  Future<List<HolidayItem>> getHolidays() async {
    final r = await _api.get(ApiEndpoints.holidays);
    final list = r.data as List<dynamic>? ?? [];
    return list.map((e) => HolidayItem.fromJson(e as Map<String, dynamic>)).toList();
  }
}
