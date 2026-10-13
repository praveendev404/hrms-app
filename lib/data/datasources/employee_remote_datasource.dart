import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../models/employee_model.dart';

/// Remote data source for employee operations
abstract class EmployeeRemoteDataSource {
  Future<EmployeeListResponse> getEmployees(EmployeeRequest request);
}

/// Implementation of employee remote data source
class EmployeeRemoteDataSourceImpl implements EmployeeRemoteDataSource {
  final ApiClient _apiClient;

  EmployeeRemoteDataSourceImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  @override
  Future<EmployeeListResponse> getEmployees(EmployeeRequest request) async {
    final response = await _apiClient.post(
      ApiEndpoints.employee,
      data: request.toJson(),
    );

    return EmployeeListResponse.fromJson(response.data as Map<String, dynamic>);
  }
}
