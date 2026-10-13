import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/dropdown_options_remote_datasource.dart';
import '../../data/models/dropdown_option_model.dart';
import 'providers.dart';

/// Provider for dropdown options datasource
final dropdownOptionsDataSourceProvider = Provider<DropdownOptionsRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return DropdownOptionsRemoteDataSourceImpl(apiClient: apiClient);
});

/// State class for dropdown options
class DropdownOptionsState {
  final List<DropdownOptionModel> categories;
  final List<DropdownOptionModel> labels;
  final List<DropdownOptionModel> priorities;
  final List<DropdownOptionModel> statuses;
  final bool isLoading;
  final String? errorMessage;

  DropdownOptionsState({
    this.categories = const [],
    this.labels = const [],
    this.priorities = const [],
    this.statuses = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  DropdownOptionsState copyWith({
    List<DropdownOptionModel>? categories,
    List<DropdownOptionModel>? labels,
    List<DropdownOptionModel>? priorities,
    List<DropdownOptionModel>? statuses,
    bool? isLoading,
    String? errorMessage,
  }) {
    return DropdownOptionsState(
      categories: categories ?? this.categories,
      labels: labels ?? this.labels,
      priorities: priorities ?? this.priorities,
      statuses: statuses ?? this.statuses,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Notifier for managing dropdown options
class DropdownOptionsNotifier extends StateNotifier<DropdownOptionsState> {
  final DropdownOptionsRemoteDataSource _dataSource;

  DropdownOptionsNotifier(this._dataSource) : super(DropdownOptionsState());

  /// Fetch all dropdown options
  Future<void> fetchAllOptions() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final results = await Future.wait([
        _dataSource.getTicketCategories(),
        _dataSource.getLabels(),
        _dataSource.getPriorities(),
        _dataSource.getTicketStatuses(),
      ]);

      state = state.copyWith(
        categories: results[0],
        labels: results[1],
        priorities: results[2],
        statuses: results[3],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load dropdown options: ${e.toString()}',
      );
    }
  }

  /// Fetch only categories
  Future<void> fetchCategories() async {
    try {
      final categories = await _dataSource.getTicketCategories();
      state = state.copyWith(categories: categories);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to load categories');
    }
  }

  /// Fetch only labels
  Future<void> fetchLabels() async {
    try {
      final labels = await _dataSource.getLabels();
      state = state.copyWith(labels: labels);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to load labels');
    }
  }

  /// Fetch only priorities
  Future<void> fetchPriorities() async {
    try {
      final priorities = await _dataSource.getPriorities();
      state = state.copyWith(priorities: priorities);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to load priorities');
    }
  }

  /// Fetch only statuses
  Future<void> fetchStatuses() async {
    try {
      final statuses = await _dataSource.getTicketStatuses();
      state = state.copyWith(statuses: statuses);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to load statuses');
    }
  }
}

/// Provider for dropdown options
final dropdownOptionsProvider = StateNotifierProvider<DropdownOptionsNotifier, DropdownOptionsState>((ref) {
  final dataSource = ref.watch(dropdownOptionsDataSourceProvider);
  return DropdownOptionsNotifier(dataSource);
});
