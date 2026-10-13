import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// A small on-disk copy of the READ calls the app makes, so previously opened screens
/// (payslips, balances, holidays, directory, ...) still open with no signal.
///
/// Only calls on the allow-list are stored, only successful ones, and the whole cache is
/// wiped on logout. Writes (apply leave, approve, check-in, ...) are never cached or replayed.
class ResponseCache {
  ResponseCache._();

  /// Non-null while the last answer came from disk (time it was saved); drives the banner.
  static final ValueNotifier<DateTime?> servingSavedData = ValueNotifier<DateTime?>(null);

  static const _exact = <String>{
    '/api/v1/profile',
    '/api/v1/org/localization',
    '/api/v1/dashboard/layout',
    '/api/v1/dashboard/catalog',
    '/api/v1/counts',
    '/api/v1/counts/charts',
    '/api/v1/counts/people',
    '/api/v1/counts/approvals-inbox',
    '/api/v1/profile/holidays',
    '/api/v1/profile/weekOffs',
    '/api/v1/leave/myleaveinfo',
    '/api/v1/leave/me',
    '/api/v1/payslip/getall',
    '/api/v1/attendence/getdetailAttendence',
    '/api/v1/notifications/list',
    '/api/v1/feed/getall',
    '/api/v1/emploan/my-loans',
    '/api/v1/empsaldetail/GetMySalaryDetails',
    '/api/v1/learning/my-enrollments',
    '/api/v1/asset/my-assets',
    '/api/v1/todo/list',
    '/api/v1/todo/dashboard',
    '/api/v1/timesheet/getall',
    '/api/v1/performance/goal/getall',
    '/api/v1/performance/review/my',
    '/api/v1/employee',
    '/api/v1/ticket/getAll',
  };

  static const _prefixes = <String>[
    '/api/v1/tax/form16/list/',
    '/api/v1/orgchart/',
    '/api/v1/skill-matrix/employee/',
    '/api/v1/admin/GetParentOptions/',
  ];

  static bool isCacheable(RequestOptions o) {
    if (kIsWeb) return false;
    final m = o.method.toUpperCase();
    if (m != 'GET' && m != 'POST') return false;
    final p = o.path;
    return _exact.contains(p) || _prefixes.any(p.startsWith);
  }

  static bool isConnectionProblem(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return true;
      case DioExceptionType.unknown:
        return e.error is SocketException;
      default:
        return false;
    }
  }

  // FNV-1a 64-bit: stable across runs (String.hashCode is not guaranteed to be).
  static String _hash(String s) {
    var h = 0xcbf29ce484222325;
    for (final b in utf8.encode(s)) {
      h ^= b;
      h = (h * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return h.toUnsigned(64).toRadixString(16);
  }

  static Future<File> _file(RequestOptions o) async {
    final dir = Directory('${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}response_cache');
    if (!await dir.exists()) await dir.create(recursive: true);
    final body = o.data == null ? '' : jsonEncode(o.data);
    final query = o.queryParameters.isEmpty ? '' : jsonEncode(o.queryParameters);
    return File('${dir.path}${Platform.pathSeparator}${_hash('${o.method}|${o.path}|$query|$body')}.json');
  }

  static Future<void> save(Response r) async {
    try {
      final data = r.data;
      if (data is! Map && data is! List) return;
      final f = await _file(r.requestOptions);
      await f.writeAsString(jsonEncode({'t': DateTime.now().toIso8601String(), 'data': data}));
    } catch (_) {
      // Caching is best-effort; never let it break a real response.
    }
  }

  /// Returns the saved response for this request, or null.
  static Future<Response?> load(RequestOptions o) async {
    try {
      final f = await _file(o);
      if (!await f.exists()) return null;
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      final at = DateTime.tryParse(j['t']?.toString() ?? '');
      servingSavedData.value = at ?? DateTime.now();
      return Response(requestOptions: o, statusCode: 200, data: j['data'], extra: {'fromCache': true});
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    servingSavedData.value = null;
    try {
      final dir = Directory('${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}response_cache');
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }
}
