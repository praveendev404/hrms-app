// The offline cache: saves allow-listed reads, serves them back, never touches writes,
// and is wiped on demand (logout).
//
//   flutter test tools/e2e/offline_cache_test.dart
// ignore_for_file: depend_on_referenced_packages
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:vectoredge_hrms/core/network/response_cache.dart';

class _TempPaths extends Fake with MockPlatformInterfaceMixin implements PathProviderPlatform {
  final String dir;
  _TempPaths(this.dir);
  @override
  Future<String?> getApplicationSupportPath() async => dir;
}

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('hrms_cache_');
    PathProviderPlatform.instance = _TempPaths(tmp.path);
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  RequestOptions req(String method, String path, {dynamic data}) =>
      RequestOptions(path: path, method: method, data: data);

  test('only allow-listed reads are cacheable; writes never are', () {
    expect(ResponseCache.isCacheable(req('GET', '/api/v1/leave/myleaveinfo')), isTrue);
    expect(ResponseCache.isCacheable(req('POST', '/api/v1/leave/me')), isTrue);
    expect(ResponseCache.isCacheable(req('POST', '/api/v1/leave')), isFalse, reason: 'apply leave is a write');
    expect(ResponseCache.isCacheable(req('POST', '/api/v1/attendence/postlatestwebcheckin')), isFalse);
    expect(ResponseCache.isCacheable(req('POST', '/api/v1/authorize')), isFalse);
    expect(ResponseCache.isCacheable(req('PUT', '/api/v1/profile')), isFalse);
  });

  test('a saved read comes back identical and flags the banner', () async {
    final o = req('POST', '/api/v1/leave/me', data: {'pageModel': {'startIndex': 0, 'pageSize': 50}});
    await ResponseCache.save(Response(requestOptions: o, statusCode: 200, data: {'list': [{'id': 1}], 'totalRecords': 1}));

    final back = await ResponseCache.load(o);
    expect(back, isNotNull);
    expect(back!.data, {'list': [{'id': 1}], 'totalRecords': 1});
    expect(ResponseCache.servingSavedData.value, isNotNull);

    // A different body is a different request: no false hit.
    final other = req('POST', '/api/v1/leave/me', data: {'pageModel': {'startIndex': 1, 'pageSize': 50}});
    expect(await ResponseCache.load(other), isNull);
  });

  test('clear() wipes everything (logout)', () async {
    final o = req('GET', '/api/v1/profile/holidays');
    await ResponseCache.save(Response(requestOptions: o, statusCode: 200, data: [{'name': 'Diwali'}]));
    expect(await ResponseCache.load(o), isNotNull);

    await ResponseCache.clear();
    expect(await ResponseCache.load(o), isNull);
    expect(ResponseCache.servingSavedData.value, isNull);
  });

  test('connection problems are recognised, server errors are not', () {
    DioException e(DioExceptionType t, {Object? error}) =>
        DioException(requestOptions: req('GET', '/x'), type: t, error: error);
    expect(ResponseCache.isConnectionProblem(e(DioExceptionType.connectionError)), isTrue);
    expect(ResponseCache.isConnectionProblem(e(DioExceptionType.connectionTimeout)), isTrue);
    expect(ResponseCache.isConnectionProblem(e(DioExceptionType.unknown, error: const SocketException('x'))), isTrue);
    expect(ResponseCache.isConnectionProblem(e(DioExceptionType.badResponse)), isFalse,
        reason: 'a 403/500 must show its error, not stale data');
  });
}
