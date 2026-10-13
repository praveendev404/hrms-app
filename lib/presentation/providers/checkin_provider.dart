import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/location_service.dart';
import '../../data/datasources/checkin_remote_datasource.dart';
import '../../data/models/checkin_model.dart';
import '../../data/repositories/checkin_repository_impl.dart';
import '../../domain/repositories/checkin_repository.dart';
import '../../domain/usecases/checkin_usecases.dart';
import 'providers.dart';

/// Check-in state
class CheckInState {
  final bool isCheckedIn;
  final DateTime? checkInTime;
  final String? errorMessage;
  final bool isLoading;

  CheckInState({
    this.isCheckedIn = false,
    this.checkInTime,
    this.errorMessage,
    this.isLoading = false,
  });

  CheckInState copyWith({
    bool? isCheckedIn,
    DateTime? checkInTime,
    String? errorMessage,
    bool? isLoading,
    bool clearCheckInTime = false,
  }) {
    return CheckInState(
      isCheckedIn: isCheckedIn ?? this.isCheckedIn,
      checkInTime: clearCheckInTime ? null : (checkInTime ?? this.checkInTime),
      errorMessage: errorMessage,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  /// Calculate elapsed time since check-in
  Duration? get elapsedTime {
    if (checkInTime == null) return null;
    return DateTime.now().difference(checkInTime!);
  }

  /// Format elapsed time as HH:MM:SS
  String get formattedElapsedTime {
    final elapsed = elapsedTime;
    if (elapsed == null) return '00:00:00';

    final hours = elapsed.inHours.toString().padLeft(2, '0');
    final minutes = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');

    return '$hours:$minutes:$seconds';
  }
}

/// Check-in notifier
class CheckInNotifier extends StateNotifier<CheckInState> {
  final GetLatestCheckInUseCase _getLatestCheckInUseCase;
  final PostCheckInUseCase _postCheckInUseCase;
  final LocationService _locationService;

  CheckInNotifier(
    this._getLatestCheckInUseCase,
    this._postCheckInUseCase,
    this._locationService,
  ) : super(CheckInState()) {
    fetchLatestCheckIn();
  }

  /// Fetch latest check-in status from server
  Future<void> fetchLatestCheckIn() async {
    state = state.copyWith(isLoading: true);

    final result = await _getLatestCheckInUseCase();

    result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: failure.message,
        );
      },
      (response) {
        if (response != null) {
          state = state.copyWith(
            isLoading: false,
            isCheckedIn: response.isCheckedIn,
            checkInTime: response.isCheckedIn ? response.dateTime : null,
          );
        } else {
          state = state.copyWith(
            isLoading: false,
            isCheckedIn: false,
            clearCheckInTime: true,
          );
        }
      },
    );
  }

  /// Best-effort device location. The server only requires it when a geo-fence is
  /// enforced, and then replies with a clear message if it is missing, so a failure
  /// here must not block the punch from being attempted.
  Future<LocationData?> _tryLocation() async {
    try {
      return await _locationService.getCurrentLocation();
    } catch (_) {
      return null;
    }
  }

  /// Check in
  Future<void> checkIn() async {
    state = state.copyWith(isLoading: true);

    final loc = await _tryLocation();
    final now = DateTime.now();
    final request = CheckInRequest(
      date: now.toIso8601String(),
      hours: now.hour,
      minutes: now.minute,
      seconds: now.second,
      punchInTypeId: 1, // 1 for check-in
      latitude: loc?.latitude,
      longitude: loc?.longitude,
    );

    final result = await _postCheckInUseCase(request);

    result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: failure.message,
        );
      },
      (success) {
        if (success) {
          state = state.copyWith(
            isLoading: false,
            isCheckedIn: true,
            checkInTime: now,
            errorMessage: 'Checked in successfully!',
          );
        } else {
          state = state.copyWith(
            isLoading: false,
            errorMessage: 'Failed to check in. Please try again.',
          );
        }
      },
    );
  }

  /// Check out
  Future<void> checkOut() async {
    state = state.copyWith(isLoading: true);

    final loc = await _tryLocation();
    final now = DateTime.now();
    final request = CheckInRequest(
      date: now.toIso8601String(),
      hours: now.hour,
      minutes: now.minute,
      seconds: now.second,
      punchInTypeId: 2, // 2 for check-out
      latitude: loc?.latitude,
      longitude: loc?.longitude,
    );

    final result = await _postCheckInUseCase(request);

    result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: failure.message,
        );
      },
      (success) {
        if (success) {
          state = state.copyWith(
            isLoading: false,
            isCheckedIn: false,
            clearCheckInTime: true,
            errorMessage: 'Checked out successfully!',
          );
        } else {
          state = state.copyWith(
            isLoading: false,
            errorMessage: 'Failed to check out. Please try again.',
          );
        }
      },
    );
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

/// Provider for check-in datasource
final checkInDataSourceProvider = Provider<CheckInRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return CheckInRemoteDataSourceImpl(apiClient: apiClient);
});

/// Provider for check-in repository
final checkInRepositoryProvider = Provider<CheckInRepository>((ref) {
  final dataSource = ref.watch(checkInDataSourceProvider);
  return CheckInRepositoryImpl(remoteDataSource: dataSource);
});

/// Provider for get latest check-in use case
final getLatestCheckInUseCaseProvider = Provider<GetLatestCheckInUseCase>((ref) {
  final repository = ref.watch(checkInRepositoryProvider);
  return GetLatestCheckInUseCase(repository);
});

/// Provider for post check-in use case
final postCheckInUseCaseProvider = Provider<PostCheckInUseCase>((ref) {
  final repository = ref.watch(checkInRepositoryProvider);
  return PostCheckInUseCase(repository);
});

/// Provider for check-in state
final checkInProvider =
    StateNotifierProvider<CheckInNotifier, CheckInState>((ref) {
  final getLatestUseCase = ref.watch(getLatestCheckInUseCaseProvider);
  final postUseCase = ref.watch(postCheckInUseCaseProvider);
  return CheckInNotifier(getLatestUseCase, postUseCase, ref.watch(locationServiceProvider));
});
