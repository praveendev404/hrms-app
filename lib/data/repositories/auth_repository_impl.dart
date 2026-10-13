import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../../core/network/api_client.dart';
import '../../core/services/storage_service.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/user_model.dart';

/// Implementation of authentication repository
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final StorageService _storageService;
  final ApiClient _apiClient;

  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required StorageService storageService,
    required ApiClient apiClient,
  })  : _remoteDataSource = remoteDataSource,
        _storageService = storageService,
        _apiClient = apiClient;

  @override
  Future<Either<Failure, LoginResponse>> login({
    required String? userName,
    required String? password,
  }) async {
    try {
      final request = LoginRequest(
        userName: userName,
        password: password,
      );
      final response = await _remoteDataSource.login(request);

      // Save credentials securely with error handling for Android 13+
      try {
        if (response.token != null) {
          await _storageService.saveAuthToken(response.token!);
          _apiClient.setAuthToken(response.token!);
        } 
        if (response.refreshToken != null) {
          await _storageService.saveRefreshToken(response.refreshToken!);
        }
      } catch (e) {
        // If storage fails, still return success but log the error
        // The token is set in API client, so the session will work
        // but won't persist across app restarts
        if (kDebugMode) {
          print('Warning: Failed to save tokens to secure storage: $e');
        }
      }

      return Right(response);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, TokenAndRefreshToken>> refreshToken({
    required String? accessToken,
    required String? refreshToken,
  }) async {
    try {
      final request = RefreshRequestModel(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
      final response = await _remoteDataSource.refreshToken(request);

      // Update stored tokens
      await _storageService.saveAuthToken(response.accessToken);
      await _storageService.saveRefreshToken(response.refreshToken);
      _apiClient.setAuthToken(response.accessToken);

      return Right(response);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getUserInfo() async {
    try {
      final response = await _remoteDataSource.getUserInfo();
      return Right(response);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> changePassword({
    required String? password,
  }) async {
    try {
      final request = ChangePasswordRequest(password: password);
      final response = await _remoteDataSource.changePassword(request);
      return Right(response);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      await _remoteDataSource.logout();
      await _storageService.clearSecureStorage();
      _apiClient.clearAuthToken();
      return const Right(null);
    } catch (e) {
      // Even if server logout fails, clear local data
      await _storageService.clearSecureStorage();
      _apiClient.clearAuthToken();
      return const Right(null);
    }
  }

  @override
  Future<bool> isLoggedIn() async {
    final isLoggedIn = await _storageService.isLoggedIn();
    if (isLoggedIn) {
      final token = await _storageService.getAuthToken();
      if (token != null) {
        _apiClient.setAuthToken(token);
      }
    }
    return isLoggedIn;
  }

  @override
  Future<String?> getAuthToken() async {
    return await _storageService.getAuthToken();
  }

  @override
  Future<String?> getRefreshToken() async {
    return await _storageService.getRefreshToken();
  }

  @override
  Future<String?> getUserId() async {
    return await _storageService.getUserId();
  }
}

