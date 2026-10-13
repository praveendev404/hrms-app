import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers.dart';

/// Authentication state
enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
  requiresPasswordChange,
}

/// Authentication state class
class AuthState {
  final AuthStatus status;
  final String? userId;
  final String? errorMessage;
  final bool isChangePasswordRequired;

  const AuthState({
    this.status = AuthStatus.initial,
    this.userId,
    this.errorMessage,
    this.isChangePasswordRequired = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? userId,
    String? errorMessage,
    bool? isChangePasswordRequired,
  }) {
    return AuthState(
      status: status ?? this.status,
      userId: userId ?? this.userId,
      errorMessage: errorMessage,
      isChangePasswordRequired: isChangePasswordRequired ?? this.isChangePasswordRequired,
    );
  }
}

/// Authentication state notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;

  AuthNotifier(this._ref) : super(const AuthState());

  /// Check initial auth status
  Future<void> checkAuthStatus() async {
    state = state.copyWith(status: AuthStatus.loading);
    
    final checkLoginStatus = _ref.read(checkLoginStatusUseCaseProvider);
    final isLoggedIn = await checkLoginStatus();

    if (isLoggedIn) {
      final userId = await _ref.read(authRepositoryProvider).getUserId();
      state = state.copyWith(
        status: AuthStatus.authenticated,
        userId: userId,
      );
    } else {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  /// Login with credentials
  /// Automatically detects device type (iOS=1, Android=2) and gets device ID
  Future<bool> login({
    required String? email,
    required String? password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    try {
      final loginUseCase = _ref.read(loginUseCaseProvider);
      final result = await loginUseCase(
        userName: email,
        password: password,
      );

      return result.fold(
        (failure) {
          state = state.copyWith(
            status: AuthStatus.error,
            errorMessage: failure.message,
          );
          return false;
        },
        (response) {
          // Check if password change is required
          if (response.isChangePassword) {
            state = state.copyWith(
              status: AuthStatus.requiresPasswordChange,
              isChangePasswordRequired: true,
            );
          } else {
            state = state.copyWith(
              status: AuthStatus.authenticated,
              userId: null, // Will be set from getUserInfo if needed
              isChangePasswordRequired: false,
            );
          }
          return true;
        },
      );
    } catch (e) {
      // Catch any unexpected errors during login
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'An unexpected error occurred during login. Please try again.',
      );
      return false;
    }
  }

  /// Logout
  Future<void> logout() async {
    state = state.copyWith(status: AuthStatus.loading);

    final logoutUseCase = _ref.read(logoutUseCaseProvider);
    await logoutUseCase();

    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

/// Auth state provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

/// Is loading provider
final isAuthLoadingProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).status == AuthStatus.loading;
});

/// Is authenticated provider
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).status == AuthStatus.authenticated;
});

