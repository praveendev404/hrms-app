import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../../data/models/user_model.dart';
import '../repositories/auth_repository.dart';

/// Use case for user login
class LoginUseCase {
  final AuthRepository _repository;

  LoginUseCase(this._repository);

  Future<Either<Failure, LoginResponse>> call({
    required String? userName,
    required String? password,
  }) {
    return _repository.login(
      userName: userName,
      password: password,
    );
  }
}

/// Use case for refreshing access token
class RefreshTokenUseCase {
  final AuthRepository _repository;

  RefreshTokenUseCase(this._repository);

  Future<Either<Failure, TokenAndRefreshToken>> call({
    required String? accessToken,
    required String? refreshToken,
  }) {
    return _repository.refreshToken(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }
}

/// Use case for getting user info
class GetUserInfoUseCase {
  final AuthRepository _repository;

  GetUserInfoUseCase(this._repository);

  Future<Either<Failure, Map<String, dynamic>>> call() {
    return _repository.getUserInfo();
  }
}

/// Use case for changing password
class ChangePasswordUseCase {
  final AuthRepository _repository;

  ChangePasswordUseCase(this._repository);

  Future<Either<Failure, bool>> call({
    required String? password,
  }) {
    return _repository.changePassword(password: password);
  }
}

/// Use case for user logout
class LogoutUseCase {
  final AuthRepository _repository;

  LogoutUseCase(this._repository);

  Future<Either<Failure, void>> call() {
    return _repository.logout();
  }
}

/// Use case to check login status
class CheckLoginStatusUseCase {
  final AuthRepository _repository;

  CheckLoginStatusUseCase(this._repository);

  Future<bool> call() {
    return _repository.isLoggedIn();
  }
}

