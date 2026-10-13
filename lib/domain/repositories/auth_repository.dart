import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../../data/models/user_model.dart';

/// Abstract repository for authentication operations
abstract class AuthRepository {
  /// Login with email and password
  Future<Either<Failure, LoginResponse>> login({
    required String? userName,
    required String? password,
  });

  /// Refresh access token
  Future<Either<Failure, TokenAndRefreshToken>> refreshToken({
    required String? accessToken,
    required String? refreshToken,
  });

  /// Get user information
  Future<Either<Failure, Map<String, dynamic>>> getUserInfo();

  /// Change password
  Future<Either<Failure, bool>> changePassword({
    required String? password,
  });

  /// Logout current user
  Future<Either<Failure, void>> logout();

  /// Check if user is logged in
  Future<bool> isLoggedIn();

  /// Get stored auth token
  Future<String?> getAuthToken();

  /// Get stored refresh token
  Future<String?> getRefreshToken();

  /// Get stored user ID
  Future<String?> getUserId();
}

