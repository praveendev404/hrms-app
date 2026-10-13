import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/user_profile_model.dart';
import 'providers.dart';

/// User profile state
class UserProfileState {
  final bool isLoading;
  final UserProfileModel? profile;
  final String? errorMessage;
  final bool isChangingPassword;

  const UserProfileState({
    this.isLoading = false,
    this.profile,
    this.errorMessage,
    this.isChangingPassword = false,
  });

  UserProfileState copyWith({
    bool? isLoading,
    UserProfileModel? profile,
    String? errorMessage,
    bool? isChangingPassword,
  }) {
    return UserProfileState(
      isLoading: isLoading ?? this.isLoading,
      profile: profile ?? this.profile,
      errorMessage: errorMessage,
      isChangingPassword: isChangingPassword ?? this.isChangingPassword,
    );
  }
}

/// User profile state notifier
class UserProfileNotifier extends StateNotifier<UserProfileState> {
  final Ref _ref;

  UserProfileNotifier(this._ref) : super(const UserProfileState());

  /// Fetch user profile information
  Future<void> fetchUserProfile() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final getUserInfoUseCase = _ref.read(getUserInfoUseCaseProvider);
    final result = await getUserInfoUseCase();

    result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: failure.message,
        );
      },
      (userInfo) {
        try {
          final profile = UserProfileModel.fromJson(userInfo);
          state = state.copyWith(
            isLoading: false,
            profile: profile,
          );
        } catch (e) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: 'Failed to parse user information',
          );
        }
      },
    );
  }

  /// Change password
  Future<bool> changePassword(String newPassword) async {
    state = state.copyWith(isChangingPassword: true, errorMessage: null);

    final changePasswordUseCase = _ref.read(changePasswordUseCaseProvider);
    final result = await changePasswordUseCase(password: newPassword);

    return result.fold(
      (failure) {
        state = state.copyWith(
          isChangingPassword: false,
          errorMessage: failure.message,
        );
        return false;
      },
      (success) {
        state = state.copyWith(isChangingPassword: false);
        return success;
      },
    );
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

/// User profile provider
final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, UserProfileState>((ref) {
  return UserProfileNotifier(ref);
});

