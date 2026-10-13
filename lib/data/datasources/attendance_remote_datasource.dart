import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../models/attendance_model.dart';

/// Remote data source for attendance operations
abstract class AttendanceRemoteDataSource {
  Future<AttendanceResponse> getAllOrgAttendance(AttendanceRequest request);
}

/// Implementation of attendance remote data source
class AttendanceRemoteDataSourceImpl implements AttendanceRemoteDataSource {
  final ApiClient _apiClient;

  AttendanceRemoteDataSourceImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  @override
  Future<AttendanceResponse> getAllOrgAttendance(
      AttendanceRequest request) async {
    final response = await _apiClient.post(
      ApiEndpoints.attendance,
      data: request.toJson(),
    );

    // Handle both direct list and wrapped response
    if (response.data is List) {
      return AttendanceResponse.fromJson(response.data as List);
    } else if (response.data is Map<String, dynamic>) {
      final data = response.data as Map<String, dynamic>;
      // Try common response wrapper keys
      if (data.containsKey('data')) {
        return AttendanceResponse.fromJson(data['data'] as List);
      } else if (data.containsKey('employees')) {
        return AttendanceResponse.fromJson(data['employees'] as List);
      } else if (data.containsKey('result')) {
        return AttendanceResponse.fromJson(data['result'] as List);
      }
    }
    
    throw Exception('Invalid response format: ${response.data}');
  }
}
