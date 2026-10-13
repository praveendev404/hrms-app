import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/datasources/attendance_remote_datasource.dart';
import '../../data/models/attendance_model.dart';
import '../../data/repositories/attendance_repository_impl.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../../domain/usecases/attendance_usecases.dart';
import 'providers.dart';

/// Provider for attendance datasource
final attendanceDataSourceProvider =
    Provider<AttendanceRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AttendanceRemoteDataSourceImpl(apiClient: apiClient);
});

/// Provider for attendance repository
final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  final dataSource = ref.watch(attendanceDataSourceProvider);
  return AttendanceRepositoryImpl(remoteDataSource: dataSource);
});

/// Provider for get attendance use case
final getAttendanceUseCaseProvider = Provider<GetAttendanceUseCase>((ref) {
  final repository = ref.watch(attendanceRepositoryProvider);
  return GetAttendanceUseCase(repository);
});

/// Attendance state
class AttendanceState {
  final AttendanceResponse? data;
  final bool isLoading;
  final String? errorMessage;
  final DateTime selectedMonth;
  final String? selectedDate; // Track which date in the table is selected

  AttendanceState({
    this.data,
    this.isLoading = false,
    this.errorMessage,
    DateTime? selectedMonth,
    this.selectedDate,
  }) : selectedMonth = selectedMonth ?? DateTime.now();

  AttendanceState copyWith({
    AttendanceResponse? data,
    bool? isLoading,
    String? errorMessage,
    DateTime? selectedMonth,
    String? selectedDate,
    bool clearData = false,
    bool clearError = false,
  }) {
    return AttendanceState(
      data: clearData ? null : (data ?? this.data),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      selectedMonth: selectedMonth ?? this.selectedMonth,
      selectedDate: selectedDate ?? this.selectedDate,
    );
  }
}

/// Attendance notifier
class AttendanceNotifier extends StateNotifier<AttendanceState> {
  final GetAttendanceUseCase _getAttendanceUseCase;

  AttendanceNotifier(this._getAttendanceUseCase) : super(AttendanceState());

  /// Fetch attendance data for selected month
  Future<void> fetchAttendance() async {
    state = state.copyWith(isLoading: true, clearError: true);

    // Use first day of the month for the request
    final firstDayOfMonth = DateTime(state.selectedMonth.year, state.selectedMonth.month, 1);
    final dateStr = DateFormat('yyyy-MM-dd').format(firstDayOfMonth);

    final request = AttendanceRequest(
      date: dateStr,
      empId: 0,
      isForParticularDate: false,
    );

    final result = await _getAttendanceUseCase(request);

    result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: failure.message,
        );
      },
      (data) {
        // Set selectedDate to today's date if it's in the current month
        final today = DateTime.now();
        final todayStr = DateFormat('yyyy-MM-dd').format(today);
        
        // Check if today's date exists in the returned data
        String? initialDate;
        if (data.employees.isNotEmpty) {
          final hasToday = data.employees.first.logsByDate.any((day) {
            try {
              final dayDate = DateTime.parse(day.date);
              return DateFormat('yyyy-MM-dd').format(dayDate) == todayStr;
            } catch (e) {
              return day.date == todayStr;
            }
          });
          
          if (hasToday) {
            initialDate = todayStr;
          } else if (data.employees.first.logsByDate.isNotEmpty) {
            // Use first available date
            initialDate = data.employees.first.logsByDate.first.date;
          }
        }
        
        state = state.copyWith(
          isLoading: false,
          data: data,
          selectedDate: initialDate,
          clearError: true,
        );
      },
    );
  }

  /// Change selected month
  void changeMonth(DateTime newMonth) {
    state = state.copyWith(selectedMonth: newMonth);
    fetchAttendance();
  }

  /// Navigate to previous month
  void previousMonth() {
    final newMonth = DateTime(
      state.selectedMonth.year,
      state.selectedMonth.month - 1,
      1,
    );
    changeMonth(newMonth);
  }

  /// Navigate to next month
  void nextMonth() {
    final newMonth = DateTime(
      state.selectedMonth.year,
      state.selectedMonth.month + 1,
      1,
    );
    changeMonth(newMonth);
  }

  /// Navigate to current month
  void currentMonth() {
    changeMonth(DateTime.now());
  }

  /// Select a specific date from the table
  void selectDate(String dateStr) {
    state = state.copyWith(selectedDate: dateStr);
  }
}

/// Provider for attendance notifier
final attendanceProvider =
    StateNotifierProvider<AttendanceNotifier, AttendanceState>((ref) {
  final useCase = ref.watch(getAttendanceUseCaseProvider);
  return AttendanceNotifier(useCase);
});
