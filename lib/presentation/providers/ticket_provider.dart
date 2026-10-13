import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/ticket_remote_datasource.dart';
import '../../data/models/ticket_model.dart';
import '../../data/repositories/ticket_repository_impl.dart';
import '../../domain/repositories/ticket_repository.dart';
import '../../domain/usecases/ticket_usecases.dart';
import 'providers.dart';

/// Ticket state
class TicketState {
  final bool isLoading;
  final bool isLoadingMore;
  final List<TicketModel> tickets;
  final int totalRecords;
  final String? errorMessage;
  final int currentPage;
  final bool hasMore;
  final String currentKeyword;
  final bool isSaving;
  final String? saveSuccessMessage;

  const TicketState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.tickets = const [],
    this.totalRecords = 0,
    this.errorMessage,
    this.currentPage = 0,
    this.hasMore = true,
    this.currentKeyword = '',
    this.isSaving = false,
    this.saveSuccessMessage,
  });

  TicketState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    List<TicketModel>? tickets,
    int? totalRecords,
    String? errorMessage,
    int? currentPage,
    bool? hasMore,
    String? currentKeyword,
    bool? isSaving,
    String? saveSuccessMessage,
  }) {
    return TicketState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      tickets: tickets ?? this.tickets,
      totalRecords: totalRecords ?? this.totalRecords,
      errorMessage: errorMessage,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      currentKeyword: currentKeyword ?? this.currentKeyword,
      isSaving: isSaving ?? this.isSaving,
      saveSuccessMessage: saveSuccessMessage,
    );
  }
}

/// Ticket state notifier
class TicketNotifier extends StateNotifier<TicketState> {
  final Ref _ref;
  static const int _pageSize = 10;

  TicketNotifier(this._ref) : super(const TicketState());

  /// Fetch tickets (first page or refresh)
  Future<void> fetchTickets({String keyword = ''}) async {
    state = state.copyWith(
      isLoading: true,
      isLoadingMore: false,
      errorMessage: null,
      currentPage: 0,
      currentKeyword: keyword,
    );

    final getTicketsUseCase = _ref.read(getTicketsUseCaseProvider);
    final result = await getTicketsUseCase(
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
        state = state.copyWith(
          isLoading: false,
          isLoadingMore: false,
          tickets: response.list,
          totalRecords: response.totalRecords,
          currentPage: 0,
          hasMore: response.list.length < response.totalRecords,
        );
      },
    );
  }

  /// Load more tickets (pagination)
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) {
      return;
    }

    final nextPage = state.currentPage + 1;
    final startIndex = nextPage;

    state = state.copyWith(isLoadingMore: true, errorMessage: null);

    final getTicketsUseCase = _ref.read(getTicketsUseCaseProvider);
    final result = await getTicketsUseCase(
      startIndex: startIndex,
      pageSize: _pageSize,
      keyword: state.currentKeyword,
    );

    result.fold(
      (failure) {
        state = state.copyWith(
          isLoadingMore: false,
          errorMessage: failure.message,
        );
      },
      (response) {
        final allTickets = [...state.tickets, ...response.list];
        final hasMore = allTickets.length < response.totalRecords;
        state = state.copyWith(
          isLoadingMore: false,
          tickets: allTickets,
          totalRecords: response.totalRecords,
          currentPage: nextPage,
          hasMore: hasMore,
        );
      },
    );
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  /// Save ticket (add or update)
  Future<bool> saveTicket(TicketModel ticket) async {
    state = state.copyWith(
      isSaving: true,
      errorMessage: null,
      saveSuccessMessage: null,
    );

    final saveTicketUseCase = _ref.read(saveTicketUseCaseProvider);
    final result = await saveTicketUseCase(ticket: ticket);

    return result.fold(
      (failure) {
        state = state.copyWith(
          isSaving: false,
          errorMessage: failure.message,
        );
        return false;
      },
      (response) {
        state = state.copyWith(
          isSaving: false,
          saveSuccessMessage: response.message,
        );
        // Refresh the ticket list after successful save
        fetchTickets(keyword: state.currentKeyword);
        return true;
      },
    );
  }
}

// Providers
final ticketRemoteDataSourceProvider = Provider<TicketRemoteDataSource>((ref) {
  return TicketRemoteDataSourceImpl(
    apiClient: ref.watch(apiClientProvider),
  );
});

final ticketRepositoryProvider = Provider<TicketRepository>((ref) {
  return TicketRepositoryImpl(
    remoteDataSource: ref.watch(ticketRemoteDataSourceProvider),
  );
});

final getTicketsUseCaseProvider = Provider<GetTicketsUseCase>((ref) {
  return GetTicketsUseCase(ref.watch(ticketRepositoryProvider));
});

final saveTicketUseCaseProvider = Provider<SaveTicketUseCase>((ref) {
  return SaveTicketUseCase(ref.watch(ticketRepositoryProvider));
});

final ticketProvider =
    StateNotifierProvider<TicketNotifier, TicketState>((ref) {
  return TicketNotifier(ref);
});
