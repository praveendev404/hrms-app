import '../../core/network/api_client.dart';
import '../models/leave_models.dart';
import '../models/social_models.dart';

/// Recognition and pulse surveys.
class SocialRemoteDataSource {
  final ApiClient _api;
  SocialRemoteDataSource(this._api);

  List<Map<String, dynamic>> _list(dynamic data) =>
      ((data as Map<String, dynamic>)['list'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

  // ---- Recognition ----

  Future<List<RecognitionRecord>> getRecords({bool mine = false}) async {
    final r = await _api.post('/api/v1/recognition/record/getall', data: {
      'myRecognitions': mine,
      'pageModel': {'startIndex': 0, 'pageSize': 50},
    });
    return _list(r.data).map(RecognitionRecord.fromJson).toList();
  }

  Future<List<RecognitionBadge>> getBadges() async {
    final r = await _api.post('/api/v1/recognition/badge/getall', data: <String, dynamic>{});
    return _list(r.data).map(RecognitionBadge.fromJson).toList();
  }

  Future<List<LeaderEntry>> getLeaderboard() async {
    final r = await _api.post('/api/v1/recognition/record/leaderboard', data: <String, dynamic>{});
    return (r.data as List<dynamic>? ?? []).map((e) => LeaderEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ActionResult> give({required int recipientId, required int badgeId, String? message}) async {
    final r = await _api.post('/api/v1/recognition/record', data: {
      'model': {
        'recipientId': recipientId,
        'badgeId': badgeId,
        if (message != null && message.isNotEmpty) 'message': message,
      },
    });
    return ActionResult.fromJson(r.data);
  }

  Future<List<EmployeeOption>> searchEmployees(String keyword) async {
    final r = await _api.post('/api/v1/employee/options', data: {
      'pageModel': {'startIndex': 0, 'pageSize': 20, 'keyword': keyword},
    });
    return _list(r.data).map(EmployeeOption.fromJson).toList();
  }

  // ---- Surveys ----

  Future<List<Survey>> getMySurveys() async {
    final r = await _api.get('/api/v1/pulse-survey/my-surveys');
    return (r.data as List<dynamic>? ?? []).map((e) => Survey.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ActionResult> submitSurvey(int surveyId, List<Map<String, dynamic>> answers) async {
    final r = await _api.post('/api/v1/pulse-survey/submit', data: {
      'surveyId': surveyId,
      'answers': answers,
    });
    return ActionResult.fromJson(r.data);
  }
}
