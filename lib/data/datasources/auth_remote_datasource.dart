import '../../core/constants/api_endpoints.dart';
import '../../core/errors/exceptions.dart';
import '../../core/network/api_client.dart';
import '../models/user_model.dart';

/// Remote data source for authentication operations
abstract class AuthRemoteDataSource {
  Future<LoginResponse> login(LoginRequest request);
  Future<TokenAndRefreshToken> refreshToken(RefreshRequestModel request);
  Future<Map<String, dynamic>> getUserInfo();
  Future<bool> changePassword(ChangePasswordRequest request);
  Future<void> logout();
}

/// Implementation of auth remote data source
class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiClient _apiClient;

  AuthRemoteDataSourceImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  @override
  Future<LoginResponse> login(LoginRequest request) async {
    final response = await _apiClient.post(
      ApiEndpoints.login,
      data: request.toJson(),
    );

    return LoginResponse.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<TokenAndRefreshToken> refreshToken(RefreshRequestModel request) async {
    final response = await _apiClient.post(
      ApiEndpoints.refreshToken,
      data: request.toJson(),
    );

    return TokenAndRefreshToken.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<Map<String, dynamic>> getUserInfo() async {
    final response = await _apiClient.get(ApiEndpoints.userInfo);
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<bool> changePassword(ChangePasswordRequest request) async {
    // The server identifies the account by userId (the profile id), not by the token.
    final me = await getUserInfo();
    final userId = me['id']?.toString();
    if (userId == null || userId.isEmpty) {
      throw const ServerException(message: 'Could not identify your account. Please log in again.');
    }

    final response = await _apiClient.post(
      ApiEndpoints.changePassword,
      data: {...request.toJson(), 'userId': userId},
    );

    final data = response.data;
    if (data is bool) return data;
    if (data is Map<String, dynamic>) return data['success'] as bool? ?? false;
    return false;
  }

  @override
  Future<void> logout() async {
    // Note: No logout endpoint in new API, but keeping for backward compatibility
    _apiClient.clearAuthToken();
  }
}

