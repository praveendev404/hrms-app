import '../../core/constants/api_endpoints.dart';
import '../../core/errors/exceptions.dart';
import '../../core/network/api_client.dart';
import '../models/checkin_model.dart';

/// Remote data source for web check-in operations
abstract class CheckInRemoteDataSource {
  Future<bool> postCheckIn(CheckInRequest request);
  Future<CheckInResponse?> getLatestCheckIn();
}

/// Implementation of check-in remote data source
class CheckInRemoteDataSourceImpl implements CheckInRemoteDataSource {
  final ApiClient _apiClient;

  CheckInRemoteDataSourceImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  @override
  Future<bool> postCheckIn(CheckInRequest request) async {
    final response = await _apiClient.post(
      ApiEndpoints.postWebCheckIn,
      data: request.toJson(),
    );

    // The API answers with a BaseResponse ({success, message}); a refusal (WFH gate,
    // geo-fence, missing location) comes back as HTTP 400 with the same shape.
    final data = response.data;
    if (data is bool) return data;
    if (data is Map<String, dynamic>) {
      final ok = data['success'] as bool? ?? false;
      if (!ok) {
        throw ServerException(message: data['message']?.toString() ?? 'Check-in was not accepted.');
      }
      return true;
    }
    return false;
  }

  @override
  Future<CheckInResponse?> getLatestCheckIn() async {
    final response = await _apiClient.get(
      ApiEndpoints.getWebCheckIn,
    );

    if (response.data == null) {
      return null;
    }

    return CheckInResponse.fromJson(response.data as Map<String, dynamic>);
  }
}
