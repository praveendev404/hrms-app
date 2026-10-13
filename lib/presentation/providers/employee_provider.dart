import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/employee_remote_datasource.dart';
import '../../data/models/employee_model.dart';
import '../../data/repositories/employee_repository_impl.dart';
import '../../domain/repositories/employee_repository.dart';
import '../../domain/usecases/employee_usecases.dart';
import 'providers.dart';

/// Employee state
class EmployeeState {
  final bool isLoading;
  final bool isLoadingMore;
  final List<EmployeeModel> employees;
  final int totalRecords;
  final String? errorMessage;
  final int currentPage;
  final bool hasMore;
  final String currentKeyword;

  const EmployeeState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.employees = const [],
    this.totalRecords = 0,
    this.errorMessage,
    this.currentPage = 0,
    this.hasMore = true,
    this.currentKeyword = '',
  });

  EmployeeState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    List<EmployeeModel>? employees,
    int? totalRecords,
    String? errorMessage,
    int? currentPage,
    bool? hasMore,
    String? currentKeyword,
  }) {
    return EmployeeState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      employees: employees ?? this.employees,
      totalRecords: totalRecords ?? this.totalRecords,
      errorMessage: errorMessage,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      currentKeyword: currentKeyword ?? this.currentKeyword,
    );
  }
}

/// Employee state notifier
class EmployeeNotifier extends StateNotifier<EmployeeState> {
  final Ref _ref;
  static const int _pageSize = 10;

  EmployeeNotifier(this._ref) : super(const EmployeeState());

  /// Fetch employees (first page or refresh)
  Future<void> fetchEmployees({String keyword = ''}) async {
    state = state.copyWith(
      isLoading: true,
      isLoadingMore: false,
      errorMessage: null,
      currentPage: 0,
      currentKeyword: keyword,
    );

    final getEmployeesUseCase = _ref.read(getEmployeesUseCaseProvider);
    final result = await getEmployeesUseCase(
      startIndex: 0,
      pageSize: _pageSize,
      keyword: keyword,
    );

    result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          isLoadingMore: false,
          errorMessage: failure.message,
        );
      },
      (response) {
        print('fetchEmployees: got ${response.list.length} employees, total=${response.totalRecords}');
        state = state.copyWith(
          isLoading: false,
          isLoadingMore: false,
          employees: response.list,
          totalRecords: response.totalRecords,
          currentPage: 0,
          hasMore: response.list.length < response.totalRecords,
        );
        print('fetchEmployees complete: hasMore=${response.list.length < response.totalRecords}');
      },
    );
  }

  /// Load more employees (pagination)
  Future<void> loadMore() async {
    // Guard: Don't load if already loading more or no more data
    if (state.isLoadingMore || !state.hasMore) {
      print('loadMore blocked: isLoadingMore=${state.isLoadingMore}, hasMore=${state.hasMore}');
      return;
    }

    final nextPage = state.currentPage + 1;
    final startIndex = nextPage; // Increment by 1 each time

    print('loadMore: fetching page $nextPage, startIndex=$startIndex, current employees=${state.employees.length}');

    state = state.copyWith(isLoadingMore: true, errorMessage: null);

    final getEmployeesUseCase = _ref.read(getEmployeesUseCaseProvider);
    final result = await getEmployeesUseCase(
      startIndex: startIndex,
      pageSize: _pageSize,
      keyword: state.currentKeyword,
    );

    result.fold(
      (failure) {
        print('loadMore error: ${failure.message}');
        state = state.copyWith(
          isLoadingMore: false,
          errorMessage: failure.message,
        );
      },
      (response) {
        print('loadMore success: received ${response.list.length} employees, total=${response.totalRecords}');
        if (response.list.isNotEmpty) {
          print('loadMore new employee IDs: ${response.list.map((e) => e.id).take(5).join(", ")}...');
        }
        final allEmployees = [...state.employees, ...response.list];
        final hasMore = allEmployees.length < response.totalRecords;
        print('loadMore before update - current list IDs: ${state.employees.map((e) => e.id).take(5).join(", ")}...');
        state = state.copyWith(
          isLoadingMore: false,
          employees: allEmployees,
          totalRecords: response.totalRecords,
          currentPage: nextPage,
          hasMore: hasMore,
        );
        print('loadMore complete: now have ${allEmployees.length} of ${response.totalRecords} employees, hasMore=$hasMore');
        print('loadMore after update - all list IDs: ${state.employees.map((e) => e.id).take(10).join(", ")}...');
      },
    );
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

// Providers
final employeeRemoteDataSourceProvider = Provider<EmployeeRemoteDataSource>((ref) {
  return EmployeeRemoteDataSourceImpl(
    apiClient: ref.watch(apiClientProvider),
  );
});

final employeeRepositoryProvider = Provider<EmployeeRepository>((ref) {
  return EmployeeRepositoryImpl(
    remoteDataSource: ref.watch(employeeRemoteDataSourceProvider),
  );
});

final getEmployeesUseCaseProvider = Provider<GetEmployeesUseCase>((ref) {
  return GetEmployeesUseCase(ref.watch(employeeRepositoryProvider));
});

final employeeProvider =
    StateNotifierProvider<EmployeeNotifier, EmployeeState>((ref) {
  return EmployeeNotifier(ref);
});
