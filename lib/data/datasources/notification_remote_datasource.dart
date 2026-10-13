import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../models/leave_models.dart';

class NotificationRemoteDataSource {
  final ApiClient _api;
  NotificationRemoteDataSource(this._api);

  Future<int> getUnreadCount() async {
    final r = await _api.get(ApiEndpoints.notificationsUnread);
    return ((r.data as Map<String, dynamic>)['count'] as num?)?.toInt() ?? 0;
  }

  Future<List<AppNotification>> getList({bool onlyUnread = false}) async {
    final r = await _api.post(ApiEndpoints.notificationsList, data: {
      'onlyUnread': onlyUnread,
      'pageModel': {'startIndex': 0, 'pageSize': 50},
    });
    return ((r.data as Map<String, dynamic>)['list'] as List<dynamic>? ?? [])
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> markRead(int id) async {
    await _api.post(ApiEndpoints.notificationRead(id));
  }

  Future<void> markAllRead() async {
    await _api.post(ApiEndpoints.notificationsReadAll);
  }
}
